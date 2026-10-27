import 'dart:async';

import 'package:flutter/widgets.dart';

import '../game/game_lifecycle_phase.dart';
import 'daily_policy.dart';
import 'monotonic_clock.dart';
import 'persistent_store.dart';
import 'screen_time_accountant.dart';
import 'wall_clock.dart';

/// Kids Mode lifecycle bridge around [ScreenTimeAccountant] (LMP-49 Step 2/3).
///
/// ## What counts
/// Kids Hub shell + child transitions + active gameplay while the app is in
/// the foreground. Does **not** count: background/inactive, Parent Settings,
/// Mentor, Near/Far / RW mission on the parent path, or off-app time.
///
/// ## Trust / recovery
/// Never calls [ScreenTimeAccountant.recoverTrust] or
/// [TrustRecovery.forceNewLocalDay]. Child surfaces cannot override caps.
/// Storage open/restore/persist failures fail closed (block play; no silent
/// fresh day).
///
/// ## Cap timeliness
/// While counting, a one-shot deadline is scheduled for
/// `min(tickInterval, remainingSeconds)` so enforcement is not delayed by a
/// full 15s tick when the budget is nearly exhausted. Worst-case delay after
/// the true remaining budget elapses is bounded by timer resolution / the
/// next scheduled check (see [maxCapEnforcementDelay]).
///
/// ## Persistence
/// [persist] is serialized on a single chain so overlapping calls cannot
/// interleave store writes. Each write reads the latest in-memory snapshot at
/// execution time (no stale overwrite from an older in-flight body).
///
/// Does not rewrite accountant arithmetic — only drives start/pause/tick/persist.
final class ScreenTimeCoordinator extends ChangeNotifier
    with WidgetsBindingObserver {
  ScreenTimeCoordinator({
    required this._accountant,
    this.tickInterval = const Duration(seconds: 15),
    this.persistEveryTicks = 4,
  });

  /// Test / DI helper with injectable clocks + store.
  factory ScreenTimeCoordinator.withDependencies({
    required MonotonicClock monotonicClock,
    required WallClock wallClock,
    required PersistentStore store,
    DailyPolicy policy = DailyPolicy.defaultThirtyMinutes,
    Duration tickInterval = const Duration(seconds: 15),
    int persistEveryTicks = 4,
  }) {
    return ScreenTimeCoordinator(
      accountant: ScreenTimeAccountant(
        monotonicClock: monotonicClock,
        wallClock: wallClock,
        store: store,
        policy: policy,
      ),
      tickInterval: tickInterval,
      persistEveryTicks: persistEveryTicks,
    );
  }

  /// Production default periodic check while counting.
  static const Duration defaultTickInterval = Duration(seconds: 15);

  final ScreenTimeAccountant _accountant;
  final Duration tickInterval;
  final int persistEveryTicks;

  bool _initialized = false;
  bool _storageFailed = false;
  bool _kidsModeShellActive = false;
  bool _appForeground = true;
  GameLifecyclePhase? _gameplayPhase;
  bool _counting = false;
  bool _observingLifecycle = false;
  Timer? _tickTimer;
  int _ticksSincePersist = 0;
  Future<void> _persistChain = Future<void>.value();
  var _disposed = false;

  ScreenTimeAccountant get accountant => _accountant;

  bool get isInitialized => _initialized;

  bool get storageFailed => _storageFailed;

  bool get kidsModeShellActive => _kidsModeShellActive;

  bool get isCounting => _counting;

  bool get isAppForeground => _appForeground;

  GameLifecyclePhase? get gameplayPhase => _gameplayPhase;

  bool get isCapReached =>
      _storageFailed || (_initialized && _accountant.isCapReached);

  bool get isTrustDegraded =>
      _storageFailed || (_initialized && _accountant.isTrustDegraded);

  /// Kids Mode may accumulate and launch/resume child play.
  bool get allowsChildPlay {
    if (!_initialized || _storageFailed) return false;
    return _accountant.allowsKidsModeUsage && !_accountant.isCapReached;
  }

  /// Cap reached, trust degraded, or storage failed — show calm boundary.
  bool get shouldShowCalmBoundary {
    if (!_initialized) return false;
    return !allowsChildPlay;
  }

  int get remainingSeconds =>
      _storageFailed ? 0 : (_initialized ? _accountant.remainingSeconds : 0);

  /// Upper bound on how long past true budget exhaustion enforcement may wait
  /// when using the production [defaultTickInterval] and a deadline schedule.
  ///
  /// With [nextCapCheckDelay], the next check is `min(tickInterval, remaining)`.
  /// After the last second elapses, the deadline fires at that remaining mark,
  /// so enforcement is not deferred a full 15s. Documented bound equals the
  /// configured [tickInterval] only when remaining ≥ tickInterval (mid-budget
  /// checks); at the boundary it shrinks to the remaining second.
  Duration get maxCapEnforcementDelay =>
      tickInterval <= Duration.zero ? Duration.zero : tickInterval;

  /// Delay until the next scheduled cap/tick check while counting, or `null`
  /// when not counting / timers disabled.
  Duration? nextCapCheckDelay() {
    if (!_counting || tickInterval <= Duration.zero) return null;
    final remaining = _accountant.remainingSeconds;
    if (remaining <= 0) return Duration.zero;
    final remainingDelay = Duration(seconds: remaining);
    return remainingDelay < tickInterval ? remainingDelay : tickInterval;
  }

  /// Restore accountant and register lifecycle observer. Idempotent.
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    try {
      await _accountant.restore();
      // Corrupt / degraded snapshots stay fail-closed via accountant flags.
      if (_accountant.isCorruptPersistence || _accountant.isTrustDegraded) {
        // Still initialized — play blocked by allowsChildPlay.
      }
      _storageFailed = false;
    } catch (_) {
      // Fail closed — do not invent a fresh trusted day.
      _storageFailed = true;
    }
    _initialized = true;
    _ensureLifecycleObserver();
    _syncCounting(persistOnStop: false);
    notifyListeners();
  }

  /// Kids Hub (and in-Hub play) is the active shell route.
  void setKidsModeShellActive(bool active) {
    if (_disposed) return;
    if (_kidsModeShellActive == active) return;
    _kidsModeShellActive = active;
    if (!active) {
      _gameplayPhase = null;
    }
    _syncCounting(persistOnStop: true);
    notifyListeners();
  }

  /// Flame / play-host phase while an activity is open; `null` on Hub home.
  void setGameplayPhase(GameLifecyclePhase? phase) {
    if (_disposed) return;
    if (_gameplayPhase == phase) return;
    _gameplayPhase = phase;
    _syncCounting(persistOnStop: true);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    final foreground = state == AppLifecycleState.resumed;
    if (_appForeground == foreground) return;
    _appForeground = foreground;
    _syncCounting(persistOnStop: true);
    notifyListeners();
  }

  /// Manual lifecycle hook for tests (without binding observer).
  void handleAppLifecycleForTest(AppLifecycleState state) {
    didChangeAppLifecycleState(state);
  }

  /// Serialized persist — overlapping callers queue; each write uses latest
  /// in-memory state. Failures fail closed.
  Future<void> persist() {
    if (_disposed) return Future<void>.value();
    final done = Completer<void>();
    _persistChain = _persistChain.then((_) async {
      try {
        await _persistUnlocked();
        if (!done.isCompleted) done.complete();
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      }
    }).catchError((Object _) {
      // Keep the chain alive after a failure so later persists still run.
    });
    return done.future;
  }

  Future<void> _persistUnlocked() async {
    if (!_initialized || _storageFailed || _disposed) return;
    try {
      await _accountant.persist();
    } catch (_) {
      _storageFailed = true;
      _syncCounting(persistOnStop: false);
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _tickTimer?.cancel();
    _tickTimer = null;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    if (_counting) {
      _accountant.pauseActive();
      _counting = false;
    }
    // Best-effort serialized checkpoint; ignore failures during teardown.
    unawaited(persist().catchError((Object _) {}));
    super.dispose();
  }

  void _ensureLifecycleObserver() {
    if (_observingLifecycle) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    } catch (_) {
      // Binding absent — tests drive lifecycle via handleAppLifecycleForTest.
    }
  }

  bool _shouldAccumulate() {
    if (!_initialized || _storageFailed || _disposed) return false;
    if (!_accountant.allowsKidsModeUsage) return false;
    if (_accountant.isCapReached) return false;
    if (!_kidsModeShellActive || !_appForeground) return false;
    final phase = _gameplayPhase;
    if (phase == GameLifecyclePhase.paused ||
        phase == GameLifecyclePhase.backgrounded) {
      return false;
    }
    return true;
  }

  void _syncCounting({required bool persistOnStop}) {
    final should = _shouldAccumulate();
    if (should && !_counting) {
      _accountant.startActive();
      _counting = accountant.isActive;
      _ticksSincePersist = 0;
      _ensureTicker();
    } else if (!should && _counting) {
      _accountant.pauseActive();
      _counting = false;
      _tickTimer?.cancel();
      _tickTimer = null;
      if (persistOnStop) {
        unawaited(persist().catchError((Object _) {}));
      }
    } else if (should && _counting) {
      _ensureTicker();
    }

    if (_initialized && !_storageFailed && _accountant.isCapReached) {
      if (_counting) {
        _accountant.pauseActive();
        _counting = false;
        _tickTimer?.cancel();
        _tickTimer = null;
      }
      unawaited(persist().catchError((Object _) {}));
    }
  }

  /// Schedules the next check at [nextCapCheckDelay] (deadline, not blind 15s).
  void _ensureTicker() {
    if (_disposed) return;
    if (tickInterval <= Duration.zero) return;
    final delay = nextCapCheckDelay();
    if (delay == null) return;
    _tickTimer?.cancel();
    _tickTimer = Timer(delay, () {
      _tickTimer = null;
      _onTick();
      if (_counting && !_disposed) {
        _ensureTicker();
      }
    });
  }

  void _onTick() {
    if (_disposed) return;
    if (!_counting || _storageFailed) {
      _tickTimer?.cancel();
      _tickTimer = null;
      return;
    }
    _accountant.tick();
    _ticksSincePersist++;
    final capped = _accountant.isCapReached;
    if (capped || _ticksSincePersist >= persistEveryTicks) {
      _ticksSincePersist = 0;
      unawaited(persist().catchError((Object _) {}));
    }
    if (capped) {
      _syncCounting(persistOnStop: true);
    }
    notifyListeners();
  }

  /// Deterministic tick for tests (no real timer wait).
  void tickForTest() => _onTick();
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../game/game_lifecycle_phase.dart';
import 'daily_policy.dart';
import 'monotonic_clock.dart';
import 'persistent_store.dart';
import 'screen_time_accountant.dart';
import 'wall_clock.dart';

/// Kids Mode lifecycle bridge around [ScreenTimeAccountant] (LMP-49 Step 2).
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

  /// Restore accountant and register lifecycle observer. Idempotent.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _accountant.restore();
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
    if (_gameplayPhase == phase) return;
    _gameplayPhase = phase;
    _syncCounting(persistOnStop: true);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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

  Future<void> persist() async {
    if (!_initialized || _storageFailed) return;
    try {
      await _accountant.persist();
    } catch (_) {
      _storageFailed = true;
      _syncCounting(persistOnStop: false);
      notifyListeners();
    }
  }

  @override
  void dispose() {
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
    // Best-effort checkpoint; ignore failures during teardown.
    unawaited(() async {
      try {
        if (_initialized && !_storageFailed) {
          await _accountant.persist();
        }
      } catch (_) {}
    }());
    super.dispose();
  }

  void _ensureLifecycleObserver() {
    if (_observingLifecycle) return;
    // Avoid crashing pure unit tests that have not initialized a binding.
    try {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    } catch (_) {
      // Binding absent — tests drive lifecycle via handleAppLifecycleForTest.
    }
  }

  bool _shouldAccumulate() {
    if (!_initialized || _storageFailed) return false;
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
        unawaited(persist());
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
      unawaited(persist());
    }
  }

  void _ensureTicker() {
    if (_tickTimer != null) return;
    if (tickInterval <= Duration.zero) return;
    _tickTimer = Timer.periodic(tickInterval, (_) => _onTick());
  }

  void _onTick() {
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
      unawaited(persist());
    }
    if (capped) {
      _syncCounting(persistOnStop: true);
    }
    notifyListeners();
  }

  /// Deterministic tick for tests (no real timer wait).
  void tickForTest() => _onTick();
}

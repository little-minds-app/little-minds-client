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
/// ## Dispose / shutdown (Flutter sync dispose)
/// [dispose] is synchronous (ChangeNotifier). It cancels timers, stops
/// counting, enqueues a final checkpoint on the persist chain, and returns.
/// Queued writes (including that checkpoint) continue asynchronously until
/// [shutdownComplete]. After the drain, the coordinator is unavailable and
/// further [persist] / Kids Mode calls are no-ops.
///
/// **Best-effort limits:** the final write is not awaited inside [dispose], so
/// a process kill mid-drain can still lose the last checkpoint. Failures
/// during shutdown fail closed (`storageFailed`) without inventing a fresh day.
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

  /// Active → shuttingDown (dispose entered, persists still drain) → disposed.
  _CoordinatorPhase _phase = _CoordinatorPhase.active;
  Completer<void>? _shutdownCompleter;

  ScreenTimeAccountant get accountant => _accountant;

  bool get isInitialized => _initialized;

  bool get storageFailed => _storageFailed;

  bool get kidsModeShellActive => _kidsModeShellActive;

  bool get isCounting => _counting;

  bool get isAppForeground => _appForeground;

  GameLifecyclePhase? get gameplayPhase => _gameplayPhase;

  bool get isDisposed => _phase == _CoordinatorPhase.disposed;

  bool get isShuttingDown => _phase == _CoordinatorPhase.shuttingDown;

  /// Completes after dispose's persist chain has drained (or immediately if
  /// not shutting down / already disposed with no pending shutdown).
  ///
  /// Await inside the test body (or a non-`testWidgets` tearDown). Do not await
  /// from a `testWidgets` tearDown: the widget-test FakeAsync zone can leave
  /// Completer continuations un-woken after the test ends.
  Future<void> get shutdownComplete {
    final pending = _shutdownCompleter;
    if (pending != null) {
      if (pending.isCompleted) return Future<void>.value();
      return pending.future;
    }
    return Future<void>.value();
  }

  bool get isCapReached =>
      _storageFailed || (_initialized && _accountant.isCapReached);

  bool get isTrustDegraded =>
      _storageFailed || (_initialized && _accountant.isTrustDegraded);

  /// Kids Mode may accumulate and launch/resume child play.
  bool get allowsChildPlay {
    if (_phase != _CoordinatorPhase.active) return false;
    if (!_initialized || _storageFailed) return false;
    return _accountant.allowsKidsModeUsage && !_accountant.isCapReached;
  }

  /// Cap reached, trust degraded, or storage failed — show calm boundary.
  bool get shouldShowCalmBoundary {
    if (_phase != _CoordinatorPhase.active) return false;
    if (!_initialized) return false;
    return !allowsChildPlay;
  }

  int get remainingSeconds {
    if (_phase == _CoordinatorPhase.disposed) return 0;
    return _storageFailed ? 0 : (_initialized ? _accountant.remainingSeconds : 0);
  }

  /// Whether a tick timer is currently scheduled (tests).
  @visibleForTesting
  bool get hasScheduledTickForTest => _tickTimer != null;

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
    if (_initialized || _phase != _CoordinatorPhase.active) return;
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
    if (_phase != _CoordinatorPhase.active) return;
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
    if (_phase != _CoordinatorPhase.active) return;
    if (_gameplayPhase == phase) return;
    _gameplayPhase = phase;
    _syncCounting(persistOnStop: true);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_phase != _CoordinatorPhase.active) return;
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
  ///
  /// Accepted while [active] or [shuttingDown] (so dispose can drain). No-op
  /// once fully [disposed].
  Future<void> persist() {
    if (_phase == _CoordinatorPhase.disposed) {
      return Future<void>.value();
    }
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
    if (!_initialized || _storageFailed) return;
    if (_phase == _CoordinatorPhase.disposed) return;
    try {
      await _accountant.persist();
    } catch (_) {
      _storageFailed = true;
      if (_phase == _CoordinatorPhase.active) {
        _syncCounting(persistOnStop: false);
        notifyListeners();
      } else {
        _cancelTicker();
        _counting = false;
      }
      rethrow;
    }
  }

  /// Synchronous ChangeNotifier dispose: cancel timers, stop counting, enqueue
  /// final checkpoint, return. Await [shutdownComplete] in tests to observe
  /// drained writes.
  @override
  void dispose() {
    if (_phase != _CoordinatorPhase.active) {
      super.dispose();
      return;
    }

    _phase = _CoordinatorPhase.shuttingDown;
    _cancelTicker();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    if (_counting) {
      _accountant.pauseActive();
      _counting = false;
    }

    final shutdown = Completer<void>();
    _shutdownCompleter = shutdown;

    // Enqueue final checkpoint on the serialized chain while shuttingDown
    // (persist still allowed), then mark disposed / unavailable. Sync dispose
    // returns immediately; callers that need the drain observe
    // [shutdownComplete] (see getter docs for testWidgets limits).
    _persistChain = _persistChain.then((_) async {
      try {
        await _persistUnlocked();
      } catch (_) {
        // Fail-closed already applied in _persistUnlocked; keep draining.
      }
    }).whenComplete(() {
      _phase = _CoordinatorPhase.disposed;
      if (!shutdown.isCompleted) {
        shutdown.complete();
      }
    });

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
    if (_phase != _CoordinatorPhase.active) return false;
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

  void _cancelTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _syncCounting({required bool persistOnStop}) {
    final should = _shouldAccumulate();

    // Fix B: any non-counting outcome cancels timers (no stray deadlines).
    if (!should) {
      _cancelTicker();
    }

    if (should && !_counting) {
      _accountant.startActive();
      _counting = accountant.isActive;
      _ticksSincePersist = 0;
      _ensureTicker();
    } else if (!should && _counting) {
      _accountant.pauseActive();
      _counting = false;
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
      }
      _cancelTicker();
      unawaited(persist().catchError((Object _) {}));
    }
  }

  /// Schedules the next check at [nextCapCheckDelay] (deadline, not blind 15s).
  void _ensureTicker() {
    if (_phase != _CoordinatorPhase.active) {
      _cancelTicker();
      return;
    }
    if (!_counting) {
      _cancelTicker();
      return;
    }
    if (tickInterval <= Duration.zero) return;
    final delay = nextCapCheckDelay();
    if (delay == null) {
      _cancelTicker();
      return;
    }
    _tickTimer?.cancel();
    _tickTimer = Timer(delay, () {
      _tickTimer = null;
      _onTick();
      if (_counting && _phase == _CoordinatorPhase.active) {
        _ensureTicker();
      }
    });
  }

  void _onTick() {
    if (_phase != _CoordinatorPhase.active) {
      _cancelTicker();
      return;
    }
    if (!_counting || _storageFailed) {
      _cancelTicker();
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

  /// True while a debug QA apply/reload/persist link is queued or running on
  /// [_persistChain]. Inspector disables conflicting QA controls while set.
  bool get isDebugQaBusy => _debugQaInFlight > 0;

  int _debugQaInFlight = 0;

  void _beginDebugQaOp() {
    _debugQaInFlight++;
    if (_debugQaInFlight == 1) notifyListeners();
  }

  void _endDebugQaOp() {
    if (_debugQaInFlight == 0) return;
    _debugQaInFlight--;
    if (_debugQaInFlight == 0) notifyListeners();
  }

  /// Debug/QA: re-emit after an out-of-band accountant mutation.
  ///
  /// Used by [ScreenTimeDebugQa] only; not a product parent control.
  void debugNotifyListenersForQa() {
    if (_phase != _CoordinatorPhase.active) return;
    notifyListeners();
  }

  /// Debug/QA: apply used-seconds then persist on the serialized [_persistChain].
  ///
  /// Prevents reload/persist races from observing a half-applied budget.
  /// [mutationsAllowed] is forwarded to the accountant lowest-boundary guard
  /// (unit tests inject release refusal here).
  Future<void> debugApplyQaAccumulatedSeconds(
    int seconds, {
    bool Function()? mutationsAllowed,
  }) {
    if (_phase != _CoordinatorPhase.active) {
      return Future<void>.error(
        StateError('ScreenTimeCoordinator is unavailable'),
      );
    }
    if (_storageFailed ||
        _accountant.isCorruptPersistence ||
        _accountant.isTrustDegraded) {
      return Future<void>.error(
        StateError(
          'Debug QA cannot mutate budget while persistence/trust is fail-closed',
        ),
      );
    }
    _beginDebugQaOp();
    final done = Completer<void>();
    _persistChain = _persistChain.then((_) async {
      try {
        if (_phase != _CoordinatorPhase.active) {
          throw StateError('ScreenTimeCoordinator is unavailable');
        }
        if (_storageFailed ||
            _accountant.isCorruptPersistence ||
            _accountant.isTrustDegraded) {
          throw StateError(
            'Debug QA cannot mutate budget while persistence/trust is fail-closed',
          );
        }
        _accountant.applyDebugQaAccumulatedSeconds(
          seconds,
          mutationsAllowed: mutationsAllowed,
        );
        await _persistUnlocked();
        if (!done.isCompleted) done.complete();
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      } finally {
        _endDebugQaOp();
        if (_phase == _CoordinatorPhase.active) {
          notifyListeners();
        }
      }
    }).catchError((Object _) {
      // Keep the chain alive after a failure so later ops still run.
    });
    return done.future;
  }

  /// Debug/QA: re-run [ScreenTimeAccountant.restore] on the serialized
  /// [_persistChain] so a concurrent persist cannot leave a stale restore.
  ///
  /// Failures fail closed (`storageFailed`); does not invent a fresh trusted day
  /// beyond what [ScreenTimeAccountant.restore] already defines for missing keys.
  Future<void> debugReloadAccountantForQa() {
    if (_phase != _CoordinatorPhase.active) {
      return Future<void>.error(
        StateError('ScreenTimeCoordinator is unavailable'),
      );
    }
    _beginDebugQaOp();
    final done = Completer<void>();
    _persistChain = _persistChain.then((_) async {
      try {
        if (_phase != _CoordinatorPhase.active) {
          throw StateError('ScreenTimeCoordinator is unavailable');
        }
        try {
          await _accountant.restore();
          // Corrupt / degraded snapshots stay fail-closed via accountant flags.
          _storageFailed = false;
        } catch (_) {
          _storageFailed = true;
          rethrow;
        }
        _syncCounting(persistOnStop: false);
        if (!done.isCompleted) done.complete();
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      } finally {
        _endDebugQaOp();
        if (_phase == _CoordinatorPhase.active) {
          notifyListeners();
        }
      }
    }).catchError((Object _) {
      // Keep the chain alive after a failure so later ops still run.
    });
    return done.future;
  }

  /// Debug/QA: enqueue persist on the same busy/serialized channel.
  Future<void> debugPersistForQa() {
    if (_phase != _CoordinatorPhase.active) {
      return Future<void>.error(
        StateError('ScreenTimeCoordinator is unavailable'),
      );
    }
    _beginDebugQaOp();
    return persist().whenComplete(_endDebugQaOp);
  }
}

enum _CoordinatorPhase { active, shuttingDown, disposed }

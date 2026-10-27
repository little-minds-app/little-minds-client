import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'activity_session_snapshot.dart';
import 'game_lifecycle_phase.dart';
import 'learning_activity.dart';
import 'scoring_neutral_outcome.dart';

/// Why the Flame engine was paused.
enum ActivityPauseReason {
  /// Explicit pause / break control.
  user,

  /// App lifecycle background / inactive.
  appBackground,

  /// Host is capturing state for orientation / resize.
  orientation,
}

/// Orchestrates enter/exit, pause/resume, foreground/background, restart, and
/// disposal for one Flame-backed [LearningActivity] at a time (LMP-44).
///
/// Guarantees:
/// - At most one active session (no duplicate GameWidget owners).
/// - Stale async completions from prior generations are ignored.
/// - Engine tick matches [GameLifecyclePhase.allowsEngineTick].
class ActivitySessionController extends ChangeNotifier {
  ActivitySessionController({this._game});

  FlameGame? _game;
  LearningActivity? _activity;
  GameLifecyclePhase _phase = GameLifecyclePhase.idle;
  int _generation = 0;
  bool _pausedBeforeBackground = false;
  Object? _lastError;
  ScoringNeutralOutcome? _lastOutcome;
  bool _disposed = false;

  FlameGame? get game => _game;

  LearningActivity? get activity => _activity;

  GameLifecyclePhase get phase => _phase;

  /// Monotonic session generation — increments on each successful enter attempt.
  int get sessionGeneration => _generation;

  Object? get lastError => _lastError;

  ScoringNeutralOutcome? get lastOutcome => _lastOutcome;

  bool get hasActiveSession => _phase.isActive;

  void attachGame(FlameGame game) {
    _assertNotDisposed();
    _game = game;
    _syncEngine();
  }

  /// Starts [activity] after offline [LearningActivity.prepare].
  ///
  /// If another session is active, it is exited first (single-session guard).
  Future<bool> enter(LearningActivity activity) async {
    _assertNotDisposed();
    if (_phase.isActive) {
      await exit();
    }

    final generation = ++_generation;
    _activity = activity;
    _lastError = null;
    _lastOutcome = null;
    _pausedBeforeBackground = false;
    _setPhase(GameLifecyclePhase.preparing);

    try {
      await activity.prepare();
      if (!_isCurrent(generation)) {
        return false;
      }
      await activity.onEnter();
      if (!_isCurrent(generation)) {
        return false;
      }
      _setPhase(GameLifecyclePhase.running);
      _syncEngine();
      return true;
    } catch (error, stack) {
      if (!_isCurrent(generation)) {
        return false;
      }
      _lastError = error;
      // Keep prepare failures local — do not escalate via FlutterError
      // (would fail widget tests and is not child-facing). Host UI reacts
      // via [lastError] / idle phase.
      assert(() {
        debugPrint(
          'ActivitySessionController: prepare failed for ${activity.id}: $error\n$stack',
        );
        return true;
      }());
      await _tearDown(generation: generation, notifyActivityExit: false);
      return false;
    }
  }

  Future<void> pause({
    ActivityPauseReason reason = ActivityPauseReason.user,
  }) async {
    _assertNotDisposed();
    final generation = _generation;
    final activity = _activity;
    if (activity == null) {
      return;
    }

    switch (reason) {
      case ActivityPauseReason.appBackground:
        if (_phase != GameLifecyclePhase.running &&
            _phase != GameLifecyclePhase.paused) {
          return;
        }
        _pausedBeforeBackground = _phase == GameLifecyclePhase.paused;
        _setPhase(GameLifecyclePhase.backgrounded);
        _syncEngine();
        await activity.onBackground();
      case ActivityPauseReason.user:
      case ActivityPauseReason.orientation:
        if (_phase != GameLifecyclePhase.running) {
          return;
        }
        _setPhase(GameLifecyclePhase.paused);
        _syncEngine();
        await activity.onPause();
    }

    if (!_isCurrent(generation)) {
      return;
    }
    _syncEngine();
  }

  Future<void> resume() async {
    _assertNotDisposed();
    if (!_phase.canResume) {
      return;
    }

    final generation = _generation;
    final activity = _activity;
    if (activity == null) {
      return;
    }

    final fromBackground = _phase == GameLifecyclePhase.backgrounded;
    if (fromBackground) {
      await activity.onForeground();
      if (!_isCurrent(generation)) {
        return;
      }
      if (_pausedBeforeBackground) {
        _pausedBeforeBackground = false;
        _setPhase(GameLifecyclePhase.paused);
        _syncEngine();
        return;
      }
    }

    await activity.onResume();
    if (!_isCurrent(generation)) {
      return;
    }
    _setPhase(GameLifecyclePhase.running);
    _syncEngine();
  }

  /// Maps Flutter [AppLifecycleState] into pause / resume.
  Future<void> handleAppLifecycle(AppLifecycleState state) async {
    _assertNotDisposed();
    if (!_phase.isActive) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if (_phase == GameLifecyclePhase.backgrounded) {
          await resume();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_phase == GameLifecyclePhase.running ||
            _phase == GameLifecyclePhase.paused) {
          await pause(reason: ActivityPauseReason.appBackground);
        }
    }
  }

  Future<void> restart() async {
    _assertNotDisposed();
    if (!_phase.canRestart) {
      return;
    }
    final generation = _generation;
    final activity = _activity;
    if (activity == null) {
      return;
    }

    await activity.onRestart();
    if (!_isCurrent(generation)) {
      return;
    }
    _lastOutcome = null;
    _pausedBeforeBackground = false;
    _setPhase(GameLifecyclePhase.running);
    _syncEngine();
  }

  void reportOutcome(ScoringNeutralOutcome outcome) {
    _assertNotDisposed();
    if (!_phase.isActive) {
      return;
    }
    _lastOutcome = outcome;
    _activity?.onOutcome(outcome);
    if (outcome is ActivityCompletedOutcome) {
      _setPhase(GameLifecyclePhase.completed);
      _syncEngine();
    } else {
      notifyListeners();
    }
  }

  ActivitySessionSnapshot? captureSnapshot() {
    _assertNotDisposed();
    final activity = _activity;
    if (activity == null || !_phase.isActive) {
      return null;
    }
    return ActivitySessionSnapshot(
      sessionGeneration: _generation,
      activityId: activity.id,
      phase: _phase,
      playState: Map<String, Object?>.unmodifiable(activity.capturePlayState()),
      pausedBeforeBackground: _pausedBeforeBackground,
    );
  }

  Future<void> restoreSnapshot(ActivitySessionSnapshot snapshot) async {
    _assertNotDisposed();
    if (snapshot.sessionGeneration != _generation) {
      return;
    }
    final activity = _activity;
    if (activity == null || activity.id != snapshot.activityId) {
      return;
    }

    await activity.restorePlayState(snapshot.playState);
    if (snapshot.sessionGeneration != _generation) {
      return;
    }
    _pausedBeforeBackground = snapshot.pausedBeforeBackground;
    if (snapshot.phase == GameLifecyclePhase.running ||
        snapshot.phase == GameLifecyclePhase.paused ||
        snapshot.phase == GameLifecyclePhase.backgrounded ||
        snapshot.phase == GameLifecyclePhase.completed) {
      _setPhase(snapshot.phase);
    }
    _syncEngine();
  }

  /// Safe exit back to idle — always disposes activity resources.
  Future<void> exit() async {
    _assertNotDisposed();
    if (_phase == GameLifecyclePhase.idle ||
        _phase == GameLifecyclePhase.disposed) {
      _activity = null;
      _setPhase(GameLifecyclePhase.idle);
      return;
    }
    final generation = _generation;
    await _tearDown(generation: generation, notifyActivityExit: true);
  }

  /// Hard dispose of the controller (host widget disposed).
  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final activity = _activity;
    _activity = null;
    _phase = GameLifecyclePhase.disposed;
    _game = null;
    // Invalidate outstanding callbacks.
    _generation++;
    if (activity != null) {
      // ignore: discarded_futures
      activity.disposeResources();
    }
    super.dispose();
  }

  Future<void> _tearDown({
    required int generation,
    required bool notifyActivityExit,
  }) async {
    final activity = _activity;
    // Invalidate outstanding callbacks belonging to this session.
    if (_generation == generation) {
      _generation++;
    }
    _activity = null;
    _pausedBeforeBackground = false;

    if (activity != null) {
      if (notifyActivityExit) {
        try {
          if (_lastOutcome is! ActivityAbandonedOutcome &&
              _lastOutcome is! ActivityCompletedOutcome) {
            _lastOutcome = const ActivityAbandonedOutcome();
            activity.onOutcome(_lastOutcome!);
          }
          await activity.onExit();
        } catch (_) {
          // Exit must still reach disposeResources.
        }
      }
      try {
        await activity.disposeResources();
      } catch (_) {
        // Best-effort cleanup.
      }
    }

    _setPhase(GameLifecyclePhase.idle);
    _syncEngine();
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _generation && _phase.isActive;

  void _setPhase(GameLifecyclePhase next) {
    if (_phase == next) {
      notifyListeners();
      return;
    }
    _phase = next;
    notifyListeners();
  }

  void _syncEngine() {
    final game = _game;
    if (game == null) {
      return;
    }
    if (_phase.allowsEngineTick) {
      if (game.paused) {
        game.resumeEngine();
      }
    } else if (!game.paused) {
      game.pauseEngine();
    }
  }

  void _assertNotDisposed() {
    assert(!_disposed, 'ActivitySessionController used after dispose');
  }
}

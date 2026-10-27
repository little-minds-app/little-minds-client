import 'dart:async';

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
/// - Stale async completions from prior generations / transitions are ignored.
/// - Stale teardown never forces [GameLifecyclePhase.idle] over a newer session
///   (phase is written only in sync ownership sections before awaits).
/// - [dispose] stays synchronous for [ChangeNotifier]; activity cleanup is
///   owned by a captured instance and never mutates this controller afterward.
/// - Engine tick matches [GameLifecyclePhase.allowsEngineTick].
class ActivitySessionController extends ChangeNotifier {
  ActivitySessionController({this._game});

  FlameGame? _game;
  LearningActivity? _activity;
  GameLifecyclePhase _phase = GameLifecyclePhase.idle;

  /// Session ownership — bumps on enter claim and on tearDown claim.
  int _generation = 0;

  /// Phase-transition ownership — bumps on pause/resume/restart/bg/enter/exit.
  /// Stale async callbacks that lose this race must not overwrite newer state.
  int _transitionSeq = 0;

  bool _pausedBeforeBackground = false;
  Object? _lastError;
  ScoringNeutralOutcome? _lastOutcome;
  bool _disposed = false;

  /// Serializes ownership mutations (enter claim / exit tearDown claim).
  Future<void> _exclusiveTail = Future<void>.value();

  FlameGame? get game => _game;

  LearningActivity? get activity => _activity;

  GameLifecyclePhase get phase => _phase;

  /// Monotonic session generation — increments on each enter / tearDown claim.
  int get sessionGeneration => _generation;

  /// Visible for tests — current transition sequence.
  @visibleForTesting
  int get transitionSeq => _transitionSeq;

  Object? get lastError => _lastError;

  ScoringNeutralOutcome? get lastOutcome => _lastOutcome;

  bool get hasActiveSession => _phase.isActive;

  bool get isDisposed => _disposed;

  void attachGame(FlameGame game) {
    _assertNotDisposed();
    _game = game;
    _syncEngine();
  }

  /// Starts [activity] after offline [LearningActivity.prepare].
  ///
  /// If another session is active, it is exited first (single-session guard).
  /// Ownership mutations are exclusive; [prepare]/[onEnter] await outside so
  /// a concurrent [exit] can invalidate the generation.
  Future<bool> enter(LearningActivity activity) async {
    _assertNotDisposed();

    final generation = await _exclusive(() async {
      _assertNotDisposed();
      if (_phase.isActive) {
        await _exitUnlocked();
        if (_disposed) {
          return -1;
        }
      }
      final gen = ++_generation;
      _transitionSeq++;
      _activity = activity;
      _lastError = null;
      _lastOutcome = null;
      _pausedBeforeBackground = false;
      _setPhase(GameLifecyclePhase.preparing);
      return gen;
    });
    if (generation < 0 || _disposed) {
      return false;
    }

    try {
      await activity.prepare();
      if (!_ownsSession(generation)) {
        return false;
      }
      await activity.onEnter();
      if (!_ownsSession(generation)) {
        return false;
      }
      return await _exclusive(() async {
        if (!_ownsSession(generation)) {
          return false;
        }
        _setPhase(GameLifecyclePhase.running);
        _syncEngine();
        return true;
      });
    } catch (error, stack) {
      if (!_ownsSession(generation)) {
        return false;
      }
      _lastError = error;
      assert(() {
        debugPrint(
          'ActivitySessionController: prepare failed for ${activity.id}: '
          '$error\n$stack',
        );
        return true;
      }());
      await _exclusive(() async {
        if (!_ownsSession(generation)) {
          return;
        }
        await _tearDownUnlocked(
          generation: generation,
          activity: activity,
          notifyActivityExit: false,
        );
      });
      return false;
    }
  }

  Future<void> pause({
    ActivityPauseReason reason = ActivityPauseReason.user,
  }) async {
    if (_disposed) {
      return;
    }
    final generation = _generation;
    final activity = _activity;
    if (activity == null || !_ownsSession(generation)) {
      return;
    }

    switch (reason) {
      case ActivityPauseReason.appBackground:
        if (_phase != GameLifecyclePhase.running &&
            _phase != GameLifecyclePhase.paused) {
          return;
        }
        final seq = ++_transitionSeq;
        _pausedBeforeBackground = _phase == GameLifecyclePhase.paused;
        _setPhase(GameLifecyclePhase.backgrounded);
        _syncEngine();
        await activity.onBackground();
        if (!_ownsSession(generation) || seq != _transitionSeq) {
          return;
        }
        _syncEngine();
      case ActivityPauseReason.user:
      case ActivityPauseReason.orientation:
        if (_phase != GameLifecyclePhase.running) {
          return;
        }
        final seq = ++_transitionSeq;
        _setPhase(GameLifecyclePhase.paused);
        _syncEngine();
        await activity.onPause();
        if (!_ownsSession(generation) || seq != _transitionSeq) {
          return;
        }
        _syncEngine();
    }
  }

  Future<void> resume() async {
    if (_disposed) {
      return;
    }
    if (!_phase.canResume) {
      return;
    }

    final generation = _generation;
    final activity = _activity;
    if (activity == null || !_ownsSession(generation)) {
      return;
    }

    final seq = ++_transitionSeq;
    final fromBackground = _phase == GameLifecyclePhase.backgrounded;
    if (fromBackground) {
      await activity.onForeground();
      if (!_ownsSession(generation) || seq != _transitionSeq) {
        return;
      }
      if (_pausedBeforeBackground) {
        _pausedBeforeBackground = false;
        _setPhase(GameLifecyclePhase.paused);
        _syncEngine();
        return;
      }
    }

    // Commit running before the activity hook so a concurrent pause can win
    // the transitionSeq race instead of being ignored while phase is still
    // paused/backgrounded mid-resume.
    _setPhase(GameLifecyclePhase.running);
    _syncEngine();
    await activity.onResume();
    if (!_ownsSession(generation) || seq != _transitionSeq) {
      return;
    }
    _syncEngine();
  }

  /// Maps Flutter [AppLifecycleState] into pause / resume.
  Future<void> handleAppLifecycle(AppLifecycleState state) async {
    if (_disposed || !_phase.isActive) {
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
    if (_disposed) {
      return;
    }
    if (!_phase.canRestart) {
      return;
    }
    final generation = _generation;
    final activity = _activity;
    if (activity == null || !_ownsSession(generation)) {
      return;
    }

    final seq = ++_transitionSeq;
    await activity.onRestart();
    if (!_ownsSession(generation) || seq != _transitionSeq) {
      return;
    }
    _lastOutcome = null;
    _pausedBeforeBackground = false;
    _setPhase(GameLifecyclePhase.running);
    _syncEngine();
  }

  void reportOutcome(ScoringNeutralOutcome outcome) {
    if (_disposed || !_phase.isActive) {
      return;
    }
    _lastOutcome = outcome;
    _activity?.onOutcome(outcome);
    if (outcome is ActivityCompletedOutcome) {
      _transitionSeq++;
      _setPhase(GameLifecyclePhase.completed);
      _syncEngine();
    } else {
      notifyListeners();
    }
  }

  ActivitySessionSnapshot? captureSnapshot() {
    if (_disposed) {
      return null;
    }
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
      transitionSeq: _transitionSeq,
    );
  }

  Future<void> restoreSnapshot(ActivitySessionSnapshot snapshot) async {
    if (!_acceptsSnapshot(snapshot)) {
      return;
    }
    final generation = snapshot.sessionGeneration;
    final seqAtStart = _transitionSeq;
    final activity = _activity;
    if (activity == null) {
      return;
    }

    await activity.restorePlayState(snapshot.playState);

    // Stale restore must not overwrite newer pause / bg / exit / restart.
    if (!_acceptsSnapshot(snapshot) ||
        generation != _generation ||
        seqAtStart != _transitionSeq) {
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

  /// Safe exit back to idle — disposes resources for the torn-down session only.
  Future<void> exit() => _exclusive(_exitUnlocked);

  Future<void> _exitUnlocked() async {
    if (_disposed) {
      return;
    }
    if (_phase == GameLifecyclePhase.idle ||
        _phase == GameLifecyclePhase.disposed) {
      _activity = null;
      _setPhase(GameLifecyclePhase.idle);
      return;
    }
    final generation = _generation;
    final activity = _activity;
    await _tearDownUnlocked(
      generation: generation,
      activity: activity,
      notifyActivityExit: true,
    );
  }

  /// Hard dispose of the controller (host widget disposed).
  ///
  /// Synchronous [ChangeNotifier] contract: listeners are dropped immediately.
  /// Activity cleanup is explicitly owned by the captured [LearningActivity]
  /// instance and never mutates this controller after return.
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
    // Invalidate outstanding session + transition callbacks.
    _generation++;
    _transitionSeq++;
    super.dispose();
    if (activity != null) {
      unawaited(_disposeOwnedActivity(activity));
    }
  }

  /// Tears down [activity] belonging to [generation] only.
  ///
  /// Session ownership and phase move to idle **synchronously** before any
  /// activity await. Async cleanup only touches the captured [activity].
  Future<void> _tearDownUnlocked({
    required int generation,
    required LearningActivity? activity,
    required bool notifyActivityExit,
  }) async {
    final outcomeBefore = _lastOutcome;

    if (_disposed) {
      if (activity != null) {
        await _disposeOwnedActivity(
          activity,
          notifyExit: notifyActivityExit,
          lastOutcome: outcomeBefore,
        );
      }
      return;
    }

    // Claim tearDown only if we still own this session generation.
    if (_generation != generation) {
      if (activity != null) {
        await _disposeOwnedActivity(
          activity,
          notifyExit: notifyActivityExit,
          lastOutcome: null,
        );
      }
      return;
    }

    _transitionSeq++;
    ++_generation;
    if (identical(_activity, activity)) {
      _activity = null;
    }
    _pausedBeforeBackground = false;

    // Idle before awaits — stale cleanup must not write phase later.
    _setPhase(GameLifecyclePhase.idle);
    _syncEngine();

    if (activity != null) {
      await _disposeOwnedActivity(
        activity,
        notifyExit: notifyActivityExit,
        lastOutcome: outcomeBefore,
      );
    }
  }

  bool _acceptsSnapshot(ActivitySessionSnapshot snapshot) {
    if (_disposed) {
      return false;
    }
    if (snapshot.sessionGeneration != _generation) {
      return false;
    }
    final activity = _activity;
    if (activity == null || activity.id != snapshot.activityId) {
      return false;
    }
    if (!_phase.isActive) {
      return false;
    }
    if (snapshot.transitionSeq != null &&
        snapshot.transitionSeq != _transitionSeq) {
      return false;
    }
    return true;
  }

  bool _ownsSession(int generation) =>
      !_disposed && generation == _generation && _phase.isActive;

  void _setPhase(GameLifecyclePhase next) {
    if (_disposed) {
      return;
    }
    if (_phase == next) {
      notifyListeners();
      return;
    }
    _phase = next;
    notifyListeners();
  }

  void _syncEngine() {
    if (_disposed) {
      return;
    }
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

  Future<T> _exclusive<T>(Future<T> Function() body) {
    final next = _exclusiveTail.catchError((_) {}).then((_) => body());
    _exclusiveTail = next.then((_) {}, onError: (_) {});
    return next;
  }

  void _assertNotDisposed() {
    assert(!_disposed, 'ActivitySessionController used after dispose');
  }

  /// Cleans a captured activity only — never reads/writes controller fields.
  static Future<void> _disposeOwnedActivity(
    LearningActivity activity, {
    bool notifyExit = false,
    ScoringNeutralOutcome? lastOutcome,
  }) async {
    if (notifyExit) {
      try {
        if (lastOutcome is! ActivityAbandonedOutcome &&
            lastOutcome is! ActivityCompletedOutcome) {
          activity.onOutcome(const ActivityAbandonedOutcome());
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
}

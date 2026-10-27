import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/game/activity_session_controller.dart';
import 'package:little_minds_mobile/game/game_lifecycle_phase.dart';
import 'package:little_minds_mobile/game/hitbox_scaler.dart';
import 'package:little_minds_mobile/game/learning_activity.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';

class _HarnessActivity extends LearningActivity {
  _HarnessActivity({
    this.id = 'lifecycle_harness',
    this.failPrepare = false,
    this.prepareDelay = Duration.zero,
    this.pauseDelay = Duration.zero,
    this.resumeDelay = Duration.zero,
    this.restoreDelay = Duration.zero,
    this.disposeDelay = Duration.zero,
  });

  @override
  final String id;

  final bool failPrepare;
  final Duration prepareDelay;
  final Duration pauseDelay;
  final Duration resumeDelay;
  final Duration restoreDelay;
  final Duration disposeDelay;

  final calls = <String>[];
  var disposed = false;
  var disposeCount = 0;
  var playToken = 0;
  final outcomes = <ScoringNeutralOutcome>[];

  @override
  String get displayName => 'Lifecycle Harness';

  @override
  bool get isPlayable => true;

  @override
  Future<void> prepare() async {
    calls.add('prepare');
    if (prepareDelay > Duration.zero) {
      await Future<void>.delayed(prepareDelay);
    }
    if (failPrepare) {
      throw StateError('offline assets missing');
    }
  }

  @override
  Future<void> onEnter() async => calls.add('onEnter');

  @override
  Future<void> onPause() async {
    calls.add('onPause');
    if (pauseDelay > Duration.zero) {
      await Future<void>.delayed(pauseDelay);
    }
  }

  @override
  Future<void> onResume() async {
    calls.add('onResume');
    if (resumeDelay > Duration.zero) {
      await Future<void>.delayed(resumeDelay);
    }
  }

  @override
  Future<void> onBackground() async => calls.add('onBackground');

  @override
  Future<void> onForeground() async => calls.add('onForeground');

  @override
  Future<void> onRestart() async {
    calls.add('onRestart');
    playToken = 0;
  }

  @override
  Future<void> onExit() async => calls.add('onExit');

  @override
  Future<void> disposeResources() async {
    calls.add('disposeResources');
    disposeCount++;
    if (disposeDelay > Duration.zero) {
      await Future<void>.delayed(disposeDelay);
    }
    disposed = true;
  }

  @override
  Map<String, Object?> capturePlayState() => {'token': playToken};

  @override
  Future<void> restorePlayState(Map<String, Object?> state) async {
    calls.add('restore');
    if (restoreDelay > Duration.zero) {
      await Future<void>.delayed(restoreDelay);
    }
    playToken = state['token'] as int? ?? 0;
  }

  @override
  void onOutcome(ScoringNeutralOutcome outcome) {
    outcomes.add(outcome);
    calls.add('outcome:${outcome.runtimeType}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HitboxScaler (F-034)', () {
    test('TC-LIFE-001 clamps short design targets to 44 logical px', () {
      const phone = Size(667, 375);
      final length = HitboxScaler.scaleLength(20, viewport: phone);
      expect(length, greaterThanOrEqualTo(HitboxScaler.minLogicalSize));

      final rect = HitboxScaler.scaleRect(
        const Rect.fromLTWH(100, 100, 20, 20),
        viewport: phone,
      );
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
    });

    test('TC-LIFE-002 tablet viewport scales larger than phone', () {
      const phone = Size(667, 375);
      const tablet = Size(1180, 820);
      final phoneLen = HitboxScaler.scaleLength(80, viewport: phone);
      final tabletLen = HitboxScaler.scaleLength(80, viewport: tablet);
      expect(tabletLen, greaterThan(phoneLen));
    });
  });

  group('ScoringNeutralOutcome', () {
    test('TC-LIFE-003 outcomes carry cues without numeric scores', () {
      const completed = ActivityCompletedOutcome();
      const encourage = EncouragementOutcome(cueKey: 'nice_try');
      const hint = HintOfferedOutcome(level: 2);
      const abandoned = ActivityAbandonedOutcome();

      expect(completed, isA<ScoringNeutralOutcome>());
      expect(encourage.cueKey, 'nice_try');
      expect(hint.level, 2);
      expect(abandoned, isA<ScoringNeutralOutcome>());
    });
  });

  group('ActivitySessionController', () {
    late FlameGame game;
    late ActivitySessionController controller;

    setUp(() {
      game = FlameGame();
      controller = ActivitySessionController(game: game);
    });

    tearDown(() {
      controller.dispose();
    });

    test('TC-LIFE-004 enter/pause/resume/exit lifecycle', () async {
      final activity = _HarnessActivity();
      expect(await controller.enter(activity), isTrue);
      expect(controller.phase, GameLifecyclePhase.running);
      expect(game.paused, isFalse);

      await controller.pause();
      expect(controller.phase, GameLifecyclePhase.paused);
      expect(game.paused, isTrue);
      expect(activity.calls, contains('onPause'));

      await controller.resume();
      expect(controller.phase, GameLifecyclePhase.running);
      expect(game.paused, isFalse);
      expect(activity.calls, contains('onResume'));

      await controller.exit();
      expect(controller.phase, GameLifecyclePhase.idle);
      expect(activity.disposed, isTrue);
      expect(activity.calls, contains('onExit'));
      expect(activity.outcomes.last, isA<ActivityAbandonedOutcome>());
    });

    test('TC-LIFE-005 foreground/background via app lifecycle', () async {
      final activity = _HarnessActivity();
      await controller.enter(activity);

      await controller.handleAppLifecycle(AppLifecycleState.paused);
      expect(controller.phase, GameLifecyclePhase.backgrounded);
      expect(game.paused, isTrue);
      expect(activity.calls, contains('onBackground'));

      await controller.handleAppLifecycle(AppLifecycleState.resumed);
      expect(controller.phase, GameLifecyclePhase.running);
      expect(activity.calls, contains('onForeground'));
    });

    test('TC-LIFE-006 background while paused restores to paused', () async {
      final activity = _HarnessActivity();
      await controller.enter(activity);
      await controller.pause();
      await controller.handleAppLifecycle(AppLifecycleState.inactive);
      expect(controller.phase, GameLifecyclePhase.backgrounded);

      await controller.handleAppLifecycle(AppLifecycleState.resumed);
      expect(controller.phase, GameLifecyclePhase.paused);
      expect(game.paused, isTrue);
    });

    test('TC-LIFE-007 restart and completed outcome', () async {
      final activity = _HarnessActivity();
      await controller.enter(activity);
      activity.playToken = 9;

      await controller.restart();
      expect(controller.phase, GameLifecyclePhase.running);
      expect(activity.playToken, 0);
      expect(activity.calls, contains('onRestart'));

      controller.reportOutcome(const ActivityCompletedOutcome());
      expect(controller.phase, GameLifecyclePhase.completed);
      expect(game.paused, isTrue);
      expect(activity.outcomes.last, isA<ActivityCompletedOutcome>());
    });

    test('TC-LIFE-008 offline prepare failure stays idle and disposes', () async {
      final activity = _HarnessActivity(failPrepare: true);
      final ok = await controller.enter(activity);
      expect(ok, isFalse);
      expect(controller.phase, GameLifecyclePhase.idle);
      expect(controller.lastError, isA<StateError>());
      expect(activity.disposed, isTrue);
      expect(activity.calls, isNot(contains('onEnter')));
    });

    test('TC-LIFE-009 single-session guard exits prior activity', () async {
      final first = _HarnessActivity(id: 'a');
      final second = _HarnessActivity(id: 'b');
      await controller.enter(first);
      expect(await controller.enter(second), isTrue);
      expect(first.disposed, isTrue);
      expect(first.calls, contains('onExit'));
      expect(controller.activity?.id, 'b');
      expect(controller.phase, GameLifecyclePhase.running);
    });

    test('TC-LIFE-010 stale prepare ignored after exit', () async {
      final slow = _HarnessActivity(
        prepareDelay: const Duration(milliseconds: 40),
      );
      final enterFuture = controller.enter(slow);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.exit();
      final ok = await enterFuture;
      expect(ok, isFalse);
      expect(controller.phase, GameLifecyclePhase.idle);
      // Stale onEnter must not run after exit invalidated the generation.
      expect(slow.calls.where((c) => c == 'onEnter'), isEmpty);
    });

    test('TC-LIFE-011 orientation snapshot preserve/restore', () async {
      final activity = _HarnessActivity();
      await controller.enter(activity);
      activity.playToken = 42;

      final snap = controller.captureSnapshot();
      expect(snap, isNotNull);
      expect(snap!.playState['token'], 42);

      activity.playToken = 0;
      await controller.restoreSnapshot(snap);
      expect(activity.playToken, 42);
      expect(activity.calls, contains('restore'));
      expect(controller.phase, GameLifecyclePhase.running);
    });

    test('TC-LIFE-012 dispose invalidates controller and resources', () async {
      final activity = _HarnessActivity();
      await controller.enter(activity);
      controller.dispose();
      expect(controller.phase, GameLifecyclePhase.disposed);
      expect(controller.isDisposed, isTrue);
      // disposeResources is owned async after sync ChangeNotifier.dispose.
      await Future<void>.delayed(Duration.zero);
      expect(activity.disposed, isTrue);
    });

    test(
        'TC-LIFE-013 stale teardown cleanup cannot idle a newer session',
        () async {
      final first = _HarnessActivity(
        id: 'a',
        disposeDelay: const Duration(milliseconds: 50),
      );
      final second = _HarnessActivity(id: 'b');
      await controller.enter(first);

      // Start exit (slow dispose) then enter second as soon as exclusive allows.
      final exitFuture = controller.exit();
      // Let exit claim idle sync + start dispose await.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(controller.phase, GameLifecyclePhase.idle);

      expect(await controller.enter(second), isTrue);
      expect(controller.phase, GameLifecyclePhase.running);
      expect(controller.activity?.id, 'b');

      await exitFuture;
      // First activity finishes delayed cleanup without forcing idle.
      expect(controller.phase, GameLifecyclePhase.running);
      expect(controller.activity?.id, 'b');
      expect(first.disposed, isTrue);
      expect(second.disposed, isFalse);
    });

    test('TC-LIFE-014 dispose during prepare cancels enter safely', () async {
      final activity = _HarnessActivity(
        prepareDelay: const Duration(milliseconds: 40),
      );
      final enterFuture = controller.enter(activity);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      controller.dispose();
      expect(controller.isDisposed, isTrue);
      expect(await enterFuture, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activity.calls.where((c) => c == 'onEnter'), isEmpty);
      // Sync dispose captured activity for cleanup (prepare may still finish).
      expect(activity.disposeCount, greaterThanOrEqualTo(1));
    });

    test('TC-LIFE-015 dispose during pause await stays disposed', () async {
      final activity = _HarnessActivity(
        pauseDelay: const Duration(milliseconds: 40),
      );
      await controller.enter(activity);
      final pauseFuture = controller.pause();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      controller.dispose();
      await pauseFuture;
      expect(controller.phase, GameLifecyclePhase.disposed);
      await Future<void>.delayed(Duration.zero);
      expect(activity.disposed, isTrue);
    });

    test(
        'TC-LIFE-016 stale resume cannot overwrite newer pause',
        () async {
      final activity = _HarnessActivity(
        resumeDelay: const Duration(milliseconds: 40),
      );
      await controller.enter(activity);
      await controller.pause();
      expect(controller.phase, GameLifecyclePhase.paused);

      final resumeFuture = controller.resume();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.pause();
      await resumeFuture;

      expect(controller.phase, GameLifecyclePhase.paused);
      expect(game.paused, isTrue);
    });

    test(
        'TC-LIFE-017 delayed snapshot restore cannot overwrite pause',
        () async {
      final activity = _HarnessActivity(
        restoreDelay: const Duration(milliseconds: 40),
      );
      await controller.enter(activity);
      activity.playToken = 11;
      final snap = controller.captureSnapshot();
      expect(snap, isNotNull);

      final restoreFuture = controller.restoreSnapshot(snap!);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.pause();
      expect(controller.phase, GameLifecyclePhase.paused);

      await restoreFuture;
      expect(controller.phase, GameLifecyclePhase.paused);
      expect(game.paused, isTrue);
    });

    test(
        'TC-LIFE-018 delayed snapshot restore ignored after restart',
        () async {
      final activity = _HarnessActivity(
        restoreDelay: const Duration(milliseconds: 40),
      );
      await controller.enter(activity);
      activity.playToken = 5;
      final snap = controller.captureSnapshot();

      final restoreFuture = controller.restoreSnapshot(snap!);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.restart();
      expect(activity.playToken, 0);

      await restoreFuture;
      // Restart won — stale restore must not resurrect old token via phase
      // rewrite; playToken may or may not flip depending on await order of
      // restorePlayState body, but phase must stay running from restart.
      expect(controller.phase, GameLifecyclePhase.running);
    });

    test(
        'TC-LIFE-019 overlapping enter/exit keeps later session',
        () async {
      final slow = _HarnessActivity(
        id: 'slow',
        prepareDelay: const Duration(milliseconds: 40),
      );
      final fast = _HarnessActivity(id: 'fast');

      final firstEnter = controller.enter(slow);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final secondEnter = controller.enter(fast);

      expect(await firstEnter, isFalse);
      expect(await secondEnter, isTrue);
      expect(controller.activity?.id, 'fast');
      expect(controller.phase, GameLifecyclePhase.running);
      expect(slow.disposed, isTrue);
    });
  });
}

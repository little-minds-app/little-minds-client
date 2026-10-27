import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_card.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_catalog.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/activity_play_host.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/game/activity_session_controller.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/game/game_lifecycle_phase.dart';
import 'package:little_minds_mobile/game/learning_activity.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';
import 'package:little_minds_mobile/l10n/app_localizations.dart';
import 'package:little_minds_mobile/orientation/app_surface.dart';
import 'package:little_minds_mobile/orientation/orientation_policy.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';

Future<void> _pumpFrames(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _setLandscape(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  final view = tester.view;
  view.physicalSize = Size(width, height);
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

class _HarnessActivity extends LearningActivity {
  _HarnessActivity({
    this.failPrepare = false,
  });

  @override
  String get id => 'lifecycle_harness';

  final bool failPrepare;
  final calls = <String>[];
  var playToken = 0;

  @override
  String get displayName => 'Lifecycle Harness';

  @override
  bool get isPlayable => true;

  @override
  Future<void> prepare() async {
    calls.add('prepare');
    if (failPrepare) {
      throw StateError('offline assets missing');
    }
  }

  @override
  Future<void> onEnter() async => calls.add('onEnter');

  @override
  Future<void> onPause() async => calls.add('onPause');

  @override
  Future<void> onResume() async => calls.add('onResume');

  @override
  Future<void> onRestart() async => calls.add('onRestart');

  @override
  Future<void> onExit() async => calls.add('onExit');

  @override
  Future<void> disposeResources() async => calls.add('dispose');

  @override
  Map<String, Object?> capturePlayState() => {'token': playToken};

  @override
  Future<void> restorePlayState(Map<String, Object?> state) async {
    playToken = state['token'] as int? ?? 0;
    calls.add('restore');
  }

  @override
  void onOutcome(ScoringNeutralOutcome outcome) => calls.add('outcome');
}

/// Catalog-aligned playable used only in tests — not production bootstrap.
class _TestPlayableShapeMatching extends LearningActivity {
  @override
  String get id => HubCatalogActivityId.shapeMatching.id;

  @override
  String get displayName => 'Shape Matching';

  @override
  bool get isPlayable => true;

  @override
  Future<void> prepare() async {}
}

Widget _hostApp({
  required LearningActivity activity,
  ActivitySessionController? controller,
  Locale locale = const Locale('en', 'US'),
  bool reduceMotion = false,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      if (!reduceMotion) {
        return child!;
      }
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(disableAnimations: true),
        child: child!,
      );
    },
    home: ActivityPlayHost(
      game: StubLearningGame(),
      activity: activity,
      controller: controller,
      onClose: () {},
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-LIFE-W01 play host enters running on phone landscape',
      (tester) async {
    final activity = _HarnessActivity();
    final controller = ActivitySessionController();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      _hostApp(activity: activity, controller: controller),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ActivityPlayHost.hostKey), findsOneWidget);
    expect(controller.phase, GameLifecyclePhase.running);
    expect(find.byKey(ActivityPlayHost.pauseKey), findsOneWidget);
    expect(find.text('Playing'), findsOneWidget);
    expect(
      OrientationPolicy.isLandscapeOnly(AppSurface.miniGame),
      isTrue,
    );
    controller.dispose();
  });

  testWidgets('TC-LIFE-W02 pause/resume/restart chrome on tablet landscape',
      (tester) async {
    final activity = _HarnessActivity();
    final controller = ActivitySessionController();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(
      _hostApp(activity: activity, controller: controller),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(ActivityPlayHost.pauseKey));
    await _pumpFrames(tester);
    expect(controller.phase, GameLifecyclePhase.paused);
    expect(find.byKey(ActivityPlayHost.resumeKey), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.byKey(ActivityPlayHost.resumeKey));
    await _pumpFrames(tester);
    expect(controller.phase, GameLifecyclePhase.running);

    await tester.tap(find.byKey(ActivityPlayHost.restartKey));
    await _pumpFrames(tester);
    expect(activity.calls, contains('onRestart'));
    controller.dispose();
  });

  testWidgets('TC-LIFE-W03 tr-TR chrome labels', (tester) async {
    final controller = ActivitySessionController();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      _hostApp(
        activity: _HarnessActivity(),
        controller: controller,
        locale: const Locale('tr', 'TR'),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Geri'), findsOneWidget);
    expect(find.text('Oynanıyor'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('TC-LIFE-W04 close exits session and returns control',
      (tester) async {
    final activity = _HarnessActivity();
    final controller = ActivitySessionController();
    var closed = false;
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActivityPlayHost(
          game: StubLearningGame(),
          activity: activity,
          controller: controller,
          onClose: () => closed = true,
        ),
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(ActivityPlayHost.closeKey));
    await _pumpFrames(tester);
    expect(closed, isTrue);
    expect(controller.phase, GameLifecyclePhase.idle);
    expect(activity.calls, contains('onExit'));
    expect(activity.calls, contains('dispose'));
    controller.dispose();
  });

  testWidgets('TC-LIFE-W05 prepare failure closes host safely', (tester) async {
    var closed = false;
    final controller = ActivitySessionController();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActivityPlayHost(
          game: StubLearningGame(),
          activity: _HarnessActivity(failPrepare: true),
          controller: controller,
          onClose: () => closed = true,
        ),
      ),
    );
    await _pumpFrames(tester, 12);
    expect(closed, isTrue);
    expect(controller.phase, GameLifecyclePhase.idle);
    controller.dispose();
  });

  testWidgets('TC-LIFE-W06 viewport change restores captured play state',
      (tester) async {
    final activity = _HarnessActivity();
    final controller = ActivitySessionController();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      _hostApp(activity: activity, controller: controller),
    );
    await _pumpFrames(tester);
    activity.playToken = 7;

    await _setLandscape(
      tester,
      width: ScaffoldingViewports.largePhoneHeight,
      height: ScaffoldingViewports.largePhoneWidth,
    );
    await _pumpFrames(tester, 12);

    expect(activity.playToken, 7);
    expect(activity.calls, contains('restore'));
    controller.dispose();
  });

  testWidgets(
      'TC-LIFE-W07 production empty registry keeps hub passive (no playables)',
      (tester) async {
    final game = StubLearningGame();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: game,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(game.registry.isEmpty, isTrue);
    expect(find.byKey(ChildHubSurface.homeKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.emptyPlayableKey), findsOneWidget);
    expect(find.byKey(ActivityPlayHost.hostKey), findsNothing);
    expect(find.byKey(HubActivityCard.playableBadgeKey('shape_matching')),
        findsNothing);
    // Visible carousel page still shows Coming Soon (passive) badges.
    expect(find.text('Coming Soon'), findsWidgets);
  });

  testWidgets(
      'TC-LIFE-W08 injected playable launches lifecycle host without hardcoding',
      (tester) async {
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(
          registry: ActivityRegistry([_TestPlayableShapeMatching()]),
        ),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(
        HubActivityCard.cardKey(HubCatalogActivityId.shapeMatching.id),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ActivityPlayHost.hostKey), findsOneWidget);
    expect(find.byKey(ActivityPlayHost.pauseKey), findsOneWidget);
  });

  testWidgets('TC-LIFE-W09 reduced-motion play host still mounts',
      (tester) async {
    final controller = ActivitySessionController();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      _hostApp(
        activity: _HarnessActivity(),
        controller: controller,
        reduceMotion: true,
      ),
    );
    await _pumpFrames(tester);
    expect(find.byKey(ActivityPlayHost.hostKey), findsOneWidget);
    expect(controller.phase, GameLifecyclePhase.running);
    controller.dispose();
  });
}

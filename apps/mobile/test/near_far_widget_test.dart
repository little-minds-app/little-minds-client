import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_catalog.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/near_far/near_far_activity.dart';
import 'package:little_minds_mobile/near_far/near_far_constants.dart';
import 'package:little_minds_mobile/near_far/near_far_events.dart';
import 'package:little_minds_mobile/near_far/near_far_mission_handoff.dart';
import 'package:little_minds_mobile/near_far/near_far_mission_handoff_panel.dart';
import 'package:little_minds_mobile/near_far/near_far_play_field.dart';
import 'package:little_minds_mobile/near_far/near_far_relation.dart';
import 'package:little_minds_mobile/near_far/near_far_spoken_labels.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/near_far_demo_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';

Future<void> _pumpFrames(WidgetTester tester, [int times = 12]) async {
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

NearFarActivity _demoActivity({
  Locale locale = const Locale('en', 'US'),
  NearFarLocalEventBuffer? buffer,
}) {
  var i = 0;
  return NearFarActivity(
    eventBuffer:
        buffer ?? NearFarLocalEventBuffer(idFactory: () => 'w-${i++}'),
    playSessionId: 'widget-session',
    localeTag: nearFarLocaleTag(locale),
    spokenLabels: NearFarSpokenLabels(
      player: RecordingNearFarLabelPlayer(),
    ),
  );
}

Future<void> completeToHandoff(
  WidgetTester tester,
  NearFarActivity activity,
) async {
  await _pumpFrames(tester, 20);
  final near = NearFarRelationLogic.nearPositions();
  activity.moveSock(near.sock);
  activity.moveSoftToy(near.softToy);
  final far = NearFarRelationLogic.initialFarPositions();
  activity.moveSock(far.sock);
  activity.moveSoftToy(far.softToy);
  await _pumpFrames(tester, 12);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-NF-W01 phone landscape demo enters running with large targets',
      (tester) async {
    final activity = _demoActivity();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        locale: const Locale('en', 'US'),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester, 20);

    expect(find.byKey(NearFarDemoSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(NearFarPlayField.sockKey), findsOneWidget);
    expect(find.byKey(NearFarPlayField.softToyKey), findsOneWidget);
    expect(find.byKey(NearFarDemoSurface.spokenBlockedKey), findsOneWidget);

    final sock = tester.getSize(find.byKey(NearFarPlayField.sockKey));
    expect(sock.width, greaterThanOrEqualTo(44));
    expect(sock.height, greaterThanOrEqualTo(44));

    expect(find.text('Near and Far'), findsWidgets);
    expect(activity.eventBuffer.events.first.eventType, 'activity_started');
  });

  testWidgets('TC-NF-W02 tablet landscape + tr-TR strings', (tester) async {
    final activity = _demoActivity(locale: const Locale('tr', 'TR'));
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        locale: const Locale('tr', 'TR'),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester, 20);

    expect(find.text('Yakın ve Uzak'), findsWidgets);
    expect(find.textContaining('Çorabı'), findsOneWidget);
    expect(find.byKey(NearFarPlayField.fieldKey), findsOneWidget);
  });

  testWidgets('TC-NF-W03 drag near then far offers mission Try/Skip flow',
      (tester) async {
    var i = 0;
    final buffer = NearFarLocalEventBuffer(idFactory: () => 'drag-${i++}');
    final activity = NearFarActivity(
      eventBuffer: buffer,
      playSessionId: 'drag-session',
      spokenLabels: NearFarSpokenLabels(player: RecordingNearFarLabelPlayer()),
    );
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester, 20);

    final near = NearFarRelationLogic.nearPositions();
    activity.moveSock(near.sock);
    activity.moveSoftToy(near.softToy);
    await _pumpFrames(tester, 8);
    expect(activity.prompt, NearFarPromptStep.makeFar);

    final far = NearFarRelationLogic.initialFarPositions();
    activity.moveSock(far.sock);
    activity.moveSoftToy(far.softToy);
    await _pumpFrames(tester, 12);

    expect(find.byKey(NearFarMissionHandoffPanel.panelKey), findsOneWidget);
    expect(
      activity.missionHandoff.handoff.state,
      NearFarMissionHandoffState.offered,
    );
    expect(find.byKey(NearFarMissionHandoffPanel.openKey), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.skipKey), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.openedConfirmKey), findsNothing);

    await tester.tap(find.byKey(NearFarMissionHandoffPanel.openKey));
    await _pumpFrames(tester, 8);
    expect(
      activity.missionHandoff.handoff.state,
      NearFarMissionHandoffState.opened,
    );
    expect(find.byKey(NearFarMissionHandoffPanel.openKey), findsNothing);
    expect(find.byKey(NearFarMissionHandoffPanel.stepsKey), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.doneKey), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.skipKey), findsOneWidget);
    expect(
      buffer.events.map((e) => e.eventType),
      containsAll([
        'activity_completed',
        'real_world_mission_offered',
        'real_world_mission_opened',
      ]),
    );
    // Repeat open path must not emit again (button gone; API still idempotent).
    activity.openMissionHandoff();
    await _pumpFrames(tester, 4);
    expect(
      buffer.events.where((e) => e.eventType == 'real_world_mission_opened').length,
      1,
    );
  });

  testWidgets('TC-NF-W04 pause / resume / restart on demo host', (tester) async {
    final activity = _demoActivity();
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester, 20);

    await tester.tap(find.byKey(NearFarDemoSurface.pauseKey));
    await _pumpFrames(tester, 8);
    expect(find.byKey(NearFarDemoSurface.resumeKey), findsOneWidget);

    await tester.tap(find.byKey(NearFarDemoSurface.resumeKey));
    await _pumpFrames(tester, 8);
    expect(find.byKey(NearFarDemoSurface.pauseKey), findsOneWidget);

    await tester.tap(find.byKey(NearFarDemoSurface.restartKey));
    await _pumpFrames(tester, 8);
    expect(activity.prompt, NearFarPromptStep.makeNear);
  });

  testWidgets('TC-NF-W05 reduced motion path still renders play field',
      (tester) async {
    final activity = _demoActivity();
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: LittleMindsApp(
        testOnlyAdultAccess: true,
          initialNearFarDemo: true,
          nearFarActivity: activity,
          audioGuidance: RecordingHubAudioGuidance(),
        ),
      ),
    );
    await _pumpFrames(tester, 20);
    expect(find.byKey(NearFarPlayField.fieldKey), findsOneWidget);
  });

  testWidgets('TC-NF-W06 hub catalog unchanged — no near_far seventh game',
      (tester) async {
    final game = StubLearningGame();
    expect(game.registry.isEmpty, isTrue);
    expect(game.registry.findById(NearFarConstants.activityId), isNull);

    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        game: game,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester, 12);

    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(NearFarDemoSurface.surfaceKey), findsNothing);

    // Six catalog ids only — near_far is not among them.
    expect(HubCatalogActivityId.values.length, 6);
    expect(
      HubCatalogActivityId.values.map((e) => e.id),
      isNot(contains(NearFarConstants.activityId)),
    );
  });

  testWidgets('TC-NF-W07 parent settings grown-ups entry opens demo',
      (tester) async {
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,audioGuidance: RecordingHubAudioGuidance()),
    );
    await _pumpFrames(tester, 12);

    // Parent Gate → Settings → Near/Far demo (not child Hub nav).
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester, 8);
    await tester.tap(find.byKey(const Key('nav-parent-settings')));
    await _pumpFrames(tester, 8);

    expect(find.byKey(ParentSettingsSurface.nearFarDemoKey), findsOneWidget);
    expect(find.byKey(ParentSettingsSurface.nearFarDemoHintKey), findsOneWidget);
    expect(
      find.textContaining('placeholder'),
      findsWidgets,
    );
    // Debug screen-time entry (LMP-49) can push Near/Far below the fold on
    // short phone landscape — scroll before tapping.
    await tester.ensureVisible(find.byKey(ParentSettingsSurface.nearFarDemoKey));
    await _pumpFrames(tester, 4);
    await tester.tap(find.byKey(ParentSettingsSurface.nearFarDemoKey));
    await _pumpFrames(tester, 20);

    expect(find.byKey(NearFarDemoSurface.surfaceKey), findsOneWidget);
  });

  testWidgets('TC-NF-W09 restart after complete allows second completion',
      (tester) async {
    var i = 0;
    final buffer = NearFarLocalEventBuffer(idFactory: () => 'rw-${i++}');
    final activity = NearFarActivity(
      eventBuffer: buffer,
      playSessionId: 'restart-widget',
      spokenLabels: NearFarSpokenLabels(player: RecordingNearFarLabelPlayer()),
    );
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester, 20);

    void complete() {
      final near = NearFarRelationLogic.nearPositions();
      activity.moveSock(near.sock);
      activity.moveSoftToy(near.softToy);
      final far = NearFarRelationLogic.initialFarPositions();
      activity.moveSock(far.sock);
      activity.moveSoftToy(far.softToy);
    }

    complete();
    await _pumpFrames(tester, 12);
    expect(find.byKey(NearFarMissionHandoffPanel.panelKey), findsOneWidget);

    await tester.tap(find.byKey(NearFarDemoSurface.restartKey));
    await _pumpFrames(tester, 12);
    expect(find.byKey(NearFarMissionHandoffPanel.panelKey), findsNothing);
    expect(activity.prompt, NearFarPromptStep.makeNear);

    complete();
    await _pumpFrames(tester, 12);
    expect(find.byKey(NearFarMissionHandoffPanel.panelKey), findsOneWidget);
    expect(
      buffer.events.where((e) => e.eventType == 'activity_completed').length,
      2,
    );
  });

  testWidgets('TC-NF-W08 ActivityRegistry stays empty with demo activity playable',
      (tester) async {
    final registry = ActivityRegistry();
    final activity = NearFarActivity(playSessionId: 'reg');
    expect(activity.isPlayable, isTrue);
    expect(activity.id, NearFarConstants.activityId);
    // Deliberately NOT registering — demo route only.
    expect(registry.findById(activity.id), isNull);
    expect(registry.isEmpty, isTrue);
  });

  testWidgets(
      'TC-NF-W10 iPhone landscape completion: card readable, no overlap/chrome',
      (tester) async {
    final activity = _demoActivity();
    // iPhone 15 logical landscape (~844×390) with notched side insets.
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(844, 390),
          padding: EdgeInsets.fromLTRB(47, 0, 47, 21),
          textScaler: TextScaler.linear(1.3),
        ),
        child: LittleMindsApp(
        testOnlyAdultAccess: true,
          initialNearFarDemo: true,
          nearFarActivity: activity,
          audioGuidance: RecordingHubAudioGuidance(),
        ),
      ),
    );
    await _pumpFrames(tester, 20);

    final near = NearFarRelationLogic.nearPositions();
    activity.moveSock(near.sock);
    activity.moveSoftToy(near.softToy);
    final far = NearFarRelationLogic.initialFarPositions();
    activity.moveSock(far.sock);
    activity.moveSoftToy(far.softToy);
    await _pumpFrames(tester, 16);

    expect(tester.takeException(), isNull);

    // Mission card present; play-field prompt / objects / lifecycle label gone.
    expect(find.byKey(NearFarMissionHandoffPanel.panelKey), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.cardKey), findsOneWidget);
    expect(find.text('Try it in the room'), findsOneWidget);
    expect(find.text('Nice exploring!'), findsNothing);
    expect(find.text('Nice work'), findsNothing);
    expect(find.byKey(NearFarPlayField.fieldKey), findsNothing);
    expect(find.byKey(NearFarPlayField.sockKey), findsNothing);
    expect(find.byKey(NearFarPlayField.softToyKey), findsNothing);
    expect(find.byKey(NearFarDemoSurface.phaseKey), findsNothing);

    final cardSize = tester.getSize(find.byKey(NearFarMissionHandoffPanel.cardKey));
    expect(cardSize.width, lessThanOrEqualTo(NearFarMissionHandoffPanel.maxCardWidth + 1));
    expect(cardSize.height, lessThanOrEqualTo(390));
    expect(cardSize.width, greaterThan(200));
    expect(cardSize.height, greaterThan(80));

    // Opaque panel paints the calm fill (no black gutter behind the card).
    final panel =
        tester.widget<ColoredBox>(find.byKey(NearFarMissionHandoffPanel.panelKey));
    expect(panel.color, isNot(equals(const Color(0xFF000000))));
    expect(panel.color.a, equals(1.0));
  });

  testWidgets(
      'TC-NF-W11 en-US Try together → steps; Skip / Done / Back l10n',
      (tester) async {
    final activity = _demoActivity(locale: const Locale('en', 'US'));
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        locale: const Locale('en', 'US'),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await completeToHandoff(tester, activity);

    expect(find.text('Try together'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.openedConfirmKey), findsNothing);

    await tester.tap(find.byKey(NearFarMissionHandoffPanel.openKey));
    await _pumpFrames(tester, 8);

    expect(find.text('Try together'), findsNothing);
    expect(find.byKey(NearFarMissionHandoffPanel.openKey), findsNothing);
    expect(find.byKey(NearFarMissionHandoffPanel.stepsKey), findsOneWidget);
    expect(find.text('Explore near and far'), findsOneWidget);
    expect(find.textContaining('Ask a grown-up'), findsWidgets);
    expect(find.text("We're done"), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Back'), findsWidgets);
    expect(find.text('Maybe later'), findsNothing);
    expect(find.textContaining('one sock'), findsAtLeastNWidgets(1));
  });

  testWidgets(
      'TC-NF-W12 tr-TR Birlikte dene → adımlar; Atla / Bitirdik / Geri',
      (tester) async {
    final activity = _demoActivity(locale: const Locale('tr', 'TR'));
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        locale: const Locale('tr', 'TR'),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await completeToHandoff(tester, activity);

    expect(find.text('Birlikte dene'), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
    expect(find.text('Belki sonra'), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.openedConfirmKey), findsNothing);

    await tester.tap(find.byKey(NearFarMissionHandoffPanel.openKey));
    await _pumpFrames(tester, 8);

    expect(find.text('Birlikte dene'), findsNothing);
    expect(find.byKey(NearFarMissionHandoffPanel.openKey), findsNothing);
    expect(find.byKey(NearFarMissionHandoffPanel.stepsKey), findsOneWidget);
    expect(find.text('Yakın ve uzağı keşfet'), findsOneWidget);
    expect(find.text('Bitirdik'), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
    expect(find.text('Geri'), findsWidgets);
    expect(find.text('Belki sonra'), findsNothing);
  });

  testWidgets('TC-NF-W13 Skip from offered shows calm exit; no photo UI',
      (tester) async {
    final activity = _demoActivity();
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await completeToHandoff(tester, activity);

    expect(find.byKey(NearFarMissionHandoffPanel.skipKey), findsOneWidget);
    await tester.tap(find.byKey(NearFarMissionHandoffPanel.skipKey));
    await _pumpFrames(tester, 8);

    expect(
      activity.missionHandoff.handoff.state,
      NearFarMissionHandoffState.skipped,
    );
    expect(find.byKey(NearFarMissionHandoffPanel.skippedKey), findsOneWidget);
    expect(find.textContaining("That's okay"), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Try together'), findsNothing);
    expect(find.textContaining('photo'), findsNothing);
    expect(find.textContaining('camera'), findsNothing);

    await tester.tap(find.byKey(NearFarMissionHandoffPanel.dismissKey));
    await _pumpFrames(tester, 16);
    // Calm Back dismiss exits demo to Child Hub (initialNearFarDemo path).
    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.panelKey), findsNothing);
  });

  testWidgets('TC-NF-W14 Start → We\'re done → Back calm completion',
      (tester) async {
    final activity = _demoActivity();
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await completeToHandoff(tester, activity);

    await tester.tap(find.byKey(NearFarMissionHandoffPanel.openKey));
    await _pumpFrames(tester, 8);
    await tester.tap(find.byKey(NearFarMissionHandoffPanel.doneKey));
    await _pumpFrames(tester, 8);

    expect(
      activity.missionHandoff.handoff.state,
      NearFarMissionHandoffState.completed,
    );
    expect(find.byKey(NearFarMissionHandoffPanel.completedKey), findsOneWidget);
    expect(find.text('Nice exploring together.'), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.skipKey), findsNothing);

    await tester.tap(find.byKey(NearFarMissionHandoffPanel.dismissKey));
    await _pumpFrames(tester, 16);
    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.panelKey), findsNothing);
  });

  testWidgets('TC-NF-W15 a11y: mission actions meet 48pt min; semantics live',
      (tester) async {
    final activity = _demoActivity();
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await completeToHandoff(tester, activity);

    final trySize =
        tester.getSize(find.byKey(NearFarMissionHandoffPanel.openKey));
    final skipSize =
        tester.getSize(find.byKey(NearFarMissionHandoffPanel.skipKey));
    final laterSize =
        tester.getSize(find.byKey(NearFarMissionHandoffPanel.dismissKey));
    expect(trySize.height, greaterThanOrEqualTo(48));
    expect(skipSize.height, greaterThanOrEqualTo(48));
    expect(laterSize.height, greaterThanOrEqualTo(48));
    expect(trySize.width, greaterThanOrEqualTo(148));

    await tester.tap(find.byKey(NearFarMissionHandoffPanel.openKey));
    await _pumpFrames(tester, 8);
    expect(find.byKey(NearFarMissionHandoffPanel.stepsKey), findsOneWidget);
    // Live-region semantics wrap the guidance column.
    expect(
      tester.getSemantics(find.byKey(NearFarMissionHandoffPanel.stepsKey)),
      isNotNull,
    );
  });

  testWidgets('TC-NF-W16 tablet landscape skip + restart mission lifecycle',
      (tester) async {
    final activity = _demoActivity();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        testOnlyAdultAccess: true,
        initialNearFarDemo: true,
        nearFarActivity: activity,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await completeToHandoff(tester, activity);
    await tester.tap(find.byKey(NearFarMissionHandoffPanel.skipKey));
    await _pumpFrames(tester, 8);
    expect(find.byKey(NearFarMissionHandoffPanel.skippedKey), findsOneWidget);

    await tester.tap(find.byKey(NearFarDemoSurface.restartKey));
    await _pumpFrames(tester, 12);
    expect(find.byKey(NearFarMissionHandoffPanel.panelKey), findsNothing);
    expect(activity.prompt, NearFarPromptStep.makeNear);

    await completeToHandoff(tester, activity);
    expect(find.text('Try together'), findsOneWidget);
    expect(find.byKey(NearFarMissionHandoffPanel.skipKey), findsOneWidget);
  });
}

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

  testWidgets('TC-NF-W03 drag near then far offers mission handoff',
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

    await tester.tap(find.byKey(NearFarMissionHandoffPanel.openKey));
    await _pumpFrames(tester, 8);
    expect(
      activity.missionHandoff.handoff.state,
      NearFarMissionHandoffState.opened,
    );
    expect(
      buffer.events.map((e) => e.eventType),
      containsAll([
        'activity_completed',
        'real_world_mission_offered',
        'real_world_mission_opened',
      ]),
    );
  });

  testWidgets('TC-NF-W04 pause / resume / restart on demo host', (tester) async {
    final activity = _demoActivity();
    await _setLandscape(tester, width: 844, height: 390);
    await tester.pumpWidget(
      LittleMindsApp(
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
      LittleMindsApp(audioGuidance: RecordingHubAudioGuidance()),
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
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_card.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_catalog.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/game/learning_activity.dart';
import 'package:little_minds_mobile/l10n/app_localizations.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';

/// Flame's GameWidget schedules continuous frames; avoid pumpAndSettle.
Future<void> _pumpFrames(WidgetTester tester, [int times = 5]) async {
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

class _PlayableShapeMatching extends LearningActivity {
  @override
  String get id => HubCatalogActivityId.shapeMatching.id;

  @override
  String get displayName => 'Shape matching';

  @override
  bool get isPlayable => true;

  @override
  Future<void> prepare() async {}
}

class _PassiveRegistered extends LearningActivity {
  @override
  String get id => HubCatalogActivityId.counting.id;

  @override
  String get displayName => 'Counting';

  @override
  bool get isPlayable => false;

  @override
  Future<void> prepare() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // TC-HUB-001 — Hub renders landscape kid home (greeting, brand).
  testWidgets('TC-HUB-001 renders Child Hub v1 home', (tester) async {
    final audio = RecordingHubAudioGuidance();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(game: StubLearningGame(), audioGuidance: audio),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.homeKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.brandKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.greetingKey), findsOneWidget);
    expect(find.text('Little Minds'), findsWidgets);
    expect(find.text("Let's play!"), findsOneWidget);
    expect(find.byKey(const Key('child-hub-placeholder')), findsNothing);
    expect(
      audio.plays.any((p) => p.cue == HubAudioCue.welcome),
      isTrue,
    );
  });

  // TC-HUB-002 — Empty registry → empty playable banner; no play host.
  testWidgets('TC-HUB-002 empty registry shows empty playable state',
      (tester) async {
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(registry: ActivityRegistry()),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.emptyPlayableKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.playHostKey), findsNothing);
    expect(find.byKey(FlameHostPanel.hostKey), findsNothing);
  });

  // TC-HUB-003 — Passive catalog cards present and non-launching.
  testWidgets('TC-HUB-003 passive cards do not launch Flame host',
      (tester) async {
    final audio = RecordingHubAudioGuidance();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(
          registry: ActivityRegistry([_PassiveRegistered()]),
        ),
        audioGuidance: audio,
      ),
    );
    await _pumpFrames(tester);

    for (final id in HubCatalogActivityId.values) {
      expect(find.byKey(HubActivityCard.cardKey(id.id)), findsOneWidget);
      expect(find.byKey(HubActivityCard.passiveBadgeKey(id.id)), findsOneWidget);
      expect(
        find.byKey(HubActivityCard.playableBadgeKey(id.id)),
        findsNothing,
      );
    }

    final shapeCard = find.byKey(
      HubActivityCard.cardKey(HubCatalogActivityId.shapeMatching.id),
    );
    await tester.ensureVisible(shapeCard);
    await tester.tap(shapeCard);
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.playHostKey), findsNothing);
    expect(
      audio.plays.any((p) => p.cue == HubAudioCue.passiveUnavailable),
      isTrue,
    );
  });

  // TC-HUB-004 — Landscape compact phone + tablet layouts recompose.
  testWidgets('TC-HUB-004 compact phone vs tablet hub layouts', (tester) async {
    // iPhone-class landscape: width may exceed expanded breakpoint, but height
    // stays short → single-pane Kids Mode.
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.compactLayoutKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.expandedLayoutKey), findsNothing);

    // iPad-class landscape: width + height allow dual-pane hub.
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.expandedLayoutKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.compactLayoutKey), findsNothing);
  });

  // TC-HUB-005 — en-US / tr-TR string swap.
  testWidgets('TC-HUB-005 localizes hub strings en-US and tr-TR',
      (tester) async {
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        locale: const Locale('en', 'US'),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);
    expect(find.text("Let's play!"), findsOneWidget);
    expect(find.byTooltip('Grown-ups'), findsOneWidget);
    expect(find.text('Shape matching'), findsOneWidget);

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        locale: const Locale('tr', 'TR'),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);
    expect(find.text('Hadi oynayalım!'), findsOneWidget);
    expect(find.byTooltip('Büyükler'), findsOneWidget);
    expect(find.text('Şekil eşleştirme'), findsOneWidget);
  });

  // TC-HUB-006 — Semantics / a11y labels on cards + parent exit.
  testWidgets('TC-HUB-006 exposes accessibility labels', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _setLandscape(
        tester,
        width: ScaffoldingViewports.compactPhoneHeight,
        height: ScaffoldingViewports.compactPhoneWidth,
      );
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
        ),
      );
      await _pumpFrames(tester);

      final parentData =
          tester.getSemantics(find.byKey(ChildHubSurface.parentExitKey));
      expect(parentData.label, 'Grown-ups');
      expect(parentData.hint, 'Opening grown-ups gate');
      expect(parentData.flagsCollection.isButton, isTrue);

      final shapeFinder = find.byKey(
        HubActivityCard.cardKey(HubCatalogActivityId.shapeMatching.id),
      );
      final shapeData = tester.getSemantics(shapeFinder);
      expect(shapeData.label, 'Shape matching');
      expect(shapeData.hint, 'Not ready yet');
      expect(shapeData.flagsCollection.isButton, isTrue);
    } finally {
      handle.dispose();
    }
  });

  // TC-HUB-007 — Navigation bounds: Parent exit → gate; settings only via gate.
  testWidgets('TC-HUB-007 navigation bounds keep settings behind Parent Gate',
      (tester) async {
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ParentSettingsSurface.surfaceKey), findsNothing);
    expect(find.byKey(const Key('nav-parent-settings')), findsNothing);

    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-parent-settings')));
    await _pumpFrames(tester);
    expect(find.byKey(ParentSettingsSurface.surfaceKey), findsOneWidget);
  });

  // TC-HUB-008 — Reduced-motion skips decorative tween; audio stub still works.
  testWidgets('TC-HUB-008 reduced-motion and audio stub remain safe',
      (tester) async {
    final audio = RecordingHubAudioGuidance();
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
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: ChildHubSurface(
          game: StubLearningGame(),
          audioGuidance: audio,
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.brandKey), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(
      audio.plays.any((p) => p.cue == HubAudioCue.welcome),
      isTrue,
    );
  });

  // TC-HUB-009 — Playable registry entry can open Flame host; passive cannot.
  testWidgets('TC-HUB-009 only playable registry activities launch host',
      (tester) async {
    final audio = RecordingHubAudioGuidance();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(
          registry: ActivityRegistry([_PlayableShapeMatching()]),
        ),
        audioGuidance: audio,
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.emptyPlayableKey), findsNothing);
    expect(
      find.byKey(
        HubActivityCard.playableBadgeKey(
          HubCatalogActivityId.shapeMatching.id,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        HubActivityCard.cardKey(HubCatalogActivityId.shapeMatching.id),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.playHostKey), findsOneWidget);
    expect(find.byKey(FlameHostPanel.hostKey), findsOneWidget);
    expect(
      audio.plays.any((p) => p.cue == HubAudioCue.playableSelect),
      isTrue,
    );
  });

  // TC-HUB-010 — Audio asset path contract stays locale-tagged and offline.
  test('TC-HUB-010 audio asset paths are locale-tagged and local-only', () {
    expect(
      HubAudioGuidance.assetPath(HubAudioCue.welcome, 'en-US'),
      'assets/audio/hub/en-US/welcome.wav',
    );
    expect(
      HubAudioGuidance.assetPath(HubAudioCue.parentExit, 'tr-TR'),
      'assets/audio/hub/tr-TR/parent_exit.wav',
    );
    expect(hubLocaleTag(const Locale('tr', 'TR')), 'tr-TR');
    expect(hubLocaleTag(const Locale('en', 'US')), 'en-US');
  });
}

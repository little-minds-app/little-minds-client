import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_art.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_card.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_carousel.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_catalog.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
import 'package:little_minds_mobile/config/env_config_badge.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/activity_play_host.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/game/learning_activity.dart';
import 'package:little_minds_mobile/l10n/app_localizations.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';

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
  String get displayName => 'Shape Matching';

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
    expect(find.byKey(ChildHubSurface.worldBackdropKey), findsOneWidget);
    expect(find.text('Little Minds'), findsWidgets);
    expect(find.text("Let's play!"), findsOneWidget);
    expect(find.byKey(const Key('child-hub-placeholder')), findsNothing);
    expect(find.byKey(EnvConfigBadge.badgeKey), findsNothing);
    expect(
      audio.plays.any((p) => p.cue == HubAudioCue.welcome),
      isTrue,
    );
  });

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

    final ids = HubCatalogActivityId.values;
    for (var i = 0; i < ids.length; i++) {
      await tester.tap(find.byKey(HubActivityCarousel.dotKey(i)));
      await tester.pumpAndSettle();
      final id = ids[i];
      expect(find.byKey(HubActivityCard.cardKey(id.id)), findsOneWidget);
      expect(find.byKey(HubActivityCard.passiveBadgeKey(id.id)), findsOneWidget);
      expect(find.byKey(HubActivityArt.artKey(id.id)), findsOneWidget);
      expect(
        find.byKey(HubActivityCard.playableBadgeKey(id.id)),
        findsNothing,
      );
    }

    await tester.tap(find.byKey(HubActivityCarousel.dotKey(0)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(HubActivityCard.cardKey(HubCatalogActivityId.shapeMatching.id)),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.playHostKey), findsNothing);
    expect(
      audio.plays.any((p) => p.cue == HubAudioCue.passiveUnavailable),
      isTrue,
    );
  });

  testWidgets('TC-HUB-004 phone carousel vs tablet 3x2 grid', (tester) async {
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
    expect(find.byKey(ChildHubSurface.activityCarouselKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.carouselIndicatorKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.activityGridKey), findsNothing);
    expect(find.byKey(ChildHubSurface.expandedLayoutKey), findsNothing);
    expect(find.byType(PageView), findsOneWidget);

    final first = tester.getRect(
      find.byKey(HubActivityCard.cardKey(HubCatalogActivityId.shapeMatching.id)),
    );
    expect(first.width, lessThan(ScaffoldingViewports.compactPhoneHeight * 0.5));

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
    expect(find.byKey(ChildHubSurface.activityGridKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.activityCarouselKey), findsNothing);
    expect(find.byKey(ChildHubSurface.carouselIndicatorKey), findsNothing);
    expect(find.byKey(ChildHubSurface.compactLayoutKey), findsNothing);
  });

  testWidgets('TC-HUB-012 carousel snap, dots, reachability, small landscape',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      // iPhone SE-class landscape (smaller than iPhone 15).
      await _setLandscape(tester, width: 667, height: 375);
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
        ),
      );
      await _pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(ChildHubSurface.activityCarouselKey), findsOneWidget);
      expect(HubActivityCarousel.viewportFractionForWidth(667), 0.42);

      // First card fully inside the viewport (padEnds).
      final firstRect = tester.getRect(
        find.byKey(
          HubActivityCard.cardKey(HubCatalogActivityId.shapeMatching.id),
        ),
      );
      expect(firstRect.left, greaterThanOrEqualTo(-1));
      expect(firstRect.right, lessThanOrEqualTo(667 + 1));

      // Snap indicator sync: jump to last via dot.
      await tester.tap(find.byKey(HubActivityCarousel.dotKey(5)));
      await tester.pumpAndSettle();

      final lastDot = tester.getSemantics(
        find.byKey(HubActivityCarousel.dotKey(5)),
      );
      expect(lastDot.flagsCollection.isSelected, Tristate.isTrue);
      final firstDot = tester.getSemantics(
        find.byKey(HubActivityCarousel.dotKey(0)),
      );
      expect(firstDot.flagsCollection.isSelected, isNot(Tristate.isTrue));

      final lastRect = tester.getRect(
        find.byKey(
          HubActivityCard.cardKey(HubCatalogActivityId.objectCategories.id),
        ),
      );
      expect(lastRect.left, greaterThanOrEqualTo(-1));
      expect(lastRect.right, lessThanOrEqualTo(667 + 1));

      // All six pages reachable via dots without overflow.
      for (var i = 0; i < HubCatalogActivityId.values.length; i++) {
        await tester.tap(find.byKey(HubActivityCarousel.dotKey(i)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(
            HubActivityCard.cardKey(HubCatalogActivityId.values[i].id),
          ),
          findsOneWidget,
        );
      }

      // iPhone 15-class landscape fraction.
      expect(
        HubActivityCarousel.viewportFractionForWidth(
          ScaffoldingViewports.compactPhoneHeight,
        ),
        0.34,
      );
    } finally {
      handle.dispose();
    }
  });

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
    expect(find.text('Shape Matching'), findsOneWidget);
    expect(find.text('Coming Soon'), findsWidgets);

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
    expect(find.text('Şekil Eşleştirme'), findsOneWidget);
    expect(find.text('Yakında'), findsWidgets);
  });

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
      expect(shapeData.label, contains('Shape Matching'));
      expect(shapeData.label, contains('Coming Soon'));
      expect(shapeData.label, contains('Not ready yet'));
      expect(shapeData.flagsCollection.isButton, isFalse);
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
      'TC-HUB-011 passive cards are not playable buttons and never open Flame',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final audio = RecordingHubAudioGuidance();
      await _setLandscape(
        tester,
        width: ScaffoldingViewports.compactPhoneHeight,
        height: ScaffoldingViewports.compactPhoneWidth,
      );
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(
            registry: ActivityRegistry([
              _PlayableShapeMatching(),
              _PassiveRegistered(),
            ]),
          ),
          audioGuidance: audio,
        ),
      );
      await _pumpFrames(tester);

      await tester.tap(find.byKey(HubActivityCarousel.dotKey(3)));
      await tester.pumpAndSettle();
      final passiveFinder = find.byKey(
        HubActivityCard.cardKey(HubCatalogActivityId.counting.id),
      );
      final passiveData = tester.getSemantics(passiveFinder);
      expect(passiveData.flagsCollection.isButton, isFalse);
      expect(passiveData.label, contains('Counting'));
      expect(passiveData.label, contains('Coming Soon'));
      expect(passiveData.label, isNot(contains('Play')));

      await tester.tap(find.byKey(HubActivityCarousel.dotKey(0)));
      await tester.pumpAndSettle();
      final playableFinder = find.byKey(
        HubActivityCard.cardKey(HubCatalogActivityId.shapeMatching.id),
      );
      final playableData = tester.getSemantics(playableFinder);
      expect(playableData.flagsCollection.isButton, isTrue);
      expect(playableData.label, 'Shape Matching');
      expect(playableData.hint, 'Play');

      await tester.tap(find.byKey(HubActivityCarousel.dotKey(3)));
      await tester.pumpAndSettle();
      await tester.tap(passiveFinder);
      await _pumpFrames(tester);
      expect(find.byKey(ChildHubSurface.playHostKey), findsNothing);
      expect(find.byKey(ActivityPlayHost.hostKey), findsNothing);
      expect(
        audio.plays.any((p) => p.cue == HubAudioCue.passiveUnavailable),
        isTrue,
      );
    } finally {
      handle.dispose();
    }
  });

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
    expect(find.byKey(ActivityPlayHost.hostKey), findsOneWidget);
    expect(
      audio.plays.any((p) => p.cue == HubAudioCue.playableSelect),
      isTrue,
    );

    await tester.tap(find.byKey(ActivityPlayHost.closeKey));
    await _pumpFrames(tester);
    expect(find.byKey(ChildHubSurface.playHostKey), findsNothing);
    expect(find.byKey(ChildHubSurface.homeKey), findsOneWidget);
  });

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

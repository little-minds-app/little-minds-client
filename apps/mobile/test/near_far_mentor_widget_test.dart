import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/child_hub/hub_activity_catalog.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/config/app_environment.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/l10n/app_localizations.dart';
import 'package:little_minds_mobile/mentor/mentor.dart';
import 'package:little_minds_mobile/near_far/near_far_constants.dart';
import 'package:little_minds_mobile/shell/adaptive_shell.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/near_far_demo_surface.dart';
import 'package:little_minds_mobile/surfaces/near_far_mentor_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';

/// Avoid pumpAndSettle — Flame / progress indicators keep scheduling frames.
Future<void> _pumpFrames(WidgetTester tester, [int times = 12]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _setSurface(
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

AppConfig get _productionConfig => AppConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: Uri.parse('https://api.example.test'),
    );

Widget _localize({
  required Widget child,
  Locale locale = const Locale('en', 'US'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

/// Deterministic wait after Mentor route opens.
///
/// Prefer [LittleMindsApp.mentorInjectedCard] / sync loaders in shell tests —
/// FakeAsync does not complete `rootBundle` fixture I/O, so asset-backed loads
/// hang on the loading spinner forever. Injected cards finish in initState.
Future<void> _waitForMentorContent(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    // Flush build + microtasks (e.g. Future.value loaders). No pumpAndSettle:
    // CircularProgressIndicator / Flame keep scheduling frames.
    await tester.pump();
    final loading = find.byKey(NearFarMentorSurface.loadingKey);
    final view = find.byKey(MentorCardView.viewKey);
    final error = find.byKey(NearFarMentorSurface.errorKey);
    if (loading.evaluate().isEmpty &&
        (view.evaluate().isNotEmpty || error.evaluate().isNotEmpty)) {
      return;
    }
  }
  fail('Mentor surface did not finish loading');
}

Future<void> _expandPromptTile(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await _pumpFrames(tester, 8);
}

Future<void> _openMentorFromHub(WidgetTester tester) async {
  await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
  await _pumpFrames(tester, 8);
  expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);

  await tester.tap(find.byKey(const Key('nav-parent-settings')));
  await _pumpFrames(tester, 8);
  expect(find.byKey(ParentSettingsSurface.surfaceKey), findsOneWidget);
  expect(find.byKey(ParentSettingsSurface.nearFarMentorKey), findsOneWidget);

  await tester.ensureVisible(find.byKey(ParentSettingsSurface.nearFarMentorKey));
  await tester.tap(find.byKey(ParentSettingsSurface.nearFarMentorKey));
  await _pumpFrames(tester, 8);
  expect(find.byKey(NearFarMentorSurface.surfaceKey), findsOneWidget);
  await _waitForMentorContent(tester);
}

class _FailingMentorLoader extends MentorCardFixtureLoader {
  @override
  Future<MentorCardV1> requireNearFar({required String locale}) {
    return Future<MentorCardV1>.error(
      StateError('unsupported schema for $locale'),
    );
  }
}

/// Completes on the microtask queue (no AssetBundle I/O) for FakeAsync tests.
class _ImmediateMentorLoader extends MentorCardFixtureLoader {
  _ImmediateMentorLoader(this._cards);

  final Map<String, MentorCardV1> _cards;

  @override
  Future<MentorCardV1> requireNearFar({required String locale}) {
    final card = _cards[locale];
    if (card == null) {
      return Future<MentorCardV1>.error(StateError('no card for $locale'));
    }
    return Future<MentorCardV1>.value(card);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MentorCardV1 draftCard;
  late MentorCardV1 approvedCard;
  late MentorCardV1 trDraftCard;

  setUpAll(() async {
    final loader = MentorCardFixtureLoader();
    draftCard = await loader.requireNearFar(locale: 'en-US');
    trDraftCard = await loader.requireNearFar(locale: 'tr-TR');
    approvedCard = draftCard.copyWith(reviewStatus: 'approved');
    expect(draftCard.reviewStatus, 'draft');
    expect(
      MentorCardNearFarLinks.resolveMissionId(draftCard),
      NearFarConstants.missionId,
    );
  });

  group('MentorCardView sections + gate (LMP-48)', () {
    testWidgets('TC-MC-W01 approved card shows Why/How/What/Safety/Adaptations',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.compactPhoneWidth,
        height: ScaffoldingViewports.compactPhoneHeight,
      );
      var missionTaps = 0;
      await tester.pumpWidget(
        _localize(
          child: MentorCardView(
            card: approvedCard,
            childAgeMonths: NearFarConstants.focusAgeMonths,
            onOpenMission: () => missionTaps++,
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(MentorCardView.viewKey), findsOneWidget);
      expect(find.byKey(MentorCardView.blockedKey), findsNothing);
      expect(find.byKey(MentorCardView.draftBannerKey), findsNothing);
      expect(find.byKey(MentorCardView.titleKey), findsOneWidget);
      expect(find.text(approvedCard.title), findsOneWidget);
      expect(find.byKey(MentorCardView.whyKey), findsOneWidget);
      expect(find.text(approvedCard.why.summary), findsOneWidget);
      expect(find.byKey(MentorCardView.howKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whatToSayKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whatBeforeKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whatDuringKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whatAfterKey), findsOneWidget);
      // Collapsed by default — section labels remain visible.
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('During'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      await _expandPromptTile(tester, MentorCardView.whatBeforeKey);
      expect(find.text(approvedCard.whatToSay.before.first), findsWidgets);
      await _expandPromptTile(tester, MentorCardView.whatDuringKey);
      expect(find.text(approvedCard.whatToSay.during.first), findsWidgets);
      await _expandPromptTile(tester, MentorCardView.whatAfterKey);
      expect(find.text(approvedCard.whatToSay.after.first), findsWidgets);
      // Safety never collapsed.
      expect(find.byKey(MentorCardView.safetyKey), findsOneWidget);
      expect(find.text(approvedCard.safety.constraints.first), findsOneWidget);
      expect(find.byKey(MentorCardView.adaptationsKey), findsOneWidget);
      expect(find.byKey(MentorCardView.ageKey), findsOneWidget);
      expect(
        find.text('For children aged 30–35 months'),
        findsOneWidget,
      );
      expect(find.textContaining('Fits this'), findsOneWidget);
      expect(find.byKey(MentorCardView.openMissionKey), findsOneWidget);

      await tester.ensureVisible(find.byKey(MentorCardView.openMissionKey));
      await tester.tap(find.byKey(MentorCardView.openMissionKey));
      await _pumpFrames(tester, 4);
      expect(missionTaps, 1);
    });

    testWidgets('TC-MC-W17 phone has no dual-pane empty sidebar',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.compactPhoneWidth,
        height: ScaffoldingViewports.compactPhoneHeight,
      );
      await tester.pumpWidget(
        LittleMindsApp(
        testOnlyAdultAccess: true,
          audioGuidance: RecordingHubAudioGuidance(),
          mentorInjectedCard: approvedCard,
        ),
      );
      await _pumpFrames(tester);
      await _openMentorFromHub(tester);

      expect(find.byKey(AdaptiveShell.dualPaneKey), findsNothing);
      expect(find.byKey(AdaptiveShell.compactChromeKey), findsOneWidget);
      expect(find.byKey(NearFarMentorSurface.scrollKey), findsOneWidget);
      // No horizontal overflow of mentor column on compact phone.
      final viewWidth = tester.view.physicalSize.width;
      final cardWidth = tester.getSize(find.byKey(MentorCardView.viewKey)).width;
      expect(cardWidth, lessThanOrEqualTo(viewWidth));
    });

    testWidgets('TC-MC-W18 large text scale keeps mission CTA reachable',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.compactPhoneWidth,
        height: ScaffoldingViewports.compactPhoneHeight,
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: _localize(
            child: MentorCardView(
              card: approvedCard,
              onOpenMission: () {},
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(MentorCardView.safetyKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(MentorCardView.openMissionKey));
      expect(find.byKey(MentorCardView.openMissionKey), findsOneWidget);
      final size = tester.getSize(find.byKey(MentorCardView.openMissionKey));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('TC-MC-W02 draft without preview is blocked (prod-safe)',
        (tester) async {
      await tester.pumpWidget(
        _localize(
          child: MentorCardView(
            card: draftCard,
            allowDraftPreview: false,
            onOpenMission: () {},
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(MentorCardView.blockedKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whyKey), findsNothing);
      expect(find.byKey(MentorCardView.openMissionKey), findsNothing);
      expect(find.textContaining('draft'), findsOneWidget);
    });

    testWidgets('TC-MC-W03 draft preview shows banner and never hides gate',
        (tester) async {
      await tester.pumpWidget(
        _localize(
          child: MentorCardView(
            card: draftCard,
            allowDraftPreview: true,
            onOpenMission: () {},
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(MentorCardView.draftBannerKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whyKey), findsOneWidget);
      expect(find.byKey(MentorCardView.openMissionKey), findsOneWidget);
      expect(
        MentorCardReviewGate.mayRenderOnParentMentorSurface(draftCard),
        isFalse,
      );
    });

    testWidgets('TC-MC-W04 tr-TR fixture copy renders caregiver sections',
        (tester) async {
      final approvedTr = trDraftCard.copyWith(reviewStatus: 'approved');
      await tester.pumpWidget(
        _localize(
          locale: const Locale('tr', 'TR'),
          child: MentorCardView(card: approvedTr),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text(approvedTr.title), findsOneWidget);
      expect(find.text(approvedTr.why.summary), findsOneWidget);
      expect(find.text('30–35 aylık çocuklar için'), findsOneWidget);
      expect(find.text('Neden'), findsOneWidget);
      expect(find.text('Nasıl'), findsOneWidget);
      expect(find.text('Ne söylenebilir'), findsOneWidget);
      expect(find.text('Sırasında'), findsOneWidget);
      await _expandPromptTile(tester, MentorCardView.whatDuringKey);
      expect(find.text(approvedTr.whatToSay.during.first), findsOneWidget);
    });

    testWidgets('TC-MC-W05 missing mission link hides CTA', (tester) async {
      final noMission = approvedCard.copyWith(linkedMissionIds: const []);
      await tester.pumpWidget(
        _localize(
          child: MentorCardView(
            card: noMission,
            onOpenMission: () {},
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(MentorCardView.whyKey), findsOneWidget);
      expect(find.byKey(MentorCardView.openMissionKey), findsNothing);
    });

    testWidgets('TC-MC-W06 age outside range messaging', (tester) async {
      await tester.pumpWidget(
        _localize(
          child: MentorCardView(
            card: approvedCard,
            childAgeMonths: 48,
          ),
        ),
      );
      await _pumpFrames(tester);
      expect(find.textContaining('Outside'), findsOneWidget);
    });

    testWidgets('TC-MC-W07 semantics label present for mentor card',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _localize(child: MentorCardView(card: approvedCard)),
        );
        await _pumpFrames(tester);

        final data = tester.getSemantics(find.byKey(MentorCardView.viewKey));
        expect(data.label, contains('Parent Play Mentor card'));
        expect(data.label, contains(approvedCard.title));
      } finally {
        handle.dispose();
      }
    });
  });

  group('Parent shell nav + mission (LMP-48)', () {
    testWidgets(
        'TC-MC-W08 Gate → Settings → Mentor → back preserves Gate path',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.compactPhoneWidth,
        height: ScaffoldingViewports.compactPhoneHeight,
      );
      await tester.pumpWidget(
        LittleMindsApp(
        testOnlyAdultAccess: true,
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          config: _productionConfig,
          // Deterministic draft card — no rootBundle under FakeAsync.
          mentorInjectedCard: draftCard,
        ),
      );
      await _pumpFrames(tester);

      await _openMentorFromHub(tester);
      // Production env: draft fixtures stay blocked (no caregiver copy).
      expect(find.byKey(MentorCardView.viewKey), findsOneWidget);
      expect(find.byKey(MentorCardView.blockedKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whyKey), findsNothing);
      expect(find.byKey(MentorCardView.draftBannerKey), findsNothing);

      await tester.tap(find.byKey(const Key('nav-back-from-mentor')));
      await _pumpFrames(tester, 8);
      expect(find.byKey(ParentSettingsSurface.surfaceKey), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-back-from-settings')));
      await _pumpFrames(tester, 8);
      expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-back-hub-from-gate')));
      await _pumpFrames(tester, 8);
      expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    });

    testWidgets(
        'TC-MC-W09 mentor mission CTA opens existing Near/Far demo',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.compactPhoneHeight,
        height: ScaffoldingViewports.compactPhoneWidth,
      );
      await tester.pumpWidget(
        LittleMindsApp(
        testOnlyAdultAccess: true,
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          mentorInjectedCard: draftCard,
        ),
      );
      await _pumpFrames(tester);

      await _openMentorFromHub(tester);
      // Development + debug: draft preview shows content + mission CTA.
      expect(find.byKey(MentorCardView.viewKey), findsOneWidget);
      expect(find.byKey(MentorCardView.draftBannerKey), findsOneWidget);
      expect(find.byKey(MentorCardView.openMissionKey), findsOneWidget);

      await tester.ensureVisible(find.byKey(MentorCardView.openMissionKey));
      await tester.tap(find.byKey(MentorCardView.openMissionKey));
      await _pumpFrames(tester, 20);

      expect(find.byKey(NearFarDemoSurface.surfaceKey), findsOneWidget);
      expect(find.byKey(NearFarMentorSurface.surfaceKey), findsNothing);

      await tester.tap(find.byKey(NearFarDemoSurface.closeKey));
      await _pumpFrames(tester, 20);
      expect(find.byKey(NearFarMentorSurface.surfaceKey), findsOneWidget);
      await _waitForMentorContent(tester);
    });

    testWidgets('TC-MC-W10 hub stays at six tiles (no Near/Far catalog entry)',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.compactPhoneHeight,
        height: ScaffoldingViewports.compactPhoneWidth,
      );
      await tester.pumpWidget(
        LittleMindsApp(
        testOnlyAdultAccess: true,
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
        ),
      );
      await _pumpFrames(tester);

      expect(HubCatalogActivityId.values.length, 6);
      expect(
        HubCatalogActivityId.values.map((e) => e.id),
        isNot(contains(NearFarConstants.activityId)),
      );
      expect(find.byKey(NearFarMentorSurface.surfaceKey), findsNothing);
    });

    testWidgets('TC-MC-W11 phone portrait mentor scrolls to mission CTA',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.compactPhoneWidth,
        height: 640,
      );
      await tester.pumpWidget(
        LittleMindsApp(
        testOnlyAdultAccess: true,
          audioGuidance: RecordingHubAudioGuidance(),
          mentorInjectedCard: draftCard,
        ),
      );
      await _pumpFrames(tester);
      await _openMentorFromHub(tester);

      expect(find.byKey(NearFarMentorSurface.scrollKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(MentorCardView.openMissionKey));
      expect(find.byKey(MentorCardView.openMissionKey), findsOneWidget);
      final missionSize =
          tester.getSize(find.byKey(MentorCardView.openMissionKey));
      expect(missionSize.height, greaterThanOrEqualTo(48));
    });

    testWidgets(
        'TC-MC-W12 tablet mentor uses single-column chrome (no empty sidebar)',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.tabletWidth,
        height: ScaffoldingViewports.tabletHeight,
      );
      await tester.pumpWidget(
        LittleMindsApp(
        testOnlyAdultAccess: true,
          audioGuidance: RecordingHubAudioGuidance(),
          locale: const Locale('en', 'US'),
          // Future.value loader — no AssetBundle; flushes on tester.pump().
          mentorCardLoader: _ImmediateMentorLoader({
            'en-US': draftCard,
            'tr-TR': trDraftCard,
          }),
        ),
      );
      await _pumpFrames(tester);
      await _openMentorFromHub(tester);

      expect(find.byKey(AdaptiveShell.singleColumnWideKey), findsOneWidget);
      expect(find.byKey(AdaptiveShell.dualPaneKey), findsNothing);
      expect(find.byKey(AdaptiveShell.expandedChromeKey), findsNothing);
      expect(find.byKey(MentorCardView.viewKey), findsOneWidget);
      // Centered readable column — not stretched edge-to-edge on iPad.
      final cardBox =
          tester.getRect(find.byKey(MentorCardView.viewKey));
      expect(cardBox.width, lessThanOrEqualTo(NearFarMentorSurface.contentMaxWidth));
    });

    testWidgets('TC-MC-W13 invalid fixture load shows error recovery',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: NearFarMentorSurface(
            loader: _FailingMentorLoader(),
            forceDraftPreview: false,
          ),
        ),
      );
      // Future.error completes on the microtask queue — flush without settle.
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        if (find.byKey(NearFarMentorSurface.errorKey).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.byKey(NearFarMentorSurface.errorKey), findsOneWidget);
      expect(find.byKey(MentorCardView.viewKey), findsNothing);
      expect(find.textContaining('could not be loaded'), findsOneWidget);
    });

    testWidgets(
        'TC-MC-W14 injected approved card on surface shows sections (en-US)',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.compactPhoneWidth,
        height: ScaffoldingViewports.compactPhoneHeight,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: NearFarMentorSurface(
            injectedCard: approvedCard,
            childAgeMonths: 32,
            onOpenNearFarMission: () {},
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(MentorCardView.whyKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whatBeforeKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whatDuringKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whatAfterKey), findsOneWidget);
      expect(find.byKey(MentorCardView.openMissionKey), findsOneWidget);
      expect(find.byKey(MentorCardView.draftBannerKey), findsNothing);
    });
  });

  group('Schema / contract fail-closed (LMP-48 + LMP-47)', () {
    test('TC-MC-W15 unsupported schema_version fails validation', () {
      final bad = Map<String, Object?>.from(draftCard.toJson())
        ..['schema_version'] = '99.0.0';
      final result = validateMentorCard(bad);
      expect(result, isA<MentorCardValidationFail>());
    });

    test('TC-MC-W16 published status is caregiver-ready', () {
      final published = draftCard.copyWith(reviewStatus: 'published');
      expect(
        MentorCardReviewGate.mayRenderOnParentMentorSurface(published),
        isTrue,
      );
      final staged = draftCard.copyWith(reviewStatus: 'staged');
      expect(
        MentorCardReviewGate.mayRenderOnParentMentorSurface(staged),
        isTrue,
      );
    });
  });
}

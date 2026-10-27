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

Future<void> _waitForMentorContent(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 16));
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
  Future<MentorCardV1> requireNearFar({required String locale}) async {
    throw StateError('unsupported schema for $locale');
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
      expect(find.text(approvedCard.whatToSay.before.first), findsOneWidget);
      expect(find.text(approvedCard.whatToSay.during.first), findsOneWidget);
      expect(find.text(approvedCard.whatToSay.after.first), findsOneWidget);
      expect(find.byKey(MentorCardView.safetyKey), findsOneWidget);
      expect(find.byKey(MentorCardView.adaptationsKey), findsOneWidget);
      expect(find.byKey(MentorCardView.ageKey), findsOneWidget);
      expect(find.textContaining('Fits this'), findsOneWidget);
      expect(find.byKey(MentorCardView.openMissionKey), findsOneWidget);

      await tester.ensureVisible(find.byKey(MentorCardView.openMissionKey));
      await tester.tap(find.byKey(MentorCardView.openMissionKey));
      await _pumpFrames(tester, 4);
      expect(missionTaps, 1);
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
      expect(find.text(approvedTr.whatToSay.during.first), findsOneWidget);
      expect(find.text('Neden'), findsOneWidget);
      expect(find.text('Nasıl'), findsOneWidget);
      expect(find.text('Ne söylenebilir'), findsOneWidget);
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
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          config: _productionConfig,
        ),
      );
      await _pumpFrames(tester);

      await _openMentorFromHub(tester);
      // Production env: draft fixtures stay blocked (no caregiver copy).
      expect(find.byKey(MentorCardView.blockedKey), findsOneWidget);
      expect(find.byKey(MentorCardView.whyKey), findsNothing);

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
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
        ),
      );
      await _pumpFrames(tester);

      await _openMentorFromHub(tester);
      // Development + debug: draft preview shows content + mission CTA.
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
        LittleMindsApp(audioGuidance: RecordingHubAudioGuidance()),
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

    testWidgets('TC-MC-W12 tablet layout uses AdaptiveShell expanded chrome',
        (tester) async {
      await _setSurface(
        tester,
        width: ScaffoldingViewports.tabletWidth,
        height: ScaffoldingViewports.tabletHeight,
      );
      await tester.pumpWidget(
        LittleMindsApp(
          audioGuidance: RecordingHubAudioGuidance(),
          locale: const Locale('en', 'US'),
        ),
      );
      await _pumpFrames(tester);
      await _openMentorFromHub(tester);

      expect(find.byKey(AdaptiveShell.expandedChromeKey), findsOneWidget);
      expect(find.byKey(AdaptiveShell.dualPaneKey), findsOneWidget);
      expect(find.byKey(MentorCardView.viewKey), findsOneWidget);
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
      await _pumpFrames(tester, 20);

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

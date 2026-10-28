import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/l10n/app_localizations.dart';
import 'package:little_minds_mobile/screen_time/screen_time.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';
import 'package:little_minds_mobile/surfaces/screen_time_debug_inspector_surface.dart';

Future<void> _pumpFrames(WidgetTester tester, [int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _setPhoneLandscape(WidgetTester tester) async {
  final view = tester.view;
  view.physicalSize = Size(
    ScaffoldingViewports.compactPhoneHeight,
    ScaffoldingViewports.compactPhoneWidth,
  );
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

/// Taller phone portrait — QA controls stay reachable without relying only on
/// ensureVisible through nested shell chrome.
Future<void> _setPhonePortrait(WidgetTester tester) async {
  final view = tester.view;
  view.physicalSize = Size(
    ScaffoldingViewports.compactPhoneWidth,
    ScaffoldingViewports.compactPhoneHeight,
  );
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

Future<void> _setTabletPortrait(WidgetTester tester) async {
  final view = tester.view;
  view.physicalSize = Size(
    ScaffoldingViewports.tabletWidth,
    ScaffoldingViewports.tabletHeight,
  );
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMonotonicClock mono;
  late FakeWallClock wall;
  late InMemoryPersistentStore store;
  late ScreenTimeCoordinator coordinator;

  tearDown(() {
    if (!coordinator.isDisposed && !coordinator.isShuttingDown) {
      coordinator.dispose();
    }
  });

  Future<ScreenTimeCoordinator> readyCoordinator() async {
    mono = FakeMonotonicClock(epochId: 'boot-0');
    wall = FakeWallClock(DateTime.utc(2026, 10, 28, 12));
    store = InMemoryPersistentStore();
    coordinator = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: store,
      tickInterval: Duration.zero,
    );
    await coordinator.initialize();
    return coordinator;
  }

  Future<void> openParentSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-parent-settings')));
    await _pumpFrames(tester);
    expect(find.byKey(ParentSettingsSurface.surfaceKey), findsOneWidget);
  }

  Future<void> openInspectorViaSettings(WidgetTester tester) async {
    await openParentSettings(tester);
    expect(find.byKey(ParentSettingsSurface.screenTimeDebugKey), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(ParentSettingsSurface.screenTimeDebugKey),
    );
    await tester.tap(find.byKey(ParentSettingsSurface.screenTimeDebugKey));
    await _pumpFrames(tester);
    expect(
      find.byKey(ScreenTimeDebugInspectorSurface.surfaceKey),
      findsOneWidget,
    );
  }

  Future<void> tapQa(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await _pumpFrames(tester);
    await tester.tap(finder);
    await _pumpFrames(tester);
  }

  group('entry / placement', () {
    testWidgets('TC-ST-D01 debug entry on Parent Settings (debug builds)',
        (tester) async {
      await _setPhoneLandscape(tester);
      final st = await readyCoordinator();
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      await openParentSettings(tester);

      expect(find.byKey(ParentSettingsSurface.screenTimeDebugKey), findsOneWidget);
      expect(
        find.byKey(ParentSettingsSurface.screenTimeDebugHintKey),
        findsOneWidget,
      );
      expect(find.textContaining('DEBUG'), findsWidgets);
    });

    testWidgets('TC-ST-D02 entry not on Hub; Parent Settings only',
        (tester) async {
      await _setPhoneLandscape(tester);
      final st = await readyCoordinator();
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
      expect(find.byKey(ParentSettingsSurface.screenTimeDebugKey), findsNothing);
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.surfaceKey),
        findsNothing,
      );

      await openParentSettings(tester);
      expect(find.byKey(ParentSettingsSurface.screenTimeDebugKey), findsOneWidget);
      // Mentor / Near-Far entries are separate; inspector is not auto-opened.
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.surfaceKey),
        findsNothing,
      );
    });

    testWidgets('TC-ST-D03 Parent Settings / inspector path does not count',
        (tester) async {
      await _setPhoneLandscape(tester);
      final st = await readyCoordinator();
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      expect(st.isCounting, isTrue);

      await openInspectorViaSettings(tester);
      expect(st.kidsModeShellActive, isFalse);
      expect(st.isCounting, isFalse);

      mono.elapse(const Duration(minutes: 5));
      st.tickForTest();
      expect(st.accountant.accumulatedActiveSeconds, 0);
    });
  });

  group('live inspector + QA controls', () {
    testWidgets('TC-ST-D04 live fields from real coordinator/accountant',
        (tester) async {
      await _setPhoneLandscape(tester);
      final st = await readyCoordinator();
      st.setKidsModeShellActive(true);
      mono.elapse(const Duration(minutes: 4));
      st.tickForTest();
      st.setKidsModeShellActive(false);
      await st.persist();

      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      await openInspectorViaSettings(tester);

      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.debugOnlyBannerKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.budgetSectionKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.lifecycleSectionKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.trustSectionKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.qaSectionKey),
        findsOneWidget,
      );
      expect(find.textContaining('04:00'), findsWidgets);
      expect(find.textContaining(st.accountant.dayKey), findsOneWidget);
      // No prefs key chrome.
      expect(find.textContaining(ScreenTimeSnapshot.storeKey), findsNothing);
      expect(
        find.textContaining(ScreenTimeSnapshot.corruptStoreKey),
        findsNothing,
      );
    });

    testWidgets('TC-ST-D05 set 29:50 leaves ~10s remaining', (tester) async {
      await _setPhonePortrait(tester);
      final st = await readyCoordinator();
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      await openInspectorViaSettings(tester);

      await tapQa(tester, ScreenTimeDebugInspectorSurface.qaNearCapKey);

      expect(st.accountant.accumulatedActiveSeconds, (29 * 60) + 50);
      expect(st.remainingSeconds, 10);
      expect(st.allowsChildPlay, isTrue);
    });

    testWidgets('TC-ST-D06 set 30:00 reaches cap and blocks play',
        (tester) async {
      await _setPhonePortrait(tester);
      final st = await readyCoordinator();
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      await openInspectorViaSettings(tester);

      await tapQa(tester, ScreenTimeDebugInspectorSurface.qaAtCapKey);

      expect(st.accountant.accumulatedActiveSeconds, 30 * 60);
      expect(st.isCapReached, isTrue);
      expect(st.allowsChildPlay, isFalse);
    });

    testWidgets('TC-ST-D07 reset requires confirm; cancel keeps budget',
        (tester) async {
      await _setPhonePortrait(tester);
      final st = await readyCoordinator();
      final qa = ScreenTimeDebugQa(st);
      await qa.setNearCap();

      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      await openInspectorViaSettings(tester);

      await tapQa(tester, ScreenTimeDebugInspectorSurface.qaResetKey);
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.qaResetConfirmDialogKey),
        findsOneWidget,
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byKey(ScreenTimeDebugInspectorSurface.surfaceKey)),
      );
      await tester.tap(find.text(l10n.screenTimeDebugResetCancel));
      await _pumpFrames(tester);
      expect(st.accountant.accumulatedActiveSeconds, (29 * 60) + 50);

      await tapQa(tester, ScreenTimeDebugInspectorSurface.qaResetKey);
      await tester.tap(find.text(l10n.screenTimeDebugResetConfirm));
      await _pumpFrames(tester);
      expect(st.accountant.accumulatedActiveSeconds, 0);
      expect(st.remainingSeconds, 30 * 60);
    });

    testWidgets('TC-ST-D08 persist now + reload round-trip', (tester) async {
      await _setPhonePortrait(tester);
      final st = await readyCoordinator();
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      await openInspectorViaSettings(tester);

      await tapQa(tester, ScreenTimeDebugInspectorSurface.qaNearCapKey);
      await tapQa(tester, ScreenTimeDebugInspectorSurface.qaPersistKey);

      // Mutate in-memory away from store, then reload.
      st.accountant.applyDebugQaAccumulatedSeconds(60);
      expect(st.accountant.accumulatedActiveSeconds, 60);

      await tapQa(tester, ScreenTimeDebugInspectorSurface.qaReloadKey);
      expect(st.accountant.accumulatedActiveSeconds, (29 * 60) + 50);
    });
  });

  group('guards / layouts', () {
    test('TC-ST-D09 runtime guard refuses mutations when not debug-allowed',
        () async {
      final st = await readyCoordinator();
      final qa = ScreenTimeDebugQa(st, mutationsAllowed: () => false);
      expect(qa.setNearCap, throwsA(isA<UnsupportedError>()));
      expect(qa.setAtCap, throwsA(isA<UnsupportedError>()));
      expect(qa.resetBudget, throwsA(isA<UnsupportedError>()));
      expect(qa.reloadFromStore, throwsA(isA<UnsupportedError>()));
      expect(qa.persistNow, throwsA(isA<UnsupportedError>()));
      expect(st.accountant.accumulatedActiveSeconds, 0);
    });

    test('TC-ST-D10 corrupt persistence is not bypassed by QA set', () async {
      store = InMemoryPersistentStore();
      store.corrupt(ScreenTimeSnapshot.storeKey, '{not-json');
      mono = FakeMonotonicClock(epochId: 'boot-0');
      wall = FakeWallClock(DateTime.utc(2026, 10, 28, 12));
      coordinator = ScreenTimeCoordinator.withDependencies(
        monotonicClock: mono,
        wallClock: wall,
        store: store,
        tickInterval: Duration.zero,
      );
      await coordinator.initialize();
      expect(coordinator.accountant.isCorruptPersistence, isTrue);

      final qa = ScreenTimeDebugQa(coordinator);
      expect(qa.setNearCap, throwsA(isA<StateError>()));
      expect(qa.resetBudget, throwsA(isA<StateError>()));
      expect(coordinator.accountant.isCorruptPersistence, isTrue);
      expect(coordinator.allowsChildPlay, isFalse);
    });

    testWidgets('TC-ST-D11 phone landscape inspector layout (F-034)',
        (tester) async {
      await _setPhoneLandscape(tester);
      final st = await readyCoordinator();
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      await openInspectorViaSettings(tester);
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.surfaceKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.qaNearCapKey),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-ST-D11b tablet portrait inspector layout (F-034)',
        (tester) async {
      await _setTabletPortrait(tester);
      final st = await readyCoordinator();
      await tester.pumpWidget(
        LittleMindsApp(
          game: StubLearningGame(),
          audioGuidance: RecordingHubAudioGuidance(),
          screenTime: st,
        ),
      );
      await _pumpFrames(tester);
      await openInspectorViaSettings(tester);
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.surfaceKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ScreenTimeDebugInspectorSurface.qaSectionKey),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-ST-D12 Parent Settings hides entry when callback null',
        (tester) async {
      await _setPhoneLandscape(tester);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ParentSettingsSurface(
            onOpenNearFarDemo: null,
            onOpenNearFarMentor: null,
            onOpenScreenTimeDebug: null,
          ),
        ),
      );
      await _pumpFrames(tester);
      expect(find.byKey(ParentSettingsSurface.screenTimeDebugKey), findsNothing);
    });
  });
}

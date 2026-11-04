import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/screen_time/screen_time.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';

Future<void> _pumpFrames(WidgetTester tester, [int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _setLandscapePhone(WidgetTester tester) async {
  final view = tester.view;
  view.physicalSize = Size(
    ScaffoldingViewports.compactPhoneHeight,
    ScaffoldingViewports.compactPhoneWidth,
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

  // Sync dispose only: awaiting [ScreenTimeCoordinator.shutdownComplete] from
  // a testWidgets tearDown can hang (widget-test FakeAsync zone). Shutdown
  // drain is covered by coordinator / hardening unit tests instead.
  tearDown(() {
    if (!coordinator.isDisposed && !coordinator.isShuttingDown) {
      coordinator.dispose();
    }
  });

  Future<ScreenTimeCoordinator> readyCoordinator({
    int usedMinutes = 0,
  }) async {
    mono = FakeMonotonicClock(epochId: 'boot-0');
    wall = FakeWallClock(DateTime.utc(2026, 10, 27, 12));
    store = InMemoryPersistentStore();
    coordinator = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: store,
      tickInterval: Duration.zero, // tests drive ticks explicitly
    );
    await coordinator.initialize();
    if (usedMinutes > 0) {
      coordinator.setKidsModeShellActive(true);
      mono.elapse(Duration(minutes: usedMinutes));
      coordinator.tickForTest();
      coordinator.setKidsModeShellActive(false);
      await coordinator.persist();
    }
    return coordinator;
  }

  testWidgets('TC-ST-UI-001 Hub counts; Parent Gate stops counting',
      (tester) async {
    await _setLandscapePhone(tester);
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
    // Bootstrap sets Kids Mode active on Hub.
    await tester.pump();
    expect(st.kidsModeShellActive, isTrue);
    expect(st.isCounting, isTrue);

    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    expect(st.kidsModeShellActive, isFalse);
    expect(st.isCounting, isFalse);
  });

  testWidgets('TC-ST-UI-002 cap shows calm boundary and blocks new play',
      (tester) async {
    await _setLandscapePhone(tester);
    final st = await readyCoordinator(usedMinutes: 30);
    expect(st.allowsChildPlay, isFalse);
    expect(st.childPlayBlockReason, ChildPlayBlockReason.dailyCap);

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
        screenTime: st,
      ),
    );
    await _pumpFrames(tester);
    await tester.pump();

    expect(find.byKey(KidsModeCalmBoundary.surfaceKey), findsOneWidget);
    expect(find.text('Time for a break'), findsOneWidget);
    expect(find.text('Ask a grown-up'), findsNothing);
    // Hub chrome still present underneath; 6-tile catalog not redesigned.
    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);

    await tester.tap(find.byKey(KidsModeCalmBoundary.grownUpsKey));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
  });

  testWidgets(
      'TC-ST-UI-002b trust/clock block uses distinct copy; Parent Gate preserved',
      (tester) async {
    await _setLandscapePhone(tester);
    // Seed trusted budget, then cross-day reboot → uncertain + remaining > 0.
    final st = await readyCoordinator(usedMinutes: 5);
    await st.persist();
    st.dispose();
    await st.shutdownComplete;

    mono = FakeMonotonicClock(epochId: 'boot-1');
    wall = FakeWallClock(DateTime.utc(2026, 10, 28, 9));
    coordinator = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: store,
      tickInterval: Duration.zero,
    );
    await coordinator.initialize();
    final blocked = coordinator;
    expect(blocked.accountant.trustState, TrustState.uncertain);
    expect(blocked.accountant.remainingSeconds, greaterThan(0));
    expect(blocked.allowsChildPlay, isFalse);
    expect(blocked.childPlayBlockReason, ChildPlayBlockReason.trustOrStorage);
    expect(blocked.shouldShowCalmBoundary, isTrue);

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
        screenTime: blocked,
      ),
    );
    await _pumpFrames(tester);
    await tester.pump();

    expect(find.byKey(KidsModeCalmBoundary.surfaceKey), findsOneWidget);
    expect(find.text('Ask a grown-up'), findsOneWidget);
    expect(
      find.textContaining('not because today\'s time is used up'),
      findsOneWidget,
    );
    // Must NOT reuse daily-cap exhaustion copy when remaining > 0.
    expect(find.text('Time for a break'), findsNothing);
    expect(find.textContaining('enough screen time for today'), findsNothing);

    await tester.tap(find.byKey(KidsModeCalmBoundary.grownUpsKey));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
  });

  testWidgets('TC-ST-UI-003 budget survives Parent Gate round-trip',
      (tester) async {
    await _setLandscapePhone(tester);
    final st = await readyCoordinator(usedMinutes: 12);

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
        screenTime: st,
      ),
    );
    await _pumpFrames(tester);
    await tester.pump();

    expect(st.accountant.accumulatedActiveSeconds, 12 * 60);

    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('nav-back-hub-from-gate')));
    await _pumpFrames(tester);
    await tester.pump();

    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(st.accountant.accumulatedActiveSeconds, 12 * 60);
    expect(st.allowsChildPlay, isTrue);
  });

  testWidgets('TC-ST-UI-004 nav/lifecycle regression checklist', (tester) async {
    await _setLandscapePhone(tester);
    final st = await readyCoordinator(usedMinutes: 5);

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
        screenTime: st,
      ),
    );
    await _pumpFrames(tester);
    await tester.pump();

    // 1) Hub active → counting
    expect(st.kidsModeShellActive, isTrue);
    expect(st.isCounting, isTrue);

    // 2) Profiles (child transition) still Kids Mode
    await tester.tap(find.byKey(ChildHubSurface.profilesKey));
    await _pumpFrames(tester);
    expect(st.kidsModeShellActive, isTrue);

    await tester.tap(find.byKey(const Key('nav-back-hub')));
    await _pumpFrames(tester);

    // 3) Parent Gate stops counting; budget intact
    final before = st.accountant.accumulatedActiveSeconds;
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    expect(st.kidsModeShellActive, isFalse);
    expect(st.isCounting, isFalse);
    expect(st.accountant.accumulatedActiveSeconds, before);

    // 4) App background while on Gate still non-counting
    st.handleAppLifecycleForTest(AppLifecycleState.paused);
    expect(st.isCounting, isFalse);
    st.handleAppLifecycleForTest(AppLifecycleState.resumed);

    // 5) Return Hub resumes counting without reset
    await tester.tap(find.byKey(const Key('nav-back-hub-from-gate')));
    await _pumpFrames(tester);
    await tester.pump();
    expect(st.kidsModeShellActive, isTrue);
    expect(st.isCounting, isTrue);
    expect(st.accountant.accumulatedActiveSeconds, before);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/screen_time/screen_time.dart';

/// Deterministic UAT repro for LMP-49 clock-skew / Reset Budget failure.
///
/// Mirrors confirmed simulator failure:
/// trusted play → persist → app restart on a later calendar day (new
/// monotonic epoch) → restore sets uncertain + clockSkewDetected →
/// allowsChildPlay false → Debug Reset Budget must restore play.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMonotonicClock mono;
  late FakeWallClock wall;
  late InMemoryPersistentStore store;
  late ScreenTimeCoordinator coordinator;

  final dayA = DateTime.utc(2026, 11, 3, 16); // matches UAT day key
  final dayB = DateTime.utc(2026, 11, 4, 10);

  tearDown(() async {
    if (!coordinator.isDisposed && !coordinator.isShuttingDown) {
      coordinator.dispose();
    }
    await coordinator.shutdownComplete;
  });

  Future<ScreenTimeCoordinator> boot({
    required FakeMonotonicClock clock,
    required FakeWallClock wallClock,
    required PersistentStore persistent,
  }) async {
    mono = clock;
    wall = wallClock;
    coordinator = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: persistent,
      tickInterval: Duration.zero,
      persistEveryTicks: 1,
    );
    await coordinator.initialize();
    return coordinator;
  }

  Future<ScreenTimeSnapshot> readPersisted(PersistentStore persistent) async {
    final raw = await persistent.read(ScreenTimeSnapshot.storeKey);
    expect(raw, isNotNull);
    final parsed = ScreenTimeSnapshot.tryDecode(raw!);
    expect(parsed, isNotNull);
    return parsed!;
  }

  test(
      'TC-ST-UAT-01 trusted → accumulate → restart next day → skew/uncertain '
      '→ Reset Budget restores play', () async {
    store = InMemoryPersistentStore();
    await boot(
      clock: FakeMonotonicClock(epochId: 'boot-0'),
      wallClock: FakeWallClock(dayA),
      persistent: store,
    );

    // Trusted start + accumulation (UAT: ~156s used, remaining budget).
    expect(coordinator.accountant.trustState, TrustState.trusted);
    expect(coordinator.allowsChildPlay, isTrue);
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(seconds: 156));
    coordinator.tickForTest();
    coordinator.setKidsModeShellActive(false);
    await coordinator.persist();

    expect(coordinator.accountant.dayKey, '2026-11-03');
    expect(coordinator.accountant.accumulatedActiveSeconds, 156);
    expect(coordinator.accountant.remainingSeconds, 1800 - 156);
    expect(coordinator.accountant.isCapReached, isFalse);
    expect(coordinator.accountant.clockSkewDetected, isFalse);

    final checkpoint = await readPersisted(store);
    expect(checkpoint.epochId, 'boot-0');
    expect(checkpoint.lastWallEpochMs, dayA.millisecondsSinceEpoch);
    expect(checkpoint.dayKey, '2026-11-03');
    expect(checkpoint.trustState, TrustState.trusted);

    // App/sim restart: new monotonic epoch; wall advances to next calendar day.
    // Clocks remain "synced" — no backward wall jump — but epoch continuity
    // is broken across a day boundary (ADR-016 fail-closed → uncertain).
    coordinator.dispose();
    await coordinator.shutdownComplete;

    await boot(
      clock: FakeMonotonicClock(epochId: 'boot-1'),
      wallClock: FakeWallClock(dayB),
      persistent: store,
    );

    // Exact bad transition recorded for UAT:
    // trust: uncertain, clockSkew: true, remaining budget, allowsChildPlay: false
    expect(coordinator.accountant.trustState, TrustState.uncertain);
    expect(coordinator.accountant.clockSkewDetected, isTrue);
    expect(coordinator.accountant.isCorruptPersistence, isFalse);
    expect(coordinator.storageFailed, isFalse);
    expect(coordinator.accountant.dayKey, '2026-11-03');
    expect(coordinator.accountant.accumulatedActiveSeconds, 156);
    expect(coordinator.accountant.remainingSeconds, 1644);
    expect(coordinator.accountant.isCapReached, isFalse);
    expect(coordinator.allowsChildPlay, isFalse);

    // restore() reconciles then persist()s fail-closed markers (ADR-016).
    // Pre-restart checkpoint (above) had wall=dayA / epoch=boot-0; current wall
    // is dayB with a new epoch — that gap is why clockSkew/uncertain fired.
    final afterRestore = await readPersisted(store);
    expect(afterRestore.trustState, TrustState.uncertain);
    expect(afterRestore.clockSkewDetected, isTrue);
    expect(afterRestore.dayKey, '2026-11-03');
    expect(afterRestore.accumulatedActiveSeconds, 156);
    expect(afterRestore.epochId, 'boot-1');
    expect(afterRestore.lastWallEpochMs, dayB.millisecondsSinceEpoch);
    expect(
      afterRestore.lastWallEpochMs - checkpoint.lastWallEpochMs,
      greaterThan(0),
      reason: 'persisted wall advanced vs pre-restart checkpoint',
    );

    // Pre-fix defect: resetBudget refused degraded trust → Hub stayed blocked.
    // Fix: debug Reset recovers via forceNewLocalDay.
    final qa = ScreenTimeDebugQa(coordinator);
    await qa.resetBudget();

    expect(coordinator.accountant.trustState, TrustState.trusted);
    expect(coordinator.accountant.clockSkewDetected, isFalse);
    expect(coordinator.accountant.dayKey, '2026-11-04');
    expect(coordinator.accountant.accumulatedActiveSeconds, 0);
    expect(coordinator.accountant.remainingSeconds, 1800);
    expect(coordinator.allowsChildPlay, isTrue);

    final afterReset = await readPersisted(store);
    expect(afterReset.trustState, TrustState.trusted);
    expect(afterReset.clockSkewDetected, isFalse);
    expect(afterReset.epochId, 'boot-1');
    expect(afterReset.dayKey, '2026-11-04');
    expect(afterReset.accumulatedActiveSeconds, 0);

    // Kids Hub can count again after reset.
    coordinator.setKidsModeShellActive(true);
    expect(coordinator.isCounting, isTrue);
    mono.elapse(const Duration(seconds: 10));
    coordinator.tickForTest();
    expect(coordinator.accountant.accumulatedActiveSeconds, 10);
  });

  test(
      'TC-ST-UAT-02 setNearCap still refuses while uncertain (no bypass)',
      () async {
    store = InMemoryPersistentStore();
    await boot(
      clock: FakeMonotonicClock(epochId: 'boot-0'),
      wallClock: FakeWallClock(dayA),
      persistent: store,
    );
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(seconds: 156));
    coordinator.tickForTest();
    coordinator.setKidsModeShellActive(false);
    await coordinator.persist();
    coordinator.dispose();
    await coordinator.shutdownComplete;

    await boot(
      clock: FakeMonotonicClock(epochId: 'boot-1'),
      wallClock: FakeWallClock(dayB),
      persistent: store,
    );
    expect(coordinator.accountant.trustState, TrustState.uncertain);

    final qa = ScreenTimeDebugQa(coordinator);
    expect(qa.setNearCap, throwsA(isA<StateError>()));
    expect(qa.setAtCap, throwsA(isA<StateError>()));
    expect(coordinator.accountant.trustState, TrustState.uncertain);
    expect(coordinator.allowsChildPlay, isFalse);
  });

  test(
      'TC-ST-UAT-03 same-day restart does not set clockSkew / uncertain',
      () async {
    store = InMemoryPersistentStore();
    await boot(
      clock: FakeMonotonicClock(epochId: 'boot-0'),
      wallClock: FakeWallClock(dayA),
      persistent: store,
    );
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(seconds: 156));
    coordinator.tickForTest();
    coordinator.setKidsModeShellActive(false);
    await coordinator.persist();
    coordinator.dispose();
    await coordinator.shutdownComplete;

    // Same calendar day, new epoch — budget kept, trusted (not UAT failure).
    await boot(
      clock: FakeMonotonicClock(epochId: 'boot-1'),
      wallClock: FakeWallClock(dayA.add(const Duration(hours: 2))),
      persistent: store,
    );
    expect(coordinator.accountant.trustState, TrustState.trusted);
    expect(coordinator.accountant.clockSkewDetected, isFalse);
    expect(coordinator.accountant.accumulatedActiveSeconds, 156);
    expect(coordinator.allowsChildPlay, isTrue);
  });
}

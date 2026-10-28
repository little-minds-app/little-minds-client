import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/game/game_lifecycle_phase.dart';
import 'package:little_minds_mobile/screen_time/screen_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMonotonicClock mono;
  late FakeWallClock wall;
  late InMemoryPersistentStore store;
  late ScreenTimeCoordinator coordinator;

  final day0 = DateTime.utc(2026, 10, 27, 10);

  tearDown(() async {
    if (!coordinator.isDisposed && !coordinator.isShuttingDown) {
      coordinator.dispose();
    }
    await coordinator.shutdownComplete;
  });

  Future<ScreenTimeCoordinator> fresh({
    Duration tickInterval = Duration.zero, // no periodic timer in unit tests
  }) async {
    mono = FakeMonotonicClock(epochId: 'boot-0');
    wall = FakeWallClock(day0);
    store = InMemoryPersistentStore();
    coordinator = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: store,
      tickInterval: tickInterval,
      persistEveryTicks: 1,
    );
    await coordinator.initialize();
    return coordinator;
  }

  test('TC-ST-LIF-001 restore then Kids Mode shell starts counting', () async {
    await fresh();
    expect(coordinator.isCounting, isFalse);

    coordinator.setKidsModeShellActive(true);
    expect(coordinator.isCounting, isTrue);
    expect(coordinator.allowsChildPlay, isTrue);

    mono.elapse(const Duration(minutes: 2));
    coordinator.tickForTest();
    expect(coordinator.accountant.accumulatedActiveSeconds, 2 * 60);
  });

  test('TC-ST-LIF-002 background stops counting; resume continues', () async {
    await fresh();
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(minutes: 1));
    coordinator.tickForTest();

    coordinator.handleAppLifecycleForTest(AppLifecycleState.paused);
    expect(coordinator.isCounting, isFalse);
    mono.elapse(const Duration(minutes: 5));
    coordinator.tickForTest();
    expect(coordinator.accountant.accumulatedActiveSeconds, 60);

    coordinator.handleAppLifecycleForTest(AppLifecycleState.resumed);
    expect(coordinator.isCounting, isTrue);
    mono.elapse(const Duration(minutes: 1));
    coordinator.tickForTest();
    expect(coordinator.accountant.accumulatedActiveSeconds, 2 * 60);
  });

  test('TC-ST-LIF-003 parent path / leave Kids Mode stops counting', () async {
    await fresh();
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(minutes: 3));
    coordinator.tickForTest();
    coordinator.setKidsModeShellActive(false);
    expect(coordinator.isCounting, isFalse);
    mono.elapse(const Duration(minutes: 10));
    expect(coordinator.accountant.accumulatedActiveSeconds, 3 * 60);
  });

  test('TC-ST-LIF-004 gameplay pause excludes time; running counts', () async {
    await fresh();
    coordinator.setKidsModeShellActive(true);
    coordinator.setGameplayPhase(GameLifecyclePhase.running);
    mono.elapse(const Duration(minutes: 1));
    coordinator.tickForTest();

    coordinator.setGameplayPhase(GameLifecyclePhase.paused);
    expect(coordinator.isCounting, isFalse);
    mono.elapse(const Duration(minutes: 4));
    expect(coordinator.accountant.accumulatedActiveSeconds, 60);

    coordinator.setGameplayPhase(GameLifecyclePhase.running);
    expect(coordinator.isCounting, isTrue);
  });

  test('TC-ST-LIF-005 duplicate Kids Mode enter does not double-start', () async {
    await fresh();
    coordinator.setKidsModeShellActive(true);
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(minutes: 2));
    coordinator.tickForTest();
    expect(coordinator.accountant.accumulatedActiveSeconds, 2 * 60);
  });

  test('TC-ST-LIF-006 cap blocks child play and stops accumulation', () async {
    await fresh();
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(minutes: 30));
    coordinator.tickForTest();

    expect(coordinator.isCapReached, isTrue);
    expect(coordinator.allowsChildPlay, isFalse);
    expect(coordinator.shouldShowCalmBoundary, isTrue);
    expect(coordinator.isCounting, isFalse);

    mono.elapse(const Duration(minutes: 5));
    coordinator.tickForTest();
    expect(coordinator.accountant.accumulatedActiveSeconds, 30 * 60);
  });

  test('TC-ST-LIF-007 persistence round-trip across coordinator instances', () async {
    await fresh();
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(minutes: 8));
    coordinator.tickForTest();
    coordinator.setKidsModeShellActive(false);
    await coordinator.persist();

    final mono2 = FakeMonotonicClock(epochId: 'boot-0', elapsed: mono.elapsed());
    final wall2 = FakeWallClock(day0);
    final next = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono2,
      wallClock: wall2,
      store: store,
      tickInterval: Duration.zero,
    );
    await next.initialize();
    expect(next.accountant.accumulatedActiveSeconds, 8 * 60);
    expect(next.allowsChildPlay, isTrue);
    next.dispose();
  });

  test('TC-ST-LIF-008 storage failure fail-closes without silent fresh day', () async {
    mono = FakeMonotonicClock();
    wall = FakeWallClock(day0);
    coordinator = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: _ThrowingStore(),
    );
    await coordinator.initialize();

    expect(coordinator.storageFailed, isTrue);
    expect(coordinator.allowsChildPlay, isFalse);
    expect(coordinator.shouldShowCalmBoundary, isTrue);
    expect(coordinator.remainingSeconds, 0);

    coordinator.setKidsModeShellActive(true);
    expect(coordinator.isCounting, isFalse);
  });

  test('TC-ST-LIF-009 never auto-recovers trust / forceNewLocalDay', () async {
    await fresh();
    // Seed uncertain via epoch change across days on accountant, then wrap.
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(minutes: 20));
    coordinator.tickForTest();
    coordinator.setKidsModeShellActive(false);
    await coordinator.persist();

    mono.reboot(newEpochId: 'boot-1');
    wall.set(DateTime.utc(2026, 10, 28, 9));
    final next = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: store,
      tickInterval: Duration.zero,
    );
    await next.initialize();

    expect(next.accountant.trustState, TrustState.uncertain);
    expect(next.allowsChildPlay, isFalse);
    expect(next.accountant.accumulatedActiveSeconds, 20 * 60);
    // No silent fresh day / no recoverTrust side effect.
    expect(next.accountant.remainingSeconds, 10 * 60);
    next.dispose();
  });

  test('TC-ST-LIF-010 nav churn does not reset budget', () async {
    await fresh();
    coordinator.setKidsModeShellActive(true);
    mono.elapse(const Duration(minutes: 5));
    coordinator.tickForTest();
    coordinator.setKidsModeShellActive(false); // parent
    coordinator.setKidsModeShellActive(true); // back to hub
    coordinator.setKidsModeShellActive(false);
    coordinator.setKidsModeShellActive(true);
    expect(coordinator.accountant.accumulatedActiveSeconds, 5 * 60);
  });
}

final class _ThrowingStore implements PersistentStore {
  @override
  Future<String?> read(String key) async {
    throw StateError('unavailable');
  }

  @override
  Future<void> write(String key, String value) async {
    throw StateError('unavailable');
  }

  @override
  Future<void> delete(String key) async {
    throw StateError('unavailable');
  }
}

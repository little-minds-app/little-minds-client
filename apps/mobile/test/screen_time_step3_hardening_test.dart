import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/screen_time/screen_time.dart';

/// Delays each write; records payloads in completion order.
final class _DelayedStore implements PersistentStore {
  _DelayedStore({this.delay = const Duration(milliseconds: 20)});

  final Duration delay;
  final Map<String, String> data = {};
  final List<String> writeCompletions = [];
  var failNextWrite = false;
  var inFlightWrites = 0;
  var maxInFlightWrites = 0;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    inFlightWrites++;
    if (inFlightWrites > maxInFlightWrites) {
      maxInFlightWrites = inFlightWrites;
    }
    await Future<void>.delayed(delay);
    if (failNextWrite) {
      failNextWrite = false;
      inFlightWrites--;
      throw StateError('injected write failure');
    }
    data[key] = value;
    writeCompletions.add(value);
    inFlightWrites--;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMonotonicClock mono;
  late FakeWallClock wall;
  late ScreenTimeCoordinator coordinator;

  final day0 = DateTime.utc(2026, 10, 27, 12);

  tearDown(() {
    coordinator.dispose();
  });

  Future<ScreenTimeCoordinator> fresh({
    PersistentStore? store,
    Duration tickInterval = Duration.zero,
  }) async {
    mono = FakeMonotonicClock(epochId: 'boot-0');
    wall = FakeWallClock(day0);
    coordinator = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: store ?? InMemoryPersistentStore(),
      tickInterval: tickInterval,
      persistEveryTicks: 1,
    );
    await coordinator.initialize();
    return coordinator;
  }

  group('persist serialization / races', () {
    test('TC-ST-H01 overlapping persist calls never concurrent writes', () async {
      final store = _DelayedStore(delay: const Duration(milliseconds: 30));
      await fresh(store: store);
      coordinator.setKidsModeShellActive(true);
      mono.elapse(const Duration(minutes: 1));
      coordinator.tickForTest();

      final a = coordinator.persist();
      mono.elapse(const Duration(minutes: 2));
      coordinator.tickForTest();
      final b = coordinator.persist();
      await Future.wait<void>([a, b]);

      expect(store.maxInFlightWrites, 1, reason: 'writes must be serialized');
      expect(store.writeCompletions, isNotEmpty);
      // Latest completed write reflects the later accumulated seconds.
      final last = ScreenTimeSnapshot.tryDecode(store.writeCompletions.last);
      expect(last, isNotNull);
      expect(last!.accumulatedActiveSeconds, 3 * 60);
    });

    test('TC-ST-H02 persist write failure fail-closes without fresh day', () async {
      final store = _DelayedStore(delay: Duration.zero);
      await fresh(store: store);
      coordinator.setKidsModeShellActive(true);
      mono.elapse(const Duration(minutes: 4));
      coordinator.tickForTest();
      await coordinator.persist();
      expect(coordinator.accountant.accumulatedActiveSeconds, 4 * 60);

      store.failNextWrite = true;
      await expectLater(coordinator.persist(), throwsA(isA<StateError>()));
      expect(coordinator.storageFailed, isTrue);
      expect(coordinator.allowsChildPlay, isFalse);
      expect(coordinator.isCounting, isFalse);
      // No silent reset of prior budget in memory before fail-closed gate.
      expect(coordinator.accountant.accumulatedActiveSeconds, 4 * 60);
    });
  });

  group('cap timeliness', () {
    test('TC-ST-H10 nextCapCheckDelay shrinks below tickInterval near cap',
        () async {
      await fresh(tickInterval: const Duration(seconds: 15));
      coordinator.setKidsModeShellActive(true);
      mono.elapse(const Duration(minutes: 29, seconds: 50));
      coordinator.tickForTest();

      expect(coordinator.remainingSeconds, 10);
      expect(
        coordinator.nextCapCheckDelay(),
        const Duration(seconds: 10),
        reason: 'must not wait a full 15s when only 10s remain',
      );
      expect(
        coordinator.maxCapEnforcementDelay,
        const Duration(seconds: 15),
      );
    });

    test('TC-ST-H11 mid-budget delay equals tickInterval', () async {
      await fresh(tickInterval: const Duration(seconds: 15));
      coordinator.setKidsModeShellActive(true);
      mono.elapse(const Duration(minutes: 5));
      coordinator.tickForTest();
      expect(coordinator.remainingSeconds, greaterThan(15));
      expect(coordinator.nextCapCheckDelay(), const Duration(seconds: 15));
    });

    test('TC-ST-H12 exact remaining tick enforces cap boundary', () async {
      await fresh();
      coordinator.setKidsModeShellActive(true);
      mono.elapse(const Duration(minutes: 29, seconds: 59));
      coordinator.tickForTest();
      expect(coordinator.isCapReached, isFalse);
      expect(coordinator.allowsChildPlay, isTrue);

      mono.elapse(const Duration(seconds: 1));
      coordinator.tickForTest();
      expect(coordinator.isCapReached, isTrue);
      expect(coordinator.allowsChildPlay, isFalse);
      expect(coordinator.isCounting, isFalse);
    });
  });

  group('bootstrap / fail-closed', () {
    test('TC-ST-H20 FailClosedPersistentStore blocks play after initialize',
        () async {
      mono = FakeMonotonicClock();
      wall = FakeWallClock(day0);
      coordinator = ScreenTimeCoordinator.withDependencies(
        monotonicClock: mono,
        wallClock: wall,
        store: const FailClosedPersistentStore(),
        tickInterval: Duration.zero,
      );
      await coordinator.initialize();
      expect(coordinator.storageFailed, isTrue);
      expect(coordinator.allowsChildPlay, isFalse);
      expect(coordinator.shouldShowCalmBoundary, isTrue);
      coordinator.setKidsModeShellActive(true);
      expect(coordinator.isCounting, isFalse);
    });

    test('TC-ST-H21 corrupt snapshot stays blocked — no child reset API',
        () async {
      final store = InMemoryPersistentStore();
      store.corrupt(ScreenTimeSnapshot.storeKey, '{bad');
      await fresh(store: store);
      expect(coordinator.accountant.isCorruptPersistence, isTrue);
      expect(coordinator.allowsChildPlay, isFalse);
      // Coordinator exposes no recoverTrust surface for children.
      expect(coordinator.remainingSeconds, 0);
    });
  });
}

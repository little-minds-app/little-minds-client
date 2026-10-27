import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/screen_time/screen_time.dart';

void main() {
  late FakeMonotonicClock mono;
  late FakeWallClock wall;
  late InMemoryPersistentStore store;
  late ScreenTimeAccountant accountant;

  final day0 = DateTime.utc(2026, 10, 27, 10, 0, 0);

  Future<ScreenTimeAccountant> fresh({
    DailyPolicy policy = DailyPolicy.defaultThirtyMinutes,
    DateTime? wallStart,
    Duration monoStart = Duration.zero,
    String epochId = 'boot-0',
  }) async {
    mono = FakeMonotonicClock(epochId: epochId, elapsed: monoStart);
    wall = FakeWallClock(wallStart ?? day0);
    store = InMemoryPersistentStore();
    accountant = ScreenTimeAccountant(
      monotonicClock: mono,
      wallClock: wall,
      store: store,
      policy: policy,
    );
    await accountant.restore();
    return accountant;
  }

  Future<ScreenTimeAccountant> restoreFrom(InMemoryPersistentStore existing) async {
    accountant = ScreenTimeAccountant(
      monotonicClock: mono,
      wallClock: wall,
      store: existing,
      policy: DailyPolicy.defaultThirtyMinutes,
    );
    await accountant.restore();
    return accountant;
  }

  group('start / pause / resume / stop', () {
    test('TC-ST-001 only explicitly started intervals accumulate', () async {
      await fresh();
      mono.elapse(const Duration(minutes: 5));
      expect(accountant.accumulatedActiveSeconds, 0);

      accountant.startActive();
      mono.elapse(const Duration(minutes: 3));
      expect(accountant.accumulatedActiveSeconds, 3 * 60);

      accountant.pauseActive();
      mono.elapse(const Duration(minutes: 10));
      expect(accountant.accumulatedActiveSeconds, 3 * 60);
      expect(accountant.isActive, isFalse);
    });

    test('TC-ST-002 pause and background-equivalent gaps are excluded', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 2));
      accountant.pauseActive(); // pause
      mono.elapse(const Duration(minutes: 4)); // would-be background
      accountant.resumeActive();
      mono.elapse(const Duration(minutes: 1));
      accountant.stopActive();
      mono.elapse(const Duration(minutes: 9));
      expect(accountant.accumulatedActiveSeconds, 3 * 60);
      expect(accountant.remainingSeconds, 27 * 60);
    });

    test('TC-ST-003 double start does not reset or double-count', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 2));
      accountant.startActive(); // no-op
      mono.elapse(const Duration(minutes: 2));
      accountant.stopActive();
      expect(accountant.accumulatedActiveSeconds, 4 * 60);
    });

    test('TC-ST-004 repeated pause/stop are idempotent', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 1));
      accountant.pauseActive();
      accountant.pauseActive();
      accountant.stopActive();
      accountant.stopActive();
      expect(accountant.accumulatedActiveSeconds, 60);
      expect(accountant.isActive, isFalse);
    });

    test('TC-ST-005 resume after pause continues without double-count', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(seconds: 30));
      accountant.pauseActive();
      accountant.resumeActive();
      mono.elapse(const Duration(seconds: 30));
      accountant.stopActive();
      expect(accountant.accumulatedActiveSeconds, 60);
    });
  });

  group('30-minute cap boundary', () {
    test('TC-ST-010 remaining is never negative', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 45));
      accountant.tick();
      expect(accountant.remainingSeconds, 0);
      expect(accountant.accumulatedActiveSeconds, 30 * 60);
      expect(accountant.isCapReached, isTrue);
    });

    test('TC-ST-011 enforces exactly at 30 minutes', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 29, seconds: 59));
      expect(accountant.isCapReached, isFalse);
      expect(accountant.remainingSeconds, 1);

      mono.elapse(const Duration(seconds: 1));
      accountant.tick();
      expect(accountant.isCapReached, isTrue);
      expect(accountant.remainingSeconds, 0);
      expect(accountant.accumulatedActiveSeconds, 30 * 60);
      expect(accountant.isActive, isFalse);
    });

    test('TC-ST-012 start while at cap is a no-op', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 30));
      accountant.tick();
      expect(accountant.isCapReached, isTrue);

      accountant.startActive();
      mono.elapse(const Duration(minutes: 5));
      expect(accountant.accumulatedActiveSeconds, 30 * 60);
      expect(accountant.isActive, isFalse);
    });
  });

  group('persist + restore', () {
    test('TC-ST-020 round-trips accumulated seconds across restore', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 7));
      accountant.stopActive();
      await accountant.persist();

      final saved = store;
      mono.elapse(const Duration(minutes: 1));
      await restoreFrom(saved);

      expect(accountant.accumulatedActiveSeconds, 7 * 60);
      expect(accountant.dayKey, '2026-10-27');
      expect(accountant.trustState, TrustState.trusted);
      expect(accountant.isActive, isFalse);
    });

    test('TC-ST-021 open interval is committed on persist', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 2));
      await accountant.persist();

      final raw = await store.read(ScreenTimeSnapshot.storeKey);
      final snap = ScreenTimeSnapshot.tryDecode(raw);
      expect(snap, isNotNull);
      expect(snap!.accumulatedActiveSeconds, 2 * 60);
    });
  });

  group('midnight rollover with monotonic evidence', () {
    test('TC-ST-030 grants new day when monotonic covers midnight gap', () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 23, 50));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 5));
      accountant.stopActive();
      await accountant.persist();
      expect(accountant.accumulatedActiveSeconds, 5 * 60);

      // Continuous process: wall crosses midnight and mono advances ≥ 10 min.
      wall.set(DateTime.utc(2026, 10, 28, 0, 5));
      mono.elapse(const Duration(minutes: 15));
      accountant.tick();

      expect(accountant.dayKey, '2026-10-28');
      expect(accountant.accumulatedActiveSeconds, 0);
      expect(accountant.trustState, TrustState.trusted);
      expect(accountant.remainingSeconds, 30 * 60);
    });

    test('TC-ST-031 forward wall alone does not grant a new day', () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 12));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 12));
      accountant.stopActive();
      await accountant.persist();

      // Jump wall to next calendar day but mono only advances 1s.
      wall.set(DateTime.utc(2026, 10, 28, 12));
      mono.elapse(const Duration(seconds: 1));
      accountant.tick();

      expect(accountant.dayKey, '2026-10-27');
      expect(accountant.accumulatedActiveSeconds, 12 * 60);
      expect(accountant.trustState, TrustState.guarded);
      expect(accountant.clockSkewDetected, isTrue);
      expect(accountant.remainingSeconds, 18 * 60);
      expect(accountant.allowsKidsModeUsage, isFalse);
    });

    test('TC-ST-032 splits active interval across midnight without loss', () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 23, 50));
      accountant.startActive();
      // 10 min before midnight + 10 min after = 20 min continuous active.
      wall.set(DateTime.utc(2026, 10, 28, 0, 10));
      mono.elapse(const Duration(minutes: 20));
      accountant.tick();

      expect(accountant.dayKey, '2026-10-28');
      expect(accountant.trustState, TrustState.trusted);
      // Post-midnight slice only (10 minutes); pre-midnight stayed on old day.
      expect(accountant.accumulatedActiveSeconds, 10 * 60);
      expect(accountant.remainingSeconds, 20 * 60);
      expect(accountant.isActive, isTrue);
    });

    test('TC-ST-033 calendar midnight gap used (not hard-coded 24h)', () async {
      // Checkpoint at 21:00 → calendar midnight is 3h away, not 24h.
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 21, 0));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 1));
      accountant.stopActive();
      await accountant.persist();

      wall.set(DateTime.utc(2026, 10, 28, 0, 0));
      // Mono covers the real 3h calendar gap, far less than 24h.
      mono.elapse(const Duration(hours: 3));
      accountant.tick();

      expect(accountant.dayKey, '2026-10-28');
      expect(accountant.trustState, TrustState.trusted);
      expect(accountant.accumulatedActiveSeconds, 0);

      final last = DateTime.utc(2026, 10, 27, 21);
      final next = ScreenTimeAccountant.startOfNextLocalDay(last);
      expect(next.difference(DateTime.utc(2026, 10, 27)), const Duration(days: 1));
      expect(
        next.difference(last),
        const Duration(hours: 3),
        reason: 'evidence gap is calendar midnight distance, not +24h from now',
      );
    });

    test('TC-ST-034 startOfNextLocalDay is calendar-based for local kind', () {
      // Local construction: next midnight is date+1 at 00:00, not +Duration(hours:24)
      // from an arbitrary afternoon instant.
      final afternoon = DateTime(2026, 10, 27, 15, 30);
      final next = ScreenTimeAccountant.startOfNextLocalDay(afternoon);
      expect(next, DateTime(2026, 10, 28));
      expect(next.hour, 0);
      expect(
        next,
        isNot(afternoon.add(const Duration(hours: 24))),
        reason: 'must not use +24h from afternoon wall time',
      );
    });
  });

  group('clock skew', () {
    test('TC-ST-040 backward wall clock must not reset budget', () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 18));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 20));
      accountant.stopActive();
      await accountant.persist();

      wall.set(DateTime.utc(2026, 10, 26, 18));
      mono.elapse(const Duration(minutes: 1));
      accountant.tick();

      expect(accountant.dayKey, '2026-10-27');
      expect(accountant.accumulatedActiveSeconds, 20 * 60);
      expect(accountant.trustState, TrustState.guarded);
      expect(accountant.clockSkewDetected, isTrue);
      expect(accountant.remainingSeconds, 10 * 60);
      expect(accountant.allowsKidsModeUsage, isFalse);
    });

    test('TC-ST-041 backward skew commits open interval before guarding', () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 18));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 4));
      wall.set(DateTime.utc(2026, 10, 26, 18));
      accountant.tick();

      expect(accountant.accumulatedActiveSeconds, 4 * 60);
      expect(accountant.isActive, isFalse);
      expect(accountant.trustState, TrustState.guarded);
    });
  });

  group('offline restart / uncertain recovery', () {
    test('TC-ST-050 epoch change on later calendar day → uncertain, no new 30m',
        () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 16));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 25));
      accountant.stopActive();
      await accountant.persist();

      // Simulate app kill + next calendar day with new monotonic epoch.
      mono.reboot(newEpochId: 'boot-1');
      wall.set(DateTime.utc(2026, 10, 28, 9));
      await restoreFrom(store);

      expect(accountant.trustState, TrustState.uncertain);
      expect(accountant.dayKey, '2026-10-27');
      expect(accountant.accumulatedActiveSeconds, 25 * 60);
      expect(accountant.remainingSeconds, 5 * 60);
      expect(accountant.isCapReached, isFalse);
      expect(accountant.allowsKidsModeUsage, isFalse);
    });

    test('TC-ST-051 explicit keepPersistedBudget recovery', () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 16));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 25));
      accountant.stopActive();
      await accountant.persist();

      mono.reboot(newEpochId: 'boot-1');
      wall.set(DateTime.utc(2026, 10, 28, 9));
      await restoreFrom(store);

      accountant.recoverTrust(TrustRecovery.keepPersistedBudget);
      expect(accountant.trustState, TrustState.trusted);
      expect(accountant.dayKey, '2026-10-27');
      expect(accountant.accumulatedActiveSeconds, 25 * 60);
      expect(accountant.allowsKidsModeUsage, isTrue);
    });

    test('TC-ST-052 explicit forceNewLocalDay recovery', () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 16));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 25));
      accountant.stopActive();
      await accountant.persist();

      mono.reboot(newEpochId: 'boot-1');
      wall.set(DateTime.utc(2026, 10, 28, 9));
      await restoreFrom(store);

      accountant.recoverTrust(TrustRecovery.forceNewLocalDay);
      expect(accountant.trustState, TrustState.trusted);
      expect(accountant.dayKey, '2026-10-28');
      expect(accountant.accumulatedActiveSeconds, 0);
      expect(accountant.remainingSeconds, 30 * 60);
    });

    test('TC-ST-053 same-day restart restores budget without uncertain', () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 11));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 8));
      accountant.stopActive();
      await accountant.persist();

      mono.reboot(newEpochId: 'boot-1');
      wall.set(DateTime.utc(2026, 10, 27, 15));
      await restoreFrom(store);

      expect(accountant.trustState, TrustState.trusted);
      expect(accountant.dayKey, '2026-10-27');
      expect(accountant.accumulatedActiveSeconds, 8 * 60);
    });

    test('TC-ST-054 recoverTrust is no-op when already trusted', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 3));
      accountant.stopActive();

      accountant.recoverTrust(TrustRecovery.forceNewLocalDay);
      expect(accountant.dayKey, '2026-10-27');
      expect(accountant.accumulatedActiveSeconds, 3 * 60);
      expect(accountant.trustState, TrustState.trusted);
    });

    test('TC-ST-055 degraded blocks start/resume; tick/persist do not auto-recover',
        () async {
      await fresh(wallStart: DateTime.utc(2026, 10, 27, 12));
      accountant.startActive();
      mono.elapse(const Duration(minutes: 6));
      accountant.stopActive();
      await accountant.persist();

      wall.set(DateTime.utc(2026, 10, 28, 12));
      mono.elapse(const Duration(seconds: 1));
      accountant.tick();
      expect(accountant.trustState, TrustState.guarded);

      accountant.startActive();
      accountant.resumeActive();
      mono.elapse(const Duration(minutes: 10));
      expect(accountant.isActive, isFalse);
      expect(accountant.accumulatedActiveSeconds, 6 * 60);

      await accountant.persist();
      expect(accountant.trustState, TrustState.guarded);
      expect(accountant.allowsKidsModeUsage, isFalse);
    });
  });

  group('corrupted / missing persistence', () {
    test('TC-ST-060 present-but-invalid does not grant silent fresh 30m', () async {
      await fresh();
      accountant.startActive();
      mono.elapse(const Duration(minutes: 9));
      accountant.stopActive();
      await accountant.persist();

      const corruptRaw = '{not-json';
      store.corrupt(ScreenTimeSnapshot.storeKey, corruptRaw);

      mono = FakeMonotonicClock(epochId: 'boot-0');
      wall = FakeWallClock(day0);
      await restoreFrom(store);

      expect(accountant.isCorruptPersistence, isTrue);
      expect(accountant.trustState, TrustState.guarded);
      expect(accountant.allowsKidsModeUsage, isFalse);
      expect(accountant.remainingSeconds, 0);
      expect(accountant.isCapReached, isTrue);
      // Primary evidence preserved; sidecar copy written.
      expect(await store.read(ScreenTimeSnapshot.storeKey), corruptRaw);
      expect(await store.read(ScreenTimeSnapshot.corruptStoreKey), corruptRaw);

      accountant.startActive();
      mono.elapse(const Duration(minutes: 5));
      expect(accountant.isActive, isFalse);
      expect(accountant.remainingSeconds, 0);
    });

    test('TC-ST-061 missing required fields treated as invalid, not first-run',
        () async {
      store = InMemoryPersistentStore();
      store.corrupt(
        ScreenTimeSnapshot.storeKey,
        '{"schema_version":1,"day_key":"2026-10-27"}',
      );
      mono = FakeMonotonicClock(epochId: 'boot-0');
      wall = FakeWallClock(day0);
      await restoreFrom(store);

      expect(accountant.isCorruptPersistence, isTrue);
      expect(accountant.trustState, TrustState.guarded);
      expect(accountant.allowsKidsModeUsage, isFalse);
      expect(accountant.remainingSeconds, 0);
      expect(
        await store.read(ScreenTimeSnapshot.storeKey),
        '{"schema_version":1,"day_key":"2026-10-27"}',
      );
    });

    test('TC-ST-062 empty store seeds default 30-minute policy (first run)',
        () async {
      await fresh();
      expect(accountant.policy.dailyCapSeconds, 30 * 60);
      expect(accountant.remainingSeconds, 30 * 60);
      expect(accountant.trustState, TrustState.trusted);
      expect(accountant.isCorruptPersistence, isFalse);
      expect(accountant.allowsKidsModeUsage, isTrue);
    });

    test('TC-ST-063 persist while corrupt does not overwrite primary evidence',
        () async {
      store = InMemoryPersistentStore();
      const raw = 'totally-broken';
      store.corrupt(ScreenTimeSnapshot.storeKey, raw);
      mono = FakeMonotonicClock(epochId: 'boot-0');
      wall = FakeWallClock(day0);
      await restoreFrom(store);

      await accountant.persist();
      expect(await store.read(ScreenTimeSnapshot.storeKey), raw);
      expect(accountant.trustState, TrustState.guarded);
    });

    test('TC-ST-064 corrupt keepPersistedBudget does not grant fresh 30m',
        () async {
      store = InMemoryPersistentStore();
      store.corrupt(ScreenTimeSnapshot.storeKey, '{bad');
      mono = FakeMonotonicClock(epochId: 'boot-0');
      wall = FakeWallClock(day0);
      await restoreFrom(store);

      accountant.recoverTrust(TrustRecovery.keepPersistedBudget);
      expect(accountant.remainingSeconds, 0);
      expect(accountant.allowsKidsModeUsage, isFalse);
      expect(accountant.isCapReached, isTrue);
      // Evidence sidecar retained while still not fully recovered to trusted.
      expect(await store.read(ScreenTimeSnapshot.corruptStoreKey), '{bad');
    });

    test('TC-ST-065 forceNewLocalDay after corrupt is explicit parent path',
        () async {
      store = InMemoryPersistentStore();
      store.corrupt(ScreenTimeSnapshot.storeKey, '{bad');
      mono = FakeMonotonicClock(epochId: 'boot-0');
      wall = FakeWallClock(day0);
      await restoreFrom(store);

      accountant.recoverTrust(TrustRecovery.forceNewLocalDay);
      await accountant.persist();

      expect(accountant.trustState, TrustState.trusted);
      expect(accountant.remainingSeconds, 30 * 60);
      expect(accountant.allowsKidsModeUsage, isTrue);
      expect(accountant.isCorruptPersistence, isFalse);
      final snap =
          ScreenTimeSnapshot.tryDecode(await store.read(ScreenTimeSnapshot.storeKey));
      expect(snap, isNotNull);
      expect(snap!.trustState, TrustState.trusted);
      expect(await store.read(ScreenTimeSnapshot.corruptStoreKey), isNull);
    });

    test('TC-ST-066 SnapshotLoadResult distinguishes missing vs invalid', () {
      expect(ScreenTimeSnapshot.load(null).isMissing, isTrue);
      expect(ScreenTimeSnapshot.load('').isMissing, isTrue);
      expect(ScreenTimeSnapshot.load('{nope').isInvalid, isTrue);
      expect(ScreenTimeSnapshot.load('{nope').raw, '{nope');

      const snap = ScreenTimeSnapshot(
        schemaVersion: 1,
        dayKey: '2026-10-27',
        accumulatedActiveSeconds: 1,
        dailyCapSeconds: 1800,
        timeZoneId: 'UTC',
        lastWallEpochMs: 1,
        lastMonotonicMs: 1,
        epochId: 'boot-0',
        trustState: TrustState.trusted,
      );
      expect(ScreenTimeSnapshot.load(snap.encode()).isValid, isTrue);
    });
  });

  group('invariants', () {
    test('TC-ST-070 requires restore before use', () {
      mono = FakeMonotonicClock();
      wall = FakeWallClock(day0);
      store = InMemoryPersistentStore();
      accountant = ScreenTimeAccountant(
        monotonicClock: mono,
        wallClock: wall,
        store: store,
      );
      expect(accountant.startActive, throwsStateError);
    });

    test('TC-ST-071 dayKeyFor formats YYYY-MM-DD', () {
      expect(
        ScreenTimeAccountant.dayKeyFor(DateTime.utc(2026, 3, 5)),
        '2026-03-05',
      );
    });

    test('TC-ST-072 snapshot codec round-trip', () {
      const snap = ScreenTimeSnapshot(
        schemaVersion: 1,
        dayKey: '2026-10-27',
        accumulatedActiveSeconds: 90,
        dailyCapSeconds: 1800,
        timeZoneId: 'UTC',
        lastWallEpochMs: 1000,
        lastMonotonicMs: 2000,
        epochId: 'boot-0',
        trustState: TrustState.trusted,
      );
      final decoded = ScreenTimeSnapshot.tryDecode(snap.encode());
      expect(decoded, isNotNull);
      expect(decoded!.accumulatedActiveSeconds, 90);
      expect(decoded.trustState, TrustState.trusted);
    });
  });
}

import 'daily_policy.dart';
import 'monotonic_clock.dart';
import 'persistent_store.dart';
import 'screen_time_snapshot.dart';
import 'trust_recovery.dart';
import 'trust_state.dart';
import 'wall_clock.dart';

/// Single source of truth for **local** daily Kids Mode active screen time.
///
/// ## Counting rules (LMP-49 Step 1 / F-010 / ADR-016 §35.3)
/// - Only explicitly [startActive] / [resumeActive] intervals accumulate.
/// - [pauseActive] / [stopActive] close the open interval; background/pause
///   callers simply must not leave an interval open (wiring is Step 2).
/// - Start/resume while already active is a no-op (no double-count).
/// - Pause/stop while inactive is a no-op (idempotent).
/// - Remaining is always ≥ 0; cap is enforced at exactly
///   [DailyPolicy.dailyCapSeconds].
///
/// ## Day rollover (conservative)
/// - Day key = local calendar `YYYY-MM-DD` from [WallClock] under policy TZ
///   scaffolding.
/// - **Backward wall clock** → keep persisted day + budget;
///   [TrustState.guarded].
/// - **Forward wall alone** → must not grant a new day. Rollover requires the
///   same monotonic [MonotonicClock.epochId] and monotonic elapsed covering at
///   least the wall duration from the last checkpoint to the next local
///   midnight.
/// - **Restart / epoch change** with a later calendar day →
///   [TrustState.uncertain]; no silent fresh 30 minutes. Use [recoverTrust]
///   explicitly.
///
/// ## Offline clock-tamper limits (documented, not mitigated here)
/// This accountant is **not tamper-proof**. A user who edits [PersistentStore],
/// spoofs clocks, or clears app data can defeat local enforcement. Secure
/// storage, server trusted time, and reset_history reconciliation (ADR-016)
/// are required for stronger guarantees and are out of Step 1 scope.
final class ScreenTimeAccountant {
  ScreenTimeAccountant({
    required MonotonicClock monotonicClock,
    required WallClock wallClock,
    required this._store,
    this._policy = DailyPolicy.defaultThirtyMinutes,
    this.storeKey = ScreenTimeSnapshot.storeKey,
  })  : _monotonic = monotonicClock,
        _wall = wallClock;

  final MonotonicClock _monotonic;
  final WallClock _wall;
  final PersistentStore _store;
  DailyPolicy _policy;
  final String storeKey;

  bool _restored = false;
  String _dayKey = '';
  int _accumulatedSeconds = 0;
  TrustState _trustState = TrustState.trusted;
  bool _clockSkewDetected = false;
  int _lastWallEpochMs = 0;
  int _lastMonotonicMs = 0;
  String _epochId = '';

  /// When non-null, an active Kids Mode interval is open at this monotonic mark.
  Duration? _activeStartedAt;

  DailyPolicy get policy => _policy;

  bool get isRestored => _restored;

  String get dayKey => _dayKey;

  TrustState get trustState => _trustState;

  bool get clockSkewDetected => _clockSkewDetected;

  bool get isActive => _activeStartedAt != null;

  /// Closed intervals only (excludes the open active interval).
  int get closedAccumulatedSeconds => _accumulatedSeconds;

  /// Closed + open interval, clamped to the daily cap.
  int get accumulatedActiveSeconds => _totalActiveSeconds();

  int get remainingSeconds {
    final remaining = _policy.dailyCapSeconds - accumulatedActiveSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  Duration get remaining => Duration(seconds: remainingSeconds);

  bool get isCapReached => remainingSeconds <= 0;

  bool get isTrustDegraded => _trustState.isDegraded;

  /// Load durable state. Call once at startup before Kids Mode use.
  ///
  /// Corrupted / missing data starts a fresh trusted day for the current wall
  /// calendar. Degraded trust from a valid snapshot is preserved.
  Future<void> restore() async {
    final raw = await _store.read(storeKey);
    final snapshot = ScreenTimeSnapshot.tryDecode(raw);
    final wallNow = _wall.now();
    final monoNow = _monotonic.elapsed();

    if (snapshot == null) {
      _beginFreshDay(
        dayKeyFor(wallNow),
        wallNow: wallNow,
        monoNow: monoNow,
        trust: TrustState.trusted,
        skew: false,
      );
      _restored = true;
      await persist();
      return;
    }

    _policy = DailyPolicy(
      dailyCapSeconds: snapshot.dailyCapSeconds > 0
          ? snapshot.dailyCapSeconds
          : _policy.dailyCapSeconds,
      timeZoneId: snapshot.timeZoneId.isNotEmpty
          ? snapshot.timeZoneId
          : _policy.timeZoneId,
    );
    _dayKey = snapshot.dayKey;
    _accumulatedSeconds = _clampSeconds(snapshot.accumulatedActiveSeconds);
    _trustState = snapshot.trustState;
    _clockSkewDetected = snapshot.clockSkewDetected;
    _lastWallEpochMs = snapshot.lastWallEpochMs;
    _lastMonotonicMs = snapshot.lastMonotonicMs;
    _epochId = snapshot.epochId;
    _activeStartedAt = null;
    _restored = true;

    _reconcileCalendar(wallNow: wallNow, monoNow: monoNow);
    await persist();
  }

  /// Begin counting an active Kids Mode foreground interval.
  ///
  /// Idempotent: if already active, does not restart the open interval.
  void startActive() {
    _ensureRestored();
    _reconcileCalendar(wallNow: _wall.now(), monoNow: _monotonic.elapsed());
    if (isCapReached) {
      _activeStartedAt = null;
      return;
    }
    if (_activeStartedAt != null) return;
    _activeStartedAt = _monotonic.elapsed();
    _checkpointClocks();
  }

  /// Alias for [startActive] after a pause — same idempotent semantics.
  void resumeActive() => startActive();

  /// Stop accumulating (pause / background / mission handoff). Idempotent.
  void pauseActive() {
    _ensureRestored();
    _commitOpenInterval();
    _reconcileCalendar(wallNow: _wall.now(), monoNow: _monotonic.elapsed());
    _checkpointClocks();
  }

  /// End the active interval (exit Kids Mode). Idempotent.
  void stopActive() => pauseActive();

  /// Re-read clocks: commit open whole seconds, apply rollover/skew, clamp cap.
  void tick() {
    _ensureRestored();
    _foldOpenWholeSeconds();
    _reconcileCalendar(wallNow: _wall.now(), monoNow: _monotonic.elapsed());
    if (_totalActiveSeconds() >= _policy.dailyCapSeconds) {
      _commitOpenInterval();
    }
    _checkpointClocks();
  }

  /// Flush checkpoint to [PersistentStore]. Commits any open interval first,
  /// then re-opens it when still under the cap.
  Future<void> persist() async {
    _ensureRestored();
    final wasActive = _activeStartedAt != null;
    _commitOpenInterval();
    _checkpointClocks();
    final snapshot = ScreenTimeSnapshot(
      schemaVersion: ScreenTimeSnapshot.currentSchemaVersion,
      dayKey: _dayKey,
      accumulatedActiveSeconds: _accumulatedSeconds,
      dailyCapSeconds: _policy.dailyCapSeconds,
      timeZoneId: _policy.timeZoneId,
      lastWallEpochMs: _lastWallEpochMs,
      lastMonotonicMs: _lastMonotonicMs,
      epochId: _epochId.isEmpty ? _monotonic.epochId : _epochId,
      trustState: _trustState,
      clockSkewDetected: _clockSkewDetected,
    );
    await _store.write(storeKey, snapshot.encode());
    if (wasActive && _accumulatedSeconds < _policy.dailyCapSeconds) {
      _activeStartedAt = _monotonic.elapsed();
    }
  }

  /// Explicit recovery for [TrustState.uncertain] / [TrustState.guarded].
  void recoverTrust(TrustRecovery recovery) {
    _ensureRestored();
    _commitOpenInterval();
    final wallNow = _wall.now();
    final monoNow = _monotonic.elapsed();
    switch (recovery) {
      case TrustRecovery.keepPersistedBudget:
        _trustState = TrustState.trusted;
        _checkpointClocks(wallNow: wallNow, monoNow: monoNow);
      case TrustRecovery.forceNewLocalDay:
        _beginFreshDay(
          dayKeyFor(wallNow),
          wallNow: wallNow,
          monoNow: monoNow,
          trust: TrustState.trusted,
          skew: false,
        );
    }
  }

  /// Local calendar day key `YYYY-MM-DD` from a wall instant.
  static String dayKeyFor(DateTime wall) {
    final y = wall.year.toString().padLeft(4, '0');
    final m = wall.month.toString().padLeft(2, '0');
    final d = wall.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Next local midnight at or after [wall]'s calendar day boundary that ends
  /// the day containing [wall]. If [wall] is exactly midnight, returns that
  /// instant (zero ms remaining in "day already started" edge — callers treat
  /// ≤0 as satisfied only when combined with a later [dayKey]).
  static DateTime startOfNextLocalDay(DateTime wall) {
    return DateTime(wall.year, wall.month, wall.day).add(const Duration(days: 1));
  }

  void _ensureRestored() {
    if (!_restored) {
      throw StateError(
        'ScreenTimeAccountant.restore() must be called before use',
      );
    }
  }

  void _beginFreshDay(
    String day, {
    required DateTime wallNow,
    required Duration monoNow,
    required TrustState trust,
    required bool skew,
  }) {
    _dayKey = day;
    _accumulatedSeconds = 0;
    _trustState = trust;
    _clockSkewDetected = skew;
    _activeStartedAt = null;
    _epochId = _monotonic.epochId;
    _lastWallEpochMs = wallNow.millisecondsSinceEpoch;
    _lastMonotonicMs = monoNow.inMilliseconds;
  }

  void _checkpointClocks({DateTime? wallNow, Duration? monoNow}) {
    final wall = wallNow ?? _wall.now();
    final mono = monoNow ?? _monotonic.elapsed();
    _lastWallEpochMs = wall.millisecondsSinceEpoch;
    _lastMonotonicMs = mono.inMilliseconds;
    if (_epochId.isEmpty) {
      _epochId = _monotonic.epochId;
    }
  }

  int _openElapsedSeconds() {
    final started = _activeStartedAt;
    if (started == null) return 0;
    final delta = _monotonic.elapsed() - started;
    if (delta.isNegative) return 0;
    return delta.inSeconds;
  }

  int _totalActiveSeconds() {
    final total = _accumulatedSeconds + _openElapsedSeconds();
    return _clampSeconds(total);
  }

  /// Fold whole open seconds into the closed accumulator without closing.
  void _foldOpenWholeSeconds() {
    final started = _activeStartedAt;
    if (started == null) return;
    final add = _openElapsedSeconds();
    if (add <= 0) return;
    final room = _policy.dailyCapSeconds - _accumulatedSeconds;
    if (room <= 0) {
      _accumulatedSeconds = _policy.dailyCapSeconds;
      _activeStartedAt = null;
      return;
    }
    if (add >= room) {
      _accumulatedSeconds = _policy.dailyCapSeconds;
      _activeStartedAt = null;
      return;
    }
    _accumulatedSeconds += add;
    _activeStartedAt = started + Duration(seconds: add);
  }

  /// Commit open interval into closed accumulator and clear active mark.
  void _commitOpenInterval() {
    final started = _activeStartedAt;
    if (started == null) return;
    final add = _openElapsedSeconds();
    final room = _policy.dailyCapSeconds - _accumulatedSeconds;
    if (add >= room) {
      _accumulatedSeconds = _policy.dailyCapSeconds;
    } else {
      _accumulatedSeconds = _clampSeconds(_accumulatedSeconds + add);
    }
    _activeStartedAt = null;
  }

  int _clampSeconds(int seconds) {
    if (seconds < 0) return 0;
    if (seconds > _policy.dailyCapSeconds) return _policy.dailyCapSeconds;
    return seconds;
  }

  /// Rebuild a wall [DateTime] matching [wallNow]'s UTC/local kind from epoch ms.
  DateTime _wallFromEpochMs(int epochMs, DateTime wallNow) {
    if (wallNow.isUtc) {
      return DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }

  void _reconcileCalendar({
    required DateTime wallNow,
    required Duration monoNow,
  }) {
    if (_dayKey.isEmpty) {
      _beginFreshDay(
        dayKeyFor(wallNow),
        wallNow: wallNow,
        monoNow: monoNow,
        trust: TrustState.trusted,
        skew: false,
      );
      return;
    }

    final currentDay = dayKeyFor(wallNow);
    if (currentDay == _dayKey) {
      // Same calendar day. Epoch change mid-day: drop unverifiable open gap,
      // keep accumulated budget, refresh epoch markers.
      if (_epochId != _monotonic.epochId) {
        _activeStartedAt = null;
        _epochId = _monotonic.epochId;
        _lastMonotonicMs = monoNow.inMilliseconds;
        _lastWallEpochMs = wallNow.millisecondsSinceEpoch;
      }
      return;
    }

    if (currentDay.compareTo(_dayKey) < 0) {
      // Wall rolled back — do not reset budget.
      _clockSkewDetected = true;
      _trustState = TrustState.guarded;
      _activeStartedAt = null;
      return;
    }

    // currentDay > _dayKey — candidate rollover.
    final sameEpoch = _epochId == _monotonic.epochId;
    if (!sameEpoch) {
      // Restart / reboot across calendar change: no silent new day.
      _trustState = TrustState.uncertain;
      _clockSkewDetected = true;
      _activeStartedAt = null;
      _epochId = _monotonic.epochId;
      _lastMonotonicMs = monoNow.inMilliseconds;
      _lastWallEpochMs = wallNow.millisecondsSinceEpoch;
      return;
    }

    if (!_trustState.allowsAutomaticRollover) {
      // Already degraded — still refuse automatic grant.
      _activeStartedAt = null;
      return;
    }

    final lastWall = _wallFromEpochMs(_lastWallEpochMs, wallNow);
    final nextMidnight = startOfNextLocalDay(lastWall);
    final msToMidnight =
        nextMidnight.millisecondsSinceEpoch - lastWall.millisecondsSinceEpoch;
    final monoDeltaMs = monoNow.inMilliseconds - _lastMonotonicMs;

    if (msToMidnight <= 0 || monoDeltaMs >= msToMidnight) {
      _beginFreshDay(
        currentDay,
        wallNow: wallNow,
        monoNow: monoNow,
        trust: TrustState.trusted,
        skew: false,
      );
      return;
    }

    // Forward wall jump without enough monotonic evidence.
    _clockSkewDetected = true;
    _trustState = TrustState.guarded;
    _activeStartedAt = null;
  }
}

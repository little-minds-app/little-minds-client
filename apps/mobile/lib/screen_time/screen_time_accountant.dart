import 'package:flutter/foundation.dart';

import 'daily_policy.dart';
import 'monotonic_clock.dart';
import 'persistent_store.dart';
import 'screen_time_snapshot.dart';
import 'snapshot_load_result.dart';
import 'trust_recovery.dart';
import 'trust_state.dart';
import 'wall_clock.dart';

/// Dual-gate for debug QA mutations (LMP-49 Step 3.4).
///
/// Requires **both** [kDebugMode] and `(mutationsAllowed?.call() ?? true)`.
/// Release/profile builds always refuse, even if a caller injects
/// `mutationsAllowed: () => true`. Debug tests may inject `() => false`.
bool screenTimeDebugMutationsPermitted({bool Function()? mutationsAllowed}) =>
    kDebugMode && (mutationsAllowed?.call() ?? true);

/// Single source of truth for **local** daily Kids Mode active screen time.
///
/// ## Counting rules (LMP-49 Step 1.1 / F-010 / ADR-016 §35.3)
/// - Only explicitly [startActive] / [resumeActive] intervals accumulate.
/// - [pauseActive] / [stopActive] close the open interval; background/pause
///   callers simply must not leave an interval open (wiring is Step 2).
/// - Start/resume while already active is a no-op (no double-count).
/// - Pause/stop while inactive is a no-op (idempotent).
/// - Remaining is always ≥ 0; cap is enforced at exactly
///   [DailyPolicy.dailyCapSeconds].
/// - When trust is degraded or persistence is corrupt, [allowsKidsModeUsage] is
///   false — [startActive] / [resumeActive] refuse to open intervals.
///
/// ## Day rollover (conservative, DST/TZ-aware local midnight)
/// - Day key = local calendar `YYYY-MM-DD` from [WallClock] components (the
///   wall instant must already be in the household timezone).
/// - Local midnight uses **calendar date components**
///   (`DateTime(year, month, day + 1)` / UTC equivalent) via
///   [startOfNextLocalDay] — never `Duration(days: 1)` / `Duration(hours: 24)`.
///   On DST spring-forward / fall-back, wall elapsed between consecutive local
///   midnights may be 23h or 25h; that wall span is the monotonic evidence
///   required for automatic rollover.
/// - Active intervals that span midnight are **split**: pre-midnight seconds
///   stay on the old day (then discarded with the day reset); post-midnight
///   seconds carry into the new day (no double-count, no loss).
/// - **Backward wall clock** → commit open time to persisted day; [TrustState.guarded].
/// - **Forward wall alone** → must not grant a new day.
/// - **Restart / epoch change** with a later calendar day →
///   [TrustState.uncertain]; no silent fresh 30 minutes.
///
/// ## Corrupted persistence
/// - **Missing** key → legitimate first run → fresh trusted day.
/// - **Present but invalid** → [TrustState.guarded], Kids Mode blocked, remaining
///   fail-closed at 0; raw bytes preserved under
///   [ScreenTimeSnapshot.corruptStoreKey] and the primary key is **not**
///   overwritten with a silent fresh snapshot.
///
/// ## Trust recovery auth boundaries
/// See [TrustRecovery]. [recoverTrust] is never invoked automatically. Child
/// surfaces must not call it; [TrustRecovery.forceNewLocalDay] is
/// parent-gate / re-auth only (wiring later).
///
/// ## Offline clock-tamper limits (documented, not mitigated here)
/// This accountant is **not tamper-proof**. A user who edits [PersistentStore],
/// spoofs clocks, or clears app data can defeat local enforcement. Secure
/// storage, server trusted time, and reset_history reconciliation (ADR-016)
/// are required for stronger guarantees and are out of Step 1.1 scope.
final class ScreenTimeAccountant {
  ScreenTimeAccountant({
    required MonotonicClock monotonicClock,
    required WallClock wallClock,
    required this._store,
    this._policy = DailyPolicy.defaultThirtyMinutes,
    this.storeKey = ScreenTimeSnapshot.storeKey,
    this.corruptStoreKey = ScreenTimeSnapshot.corruptStoreKey,
  })  : _monotonic = monotonicClock,
        _wall = wallClock;

  final MonotonicClock _monotonic;
  final WallClock _wall;
  final PersistentStore _store;
  DailyPolicy _policy;
  final String storeKey;
  final String corruptStoreKey;

  bool _restored = false;
  String _dayKey = '';
  int _accumulatedSeconds = 0;
  TrustState _trustState = TrustState.trusted;
  bool _clockSkewDetected = false;
  int _lastWallEpochMs = 0;
  int _lastMonotonicMs = 0;
  String _epochId = '';

  /// True when primary store value was present but invalid.
  bool _corruptPersistence = false;

  /// When non-null, an active Kids Mode interval is open at this monotonic mark.
  Duration? _activeStartedAt;

  DailyPolicy get policy => _policy;

  bool get isRestored => _restored;

  String get dayKey => _dayKey;

  TrustState get trustState => _trustState;

  bool get clockSkewDetected => _clockSkewDetected;

  bool get isCorruptPersistence => _corruptPersistence;

  bool get isActive => _activeStartedAt != null;

  /// Closed intervals only (excludes the open active interval).
  int get closedAccumulatedSeconds => _accumulatedSeconds;

  /// Closed + open interval, clamped to the daily cap.
  ///
  /// When persistence is corrupt, reports the fail-closed capped value.
  int get accumulatedActiveSeconds {
    if (_corruptPersistence) return _policy.dailyCapSeconds;
    return _totalActiveSeconds();
  }

  int get remainingSeconds {
    // Corrupt persistence: fail closed at 0 until parent-authorized recovery.
    // Degraded-but-valid snapshots still expose real remaining for display;
    // [allowsKidsModeUsage] blocks new intervals until [recoverTrust].
    if (_corruptPersistence) return 0;
    final remaining = _policy.dailyCapSeconds - accumulatedActiveSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  Duration get remaining => Duration(seconds: remainingSeconds);

  bool get isCapReached => remainingSeconds <= 0;

  bool get isTrustDegraded => _trustState.isDegraded || _corruptPersistence;

  /// Kids Mode may open active intervals only when restored, trusted, and not
  /// corrupt. Cap exhaustion is reported separately via [isCapReached].
  bool get allowsKidsModeUsage =>
      _restored && !_corruptPersistence && !_trustState.isDegraded;

  /// Load durable state. Call once at startup before Kids Mode use.
  Future<void> restore() async {
    final raw = await _store.read(storeKey);
    final loaded = ScreenTimeSnapshot.load(raw);
    final wallNow = _wall.now();
    final monoNow = _monotonic.elapsed();

    switch (loaded.presence) {
      case SnapshotPresence.missing:
        _corruptPersistence = false;
        _beginFreshDay(
          dayKeyFor(wallNow),
          wallNow: wallNow,
          monoNow: monoNow,
          trust: TrustState.trusted,
          skew: false,
        );
        _restored = true;
        await _writeWorkingSnapshot();
        return;

      case SnapshotPresence.invalid:
        await _enterCorruptPersistence(
          raw: loaded.raw!,
          wallNow: wallNow,
          monoNow: monoNow,
        );
        _restored = true;
        // Do not overwrite primary corrupt bytes with a trusted fresh snapshot.
        return;

      case SnapshotPresence.valid:
        final snapshot = loaded.snapshot!;
        _corruptPersistence = false;
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
        return;
    }
  }

  /// Begin counting an active Kids Mode foreground interval.
  ///
  /// Idempotent: if already active, does not restart the open interval.
  /// No-op when [allowsKidsModeUsage] is false or the cap is reached.
  void startActive() {
    _ensureRestored();
    if (!allowsKidsModeUsage) {
      _activeStartedAt = null;
      return;
    }
    _reconcileCalendar(wallNow: _wall.now(), monoNow: _monotonic.elapsed());
    if (!allowsKidsModeUsage || isCapReached) {
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

  /// Re-read clocks: apply rollover/skew (with midnight split), clamp cap.
  void tick() {
    _ensureRestored();
    if (_corruptPersistence) {
      _activeStartedAt = null;
      return;
    }
    // Reconcile first so an active span across midnight can be split without
    // folding the entire open interval onto the old day then wiping it.
    _reconcileCalendar(wallNow: _wall.now(), monoNow: _monotonic.elapsed());
    if (!allowsKidsModeUsage) {
      _commitOpenInterval();
      _activeStartedAt = null;
      _checkpointClocks();
      return;
    }
    _foldOpenWholeSeconds();
    if (_totalActiveSeconds() >= _policy.dailyCapSeconds) {
      _commitOpenInterval();
    }
    _checkpointClocks();
  }

  /// Flush checkpoint to [PersistentStore].
  ///
  /// When persistence is corrupt, does **not** overwrite the primary key
  /// (recovery evidence preserved). Working state is only written after
  /// explicit [recoverTrust].
  Future<void> persist() async {
    _ensureRestored();
    if (_corruptPersistence) {
      _activeStartedAt = null;
      return;
    }
    final wasActive = _activeStartedAt != null && allowsKidsModeUsage;
    _commitOpenInterval();
    _checkpointClocks();
    await _writeWorkingSnapshot();
    if (wasActive &&
        allowsKidsModeUsage &&
        _accumulatedSeconds < _policy.dailyCapSeconds) {
      _activeStartedAt = _monotonic.elapsed();
    }
  }

  /// Explicit recovery for degraded / corrupt trust. **Never automatic.**
  ///
  /// Auth boundary: callers must enforce Parent Gate / re-auth before
  /// [TrustRecovery.forceNewLocalDay]. This method does not authenticate.
  /// No-op when trust is already healthy and persistence is not corrupt.
  void recoverTrust(TrustRecovery recovery) {
    _ensureRestored();
    if (!isTrustDegraded && !_corruptPersistence) {
      return;
    }
    _commitOpenInterval();
    final wallNow = _wall.now();
    final monoNow = _monotonic.elapsed();
    switch (recovery) {
      case TrustRecovery.keepPersistedBudget:
        if (_corruptPersistence) {
          // No salvageable budget — remain fail-closed for the current wall day
          // but clear corrupt flag so parent can later force a new day.
          // Kids Mode stays blocked until forceNewLocalDay (remaining 0, capped).
          _corruptPersistence = false;
          _dayKey = dayKeyFor(wallNow);
          _accumulatedSeconds = _policy.dailyCapSeconds;
          _trustState = TrustState.guarded;
          _clockSkewDetected = true;
          _activeStartedAt = null;
          _epochId = _monotonic.epochId;
          _checkpointClocks(wallNow: wallNow, monoNow: monoNow);
          // Still degraded (guarded) — does not grant fresh 30m.
          return;
        }
        _trustState = TrustState.trusted;
        _clockSkewDetected = false;
        _checkpointClocks(wallNow: wallNow, monoNow: monoNow);
      case TrustRecovery.forceNewLocalDay:
        _corruptPersistence = false;
        _beginFreshDay(
          dayKeyFor(wallNow),
          wallNow: wallNow,
          monoNow: monoNow,
          trust: TrustState.trusted,
          skew: false,
        );
        // Parent-authorized only path may replace primary + drop sidecar.
        // Deletion is async via [persist]; mark cleared in-memory here.
    }
  }

  /// Debug/QA-only budget mutation for local inspector controls (LMP-49 Step 3.2–3.4).
  ///
  /// **Not a production parent API** and not a trust-recovery path. Lowest
  /// boundary guard requires **both** [kDebugMode] **and**
  /// `(mutationsAllowed?.call() ?? true)`. Release/profile builds refuse even
  /// if a caller injects `mutationsAllowed: () => true`. Unit tests may inject
  /// `mutationsAllowed: () => false` in debug to assert refusal.
  ///
  /// Refuses corrupt **or** trust-degraded state (no bypass / manufactured
  /// trust). Closes any open interval, replaces closed accumulated seconds,
  /// and leaves trust flags unchanged.
  void applyDebugQaAccumulatedSeconds(
    int seconds, {
    bool Function()? mutationsAllowed,
  }) {
    if (!screenTimeDebugMutationsPermitted(
      mutationsAllowed: mutationsAllowed,
    )) {
      throw UnsupportedError(
        'Screen-time debug QA mutations are debug-only',
      );
    }
    _ensureRestored();
    if (_corruptPersistence || isTrustDegraded) {
      throw StateError(
        'Debug QA cannot mutate budget while persistence/trust is fail-closed',
      );
    }
    _commitOpenInterval();
    _accumulatedSeconds = _clampSeconds(seconds);
    _activeStartedAt = null;
    _checkpointClocks();
  }

  /// Persist after recovery. Prefer calling [persist] which writes the working
  /// snapshot; this helper removes corrupt evidence only once state is trusted
  /// and no longer corrupt (typically after [TrustRecovery.forceNewLocalDay]).
  Future<void> _clearCorruptEvidenceIfSafe() async {
    if (_corruptPersistence || _trustState.isDegraded) return;
    await _store.delete(corruptStoreKey);
  }

  /// Local calendar day key `YYYY-MM-DD` from a wall instant's date components.
  static String dayKeyFor(DateTime wall) {
    final y = wall.year.toString().padLeft(4, '0');
    final m = wall.month.toString().padLeft(2, '0');
    final d = wall.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Start of the next local calendar day after [wall]'s date (00:00:00.000).
  ///
  /// Constructs the next calendar date with `year` / `month` / `day + 1`
  /// (Dart overflows month/year). Does **not** add [Duration.days] or a fixed
  /// 24h span: on DST spring-forward, `localMidnight.add(Duration(days: 1))`
  /// lands at 01:00 next calendar day, which would corrupt rollover evidence.
  ///
  /// When [wall] is local in a DST-observing zone, elapsed wall time between
  /// consecutive midnights may be 23h, 24h, or 25h. UTC walls are always 24h.
  static DateTime startOfNextLocalDay(DateTime wall) {
    if (wall.isUtc) {
      return DateTime.utc(wall.year, wall.month, wall.day + 1);
    }
    return DateTime(wall.year, wall.month, wall.day + 1);
  }

  void _ensureRestored() {
    if (!_restored) {
      throw StateError(
        'ScreenTimeAccountant.restore() must be called before use',
      );
    }
  }

  Future<void> _enterCorruptPersistence({
    required String raw,
    required DateTime wallNow,
    required Duration monoNow,
  }) async {
    // Preserve evidence: sidecar + leave primary untouched.
    await _store.write(corruptStoreKey, raw);
    _corruptPersistence = true;
    _trustState = TrustState.guarded;
    _clockSkewDetected = true;
    _dayKey = dayKeyFor(wallNow);
    _accumulatedSeconds = _policy.dailyCapSeconds;
    _activeStartedAt = null;
    _epochId = _monotonic.epochId;
    _lastWallEpochMs = wallNow.millisecondsSinceEpoch;
    _lastMonotonicMs = monoNow.inMilliseconds;
  }

  Future<void> _writeWorkingSnapshot() async {
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
    await _clearCorruptEvidenceIfSafe();
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

  int _openElapsedMs() {
    final started = _activeStartedAt;
    if (started == null) return 0;
    final deltaMs =
        _monotonic.elapsed().inMilliseconds - started.inMilliseconds;
    return deltaMs < 0 ? 0 : deltaMs;
  }

  int _totalActiveSeconds() {
    final total = _accumulatedSeconds + _openElapsedSeconds();
    return _clampSeconds(total);
  }

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

  DateTime _wallFromEpochMs(int epochMs, DateTime wallNow) {
    if (wallNow.isUtc) {
      return DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }

  /// Commit any open interval onto the persisted day, then mark degraded.
  void _failClosedDegraded({
    required TrustState trust,
    required DateTime wallNow,
    required Duration monoNow,
    bool updateEpochMarkers = false,
  }) {
    _commitOpenInterval();
    _clockSkewDetected = true;
    _trustState = trust;
    _activeStartedAt = null;
    if (updateEpochMarkers) {
      _epochId = _monotonic.epochId;
      _lastMonotonicMs = monoNow.inMilliseconds;
      _lastWallEpochMs = wallNow.millisecondsSinceEpoch;
    }
  }

  /// Split an open active interval at local midnight, roll to [currentDay],
  /// and carry post-midnight seconds into the new day without loss/double-count.
  void _rolloverSplittingActive({
    required String currentDay,
    required DateTime wallNow,
    required Duration monoNow,
    required int msToMidnight,
  }) {
    final started = _activeStartedAt;
    var postMs = 0;
    var keepActive = false;

    if (started != null) {
      keepActive = true;
      final openMs = _openElapsedMs();
      // Monotonic instant corresponding to local midnight, paired with the
      // last wall/mono checkpoint (continuous trusted epoch only).
      final monoMidnightMs = _lastMonotonicMs + msToMidnight;
      final startMs = started.inMilliseconds;
      final preMs = (monoMidnightMs - startMs).clamp(0, openMs);
      postMs = openMs - preMs;

      final preSec = preMs ~/ 1000;
      _accumulatedSeconds =
          _clampSeconds(_accumulatedSeconds + preSec);
      _activeStartedAt = null;
    }

    _beginFreshDay(
      currentDay,
      wallNow: wallNow,
      monoNow: monoNow,
      trust: TrustState.trusted,
      skew: false,
    );

    if (postMs > 0) {
      final postSec = postMs ~/ 1000;
      _accumulatedSeconds = _clampSeconds(postSec);
      final remainderMs = postMs - (postSec * 1000);
      if (keepActive && _accumulatedSeconds < _policy.dailyCapSeconds) {
        // Re-open so sub-second remainder and further play continue on new day.
        _activeStartedAt =
            monoNow - Duration(milliseconds: remainderMs < 0 ? 0 : remainderMs);
      }
    } else if (keepActive && _accumulatedSeconds < _policy.dailyCapSeconds) {
      _activeStartedAt = monoNow;
    }
  }

  void _reconcileCalendar({
    required DateTime wallNow,
    required Duration monoNow,
  }) {
    if (_corruptPersistence) {
      _activeStartedAt = null;
      return;
    }

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
      if (_epochId != _monotonic.epochId) {
        // Same calendar day, new epoch: drop unverifiable open gap, keep budget.
        _commitOpenInterval();
        _activeStartedAt = null;
        _epochId = _monotonic.epochId;
        _lastMonotonicMs = monoNow.inMilliseconds;
        _lastWallEpochMs = wallNow.millisecondsSinceEpoch;
      }
      return;
    }

    if (currentDay.compareTo(_dayKey) < 0) {
      _failClosedDegraded(
        trust: TrustState.guarded,
        wallNow: wallNow,
        monoNow: monoNow,
      );
      return;
    }

    // currentDay > _dayKey — candidate rollover.
    final sameEpoch = _epochId == _monotonic.epochId;
    if (!sameEpoch) {
      _failClosedDegraded(
        trust: TrustState.uncertain,
        wallNow: wallNow,
        monoNow: monoNow,
        updateEpochMarkers: true,
      );
      return;
    }

    if (!_trustState.allowsAutomaticRollover) {
      _commitOpenInterval();
      _activeStartedAt = null;
      return;
    }

    final lastWall = _wallFromEpochMs(_lastWallEpochMs, wallNow);
    // Guard: last wall should still be on the persisted day; if not, treat as
    // insufficient evidence rather than assuming a 24h span.
    if (dayKeyFor(lastWall) != _dayKey) {
      _failClosedDegraded(
        trust: TrustState.guarded,
        wallNow: wallNow,
        monoNow: monoNow,
      );
      return;
    }

    final nextMidnight = startOfNextLocalDay(lastWall);
    final msToMidnight =
        nextMidnight.millisecondsSinceEpoch - lastWall.millisecondsSinceEpoch;
    final monoDeltaMs = monoNow.inMilliseconds - _lastMonotonicMs;

    // Gap is calendar next-midnight minus last wall (23h/24h/25h under DST).
    if (msToMidnight > 0 && monoDeltaMs >= msToMidnight) {
      _rolloverSplittingActive(
        currentDay: currentDay,
        wallNow: wallNow,
        monoNow: monoNow,
        msToMidnight: msToMidnight,
      );
      return;
    }

    // Forward wall jump without enough monotonic evidence (or non-positive gap).
    _failClosedDegraded(
      trust: TrustState.guarded,
      wallNow: wallNow,
      monoNow: monoNow,
    );
  }
}

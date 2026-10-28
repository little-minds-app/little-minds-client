import 'dart:convert';

import 'daily_policy.dart';
import 'snapshot_load_result.dart';
import 'trust_state.dart';

/// Durable local daily screen-time checkpoint (device-attributed, offline).
///
/// Schema is intentionally small for LMP-49 Step 1. Sync / multi-device fields
/// from ADR-016 are out of scope until a later ticket.
final class ScreenTimeSnapshot {
  const ScreenTimeSnapshot({
    required this.schemaVersion,
    required this.dayKey,
    required this.accumulatedActiveSeconds,
    required this.dailyCapSeconds,
    required this.timeZoneId,
    required this.lastWallEpochMs,
    required this.lastMonotonicMs,
    required this.epochId,
    required this.trustState,
    this.clockSkewDetected = false,
  });

  static const int currentSchemaVersion = 1;

  static const String storeKey = 'screen_time.snapshot.v1';

  /// Sidecar key preserving the last present-but-invalid payload for recovery /
  /// forensics. Must not be overwritten by a silent fresh trusted snapshot.
  static const String corruptStoreKey = 'screen_time.snapshot.v1.corrupt';

  final int schemaVersion;

  /// Local calendar day `YYYY-MM-DD` under [timeZoneId] scaffolding.
  final String dayKey;

  /// Closed-interval accumulated active seconds for [dayKey] (no open interval).
  final int accumulatedActiveSeconds;

  final int dailyCapSeconds;
  final String timeZoneId;

  /// Wall clock millis at last checkpoint (untrusted offline).
  final int lastWallEpochMs;

  /// Monotonic elapsed millis at last checkpoint within [epochId].
  final int lastMonotonicMs;

  /// Monotonic epoch identity at last checkpoint.
  final String epochId;

  final TrustState trustState;

  /// True when a wall-clock rollback or unverified forward jump was observed.
  final bool clockSkewDetected;

  Map<String, Object?> toJson() => {
        'schema_version': schemaVersion,
        'day_key': dayKey,
        'accumulated_active_seconds': accumulatedActiveSeconds,
        'daily_cap_seconds': dailyCapSeconds,
        'time_zone_id': timeZoneId,
        'last_wall_epoch_ms': lastWallEpochMs,
        'last_monotonic_ms': lastMonotonicMs,
        'epoch_id': epochId,
        'trust_state': trustState.wireName,
        'clock_skew_detected': clockSkewDetected,
      };

  String encode() => jsonEncode(toJson());

  /// Distinguishes missing vs valid vs present-but-invalid.
  static SnapshotLoadResult load(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const SnapshotLoadResult.missing();
    }
    final parsed = tryDecode(raw);
    if (parsed == null) {
      return SnapshotLoadResult.invalid(raw);
    }
    return SnapshotLoadResult.valid(parsed);
  }

  static ScreenTimeSnapshot? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, Object?>.from(decoded);
      return fromJson(map);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static ScreenTimeSnapshot? fromJson(Map<String, Object?> map) {
    final schema = _asInt(map['schema_version']);
    final dayKey = map['day_key'];
    final accumulated = _asInt(map['accumulated_active_seconds']);
    final cap = _asInt(map['daily_cap_seconds']);
    final tz = map['time_zone_id'];
    final wall = _asInt(map['last_wall_epoch_ms']);
    final mono = _asInt(map['last_monotonic_ms']);
    final epochId = map['epoch_id'];
    final trustRaw = map['trust_state'];
    final skew = map['clock_skew_detected'];

    if (schema == null ||
        dayKey is! String ||
        dayKey.isEmpty ||
        accumulated == null ||
        accumulated < 0 ||
        cap == null ||
        cap < 0 ||
        tz is! String ||
        wall == null ||
        mono == null ||
        mono < 0 ||
        epochId is! String ||
        epochId.isEmpty ||
        trustRaw is! String) {
      return null;
    }

    final trust = TrustState.fromWire(trustRaw);
    if (trust == null) return null;

    return ScreenTimeSnapshot(
      schemaVersion: schema,
      dayKey: dayKey,
      accumulatedActiveSeconds: accumulated,
      dailyCapSeconds: cap,
      timeZoneId: tz,
      lastWallEpochMs: wall,
      lastMonotonicMs: mono,
      epochId: epochId,
      trustState: trust,
      clockSkewDetected: skew == true,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  ScreenTimeSnapshot copyWith({
    int? schemaVersion,
    String? dayKey,
    int? accumulatedActiveSeconds,
    int? dailyCapSeconds,
    String? timeZoneId,
    int? lastWallEpochMs,
    int? lastMonotonicMs,
    String? epochId,
    TrustState? trustState,
    bool? clockSkewDetected,
  }) {
    return ScreenTimeSnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      dayKey: dayKey ?? this.dayKey,
      accumulatedActiveSeconds:
          accumulatedActiveSeconds ?? this.accumulatedActiveSeconds,
      dailyCapSeconds: dailyCapSeconds ?? this.dailyCapSeconds,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      lastWallEpochMs: lastWallEpochMs ?? this.lastWallEpochMs,
      lastMonotonicMs: lastMonotonicMs ?? this.lastMonotonicMs,
      epochId: epochId ?? this.epochId,
      trustState: trustState ?? this.trustState,
      clockSkewDetected: clockSkewDetected ?? this.clockSkewDetected,
    );
  }

  DailyPolicy get policy => DailyPolicy(
        dailyCapSeconds: dailyCapSeconds,
        timeZoneId: timeZoneId,
      );
}

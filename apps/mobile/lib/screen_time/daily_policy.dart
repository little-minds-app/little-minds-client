/// Local offline daily screen-time policy (F-010 scaffolding until M10 sync).
///
/// **TECHNICAL ASSUMPTION** — fixed 30-minute default for offline demo / LMP-49
/// Step 1. Not a parent-synced [screen_time_policies] row; not a claim that
/// 30 minutes is medically optimal (Blueprint §5.1).
final class DailyPolicy {
  const DailyPolicy({
    required this.dailyCapSeconds,
    this.timeZoneId = defaultTimeZoneId,
  }) : assert(dailyCapSeconds >= 0, 'dailyCapSeconds must be non-negative');

  /// Blueprint / Jira AC default maximum for V1 demo enforcement.
  static const int defaultDailyCapSeconds = 30 * 60;

  /// Scaffolding timezone until parent-selected IANA TZ is wired.
  /// TECHNICAL ASSUMPTION ⏳ — device-local semantics via wall clock instants
  /// that tests/fakes already express in this zone.
  static const String defaultTimeZoneId = 'UTC';

  static const DailyPolicy defaultThirtyMinutes = DailyPolicy(
    dailyCapSeconds: defaultDailyCapSeconds,
    timeZoneId: defaultTimeZoneId,
  );

  /// Non-negative daily cap in whole seconds.
  final int dailyCapSeconds;

  /// IANA timezone id for local midnight / day-key (scaffolding may be UTC).
  final String timeZoneId;

  Duration get dailyCap => Duration(seconds: dailyCapSeconds);

  DailyPolicy copyWith({int? dailyCapSeconds, String? timeZoneId}) {
    return DailyPolicy(
      dailyCapSeconds: dailyCapSeconds ?? this.dailyCapSeconds,
      timeZoneId: timeZoneId ?? this.timeZoneId,
    );
  }
}

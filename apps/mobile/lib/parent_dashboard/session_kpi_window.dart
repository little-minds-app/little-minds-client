/// Fixed recent window for session KPI queries (LMP-53 / Jira execution design).
///
/// Seven completed Istanbul calendar days plus the current local day, encoded as
/// `[from, to)` UTC instants for `GET /v1/insights/session-kpis`.
class SessionKpiWindow {
  const SessionKpiWindow({
    required this.fromUtc,
    required this.toUtcExclusive,
    required this.timezone,
  });

  final DateTime fromUtc;
  final DateTime toUtcExclusive;
  final String timezone;

  static const defaultTimezone = 'Europe/Istanbul';
  static const _istanbulOffset = Duration(hours: 3);

  /// Builds the default parent-dashboard window from [now] (defaults to clock now).
  static SessionKpiWindow recentSevenDaysPlusToday({
    DateTime? now,
    String timezone = defaultTimezone,
  }) {
    assert(timezone == defaultTimezone, 'Only Europe/Istanbul is validated in V1');
    final utcNow = (now ?? DateTime.now()).toUtc();
    final istanbulLocal = utcNow.add(_istanbulOffset);
    final todayLocal = DateTime(
      istanbulLocal.year,
      istanbulLocal.month,
      istanbulLocal.day,
    );
    final fromLocal = todayLocal.subtract(const Duration(days: 7));
    final toLocalExclusive = todayLocal.add(const Duration(days: 1));
    return SessionKpiWindow(
      fromUtc: _istanbulMidnightToUtc(fromLocal),
      toUtcExclusive: _istanbulMidnightToUtc(toLocalExclusive),
      timezone: timezone,
    );
  }

  static DateTime _istanbulMidnightToUtc(DateTime localCalendarDate) {
    return DateTime.utc(
      localCalendarDate.year,
      localCalendarDate.month,
      localCalendarDate.day,
    ).subtract(_istanbulOffset);
  }
}

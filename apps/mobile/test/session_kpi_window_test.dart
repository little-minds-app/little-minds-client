import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_window.dart';

void main() {
  test('recentSevenDaysPlusToday uses Istanbul calendar [from,to) UTC', () {
    // 2026-11-03 10:00 UTC → 13:00 Istanbul same calendar day.
    final window = SessionKpiWindow.recentSevenDaysPlusToday(
      now: DateTime.utc(2026, 11, 3, 10),
    );
    expect(window.timezone, 'Europe/Istanbul');
    // From: 2026-10-27 00:00 Istanbul = 2026-10-26 21:00 UTC
    expect(window.fromUtc, DateTime.utc(2026, 10, 26, 21));
    // To exclusive: 2026-11-04 00:00 Istanbul = 2026-11-03 21:00 UTC
    expect(window.toUtcExclusive, DateTime.utc(2026, 11, 3, 21));
  });
}

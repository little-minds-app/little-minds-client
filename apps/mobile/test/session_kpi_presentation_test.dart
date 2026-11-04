import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_presentation.dart';

void main() {
  test('friendlyRateReason localizes known codes and hides unknown', () {
    expect(friendlyRateReason('zero_denominator'),
        'Hesaplamak için henüz uygun veri yok');
    expect(friendlyRateReason('internal_code'), 'Bu oran şu anda hesaplanamıyor');
  });

  test('formatSessionKpiRate keeps zero distinct from unavailable', () {
    final unavailable = formatSessionKpiRate(SessionKpiRateMetric(
      availabilityStatus: SessionKpiRateMetricAvailabilityStatusEnum.unavailable,
      reasonCode: 'no_signal',
      numerator: 0,
      denominator: 0,
    ));
    expect(unavailable.unavailable, isTrue);
    expect(unavailable.label, 'Bu dönemde ölçülebilir sonuç yok');

    final zero = formatSessionKpiRate(SessionKpiRateMetric(
      availabilityStatus: SessionKpiRateMetricAvailabilityStatusEnum.available,
      value: 0,
      numerator: 0,
      denominator: 5,
    ));
    expect(zero.unavailable, isFalse);
    expect(zero.label, '0% (0/5)');
  });

  test('freshness and completeness labels avoid raw enums', () {
    expect(
      freshnessStatusLabel(SessionKpiResponseFreshnessStatusEnum.fresh),
      'Güncel',
    );
    expect(
      completenessLabel(SessionKpiResponseFreshnessDataCompletenessEnum.partial),
      'Kısmi',
    );
  });
}

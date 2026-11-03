import 'package:little_minds_api/api.dart';

/// User-facing KPI copy — server values only, no metric recomputation (LMP-131).

const _rateUnavailableReasons = <String, String>{
  'zero_denominator': 'Hesaplamak için henüz uygun veri yok',
  'insufficient_denominator': 'Güvenilir bir oran için yeterli oturum yok',
  'insufficient_data': 'Henüz yeterli veri yok',
  'no_signal': 'Bu dönemde ölçülebilir sonuç yok',
  'insufficient_sample': 'Henüz yeterli örnek yok',
};

String friendlyRateReason(String? reasonCode) {
  if (reasonCode == null || reasonCode.trim().isEmpty) {
    return 'Bu oran şu anda hesaplanamıyor';
  }
  return _rateUnavailableReasons[reasonCode.trim()] ??
      'Bu oran şu anda hesaplanamıyor';
}

String freshnessStatusLabel(SessionKpiResponseFreshnessStatusEnum status) {
  return switch (status) {
    SessionKpiResponseFreshnessStatusEnum.fresh => 'Güncel',
    SessionKpiResponseFreshnessStatusEnum.stale => 'Güncelliğini yitirmiş',
    SessionKpiResponseFreshnessStatusEnum.noData => 'Henüz veri yok',
    SessionKpiResponseFreshnessStatusEnum() => 'Durum bilinmiyor',
  };
}

String completenessLabel(SessionKpiResponseFreshnessDataCompletenessEnum status) {
  return switch (status) {
    SessionKpiResponseFreshnessDataCompletenessEnum.complete => 'Tam',
    SessionKpiResponseFreshnessDataCompletenessEnum.partial => 'Kısmi',
    SessionKpiResponseFreshnessDataCompletenessEnum() => 'Bilinmiyor',
  };
}

({String label, bool unavailable}) formatSessionKpiRate(SessionKpiRateMetric metric) {
  if (metric.availabilityStatus ==
      SessionKpiRateMetricAvailabilityStatusEnum.unavailable) {
    return (label: friendlyRateReason(metric.reasonCode), unavailable: true);
  }
  final value = metric.value;
  if (value == null) {
    return (label: friendlyRateReason(metric.reasonCode), unavailable: true);
  }
  final pct = (value * 100).toStringAsFixed(0);
  return (
    label: '$pct% (${metric.numerator}/${metric.denominator})',
    unavailable: false,
  );
}

String formatPlayDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '0 dk';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes == 0) return '$seconds sn';
  if (seconds == 0) return '$minutes dk';
  return '$minutes dk $seconds sn';
}

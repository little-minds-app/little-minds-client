import 'package:little_minds_api/api.dart';

SessionKpiRateMetric availableRate({num value = 0.5, int numerator = 1, int denominator = 2}) {
  return SessionKpiRateMetric(
    availabilityStatus: SessionKpiRateMetricAvailabilityStatusEnum.available,
    value: value,
    numerator: numerator,
    denominator: denominator,
  );
}

SessionKpiRateMetric unavailableRate({String reason = 'insufficient_sample'}) {
  return SessionKpiRateMetric(
    availabilityStatus: SessionKpiRateMetricAvailabilityStatusEnum.unavailable,
    reasonCode: reason,
    numerator: 0,
    denominator: 0,
  );
}

SessionKpiResponse sampleKpiResponse({
  int eligible = 3,
  SessionKpiResponseFreshnessStatusEnum freshness =
      SessionKpiResponseFreshnessStatusEnum.fresh,
}) {
  return SessionKpiResponse(
    definitionVersion: '2026-11-03',
    source_: SessionKpiResponseSource_Enum.serverActivitySessions,
    generatedAt: DateTime.utc(2026, 11, 3, 12),
    window: SessionKpiResponseWindow(
      from: DateTime.utc(2026, 10, 26, 21),
      to: DateTime.utc(2026, 11, 3, 21),
      timezone: 'Europe/Istanbul',
      bounds: SessionKpiResponseWindowBoundsEnum.halfOpenStartedAt,
    ),
    freshness: SessionKpiResponseFreshness(
      status: freshness,
      staleThresholdSeconds: 900,
      dataCompleteness: SessionKpiResponseFreshnessDataCompletenessEnum.complete,
    ),
    sample: SessionKpiResponseSample(
      eligibleSessions: eligible,
      terminalSessions: eligible,
      excludedUnsupportedSchema: 0,
      excludedConsent: 0,
    ),
    metrics: SessionKpiResponseMetrics(
      eligibleSessionCount: eligible,
      completedSessionCount: 2,
      interruptedSessionCount: 1,
      abandonedSessionCount: 0,
      inProgressSessionCount: 0,
      totalPlayDurationSeconds: 600,
      completedSessionRate: availableRate(value: 0.67, numerator: 2, denominator: 3),
      distinctPlayDays: 2,
      byActivity: const [],
      firstAttemptAccuracy: unavailableRate(),
    ),
  );
}

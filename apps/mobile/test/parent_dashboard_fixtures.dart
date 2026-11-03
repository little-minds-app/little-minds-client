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

MissionParentReportFacts sampleMissionParentReport({
  MissionParentReportFactsAvailabilityEnum availability =
      MissionParentReportFactsAvailabilityEnum.reported,
  MissionParentReportFactsStatusEnum? status =
      MissionParentReportFactsStatusEnum.completed,
}) {
  return MissionParentReportFacts(
    availability: availability,
    status: status,
    authoritative: true,
    recordedAt: DateTime.utc(2026, 11, 2, 10),
    assertionId: 'assert-1',
    revision: 1,
    actor: MissionParentReportFactsActorEnum.parent,
    source_: MissionParentReportFactsSource_Enum.caregiverReport,
  );
}

MissionStatusOccurrenceRow sampleMissionRow({
  String missionId = 'near-far-v1',
  String occurrenceId = 'occ-1',
  MissionParentReportFactsAvailabilityEnum reportAvailability =
      MissionParentReportFactsAvailabilityEnum.reported,
}) {
  return MissionStatusOccurrenceRow(
    missionId: missionId,
    occurrenceId: occurrenceId,
    interaction: MissionInteractionFacts(
      offeredAt: DateTime.utc(2026, 11, 2, 9),
      openedAt: DateTime.utc(2026, 11, 2, 9, 5),
      source_: MissionInteractionFactsSource_Enum.childPlayEvents,
    ),
    parentReport: sampleMissionParentReport(availability: reportAvailability),
  );
}

MissionStatusListResponse sampleMissionStatusResponse({
  List<MissionStatusOccurrenceRow>? items,
  bool truncated = false,
  String childId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
}) {
  return MissionStatusListResponse(
    schemaVersion: MissionStatusListResponseSchemaVersionEnum.missionStatusV1,
    definitionVersion: MissionStatusListResponseDefinitionVersionEnum.missionStatusV1,
    generatedAt: DateTime.utc(2026, 11, 3, 12),
    childId: childId,
    window: MissionStatusListResponseWindow(
      from: DateTime.utc(2026, 10, 26, 21),
      to: DateTime.utc(2026, 11, 3, 21),
      bounds: MissionStatusListResponseWindowBoundsEnum.halfOpenRecordedAt,
    ),
    items: items ?? [sampleMissionRow()],
    pagination: MissionStatusListResponsePagination(
      limit: 50,
      truncated: truncated,
    ),
  );
}

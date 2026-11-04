import 'package:little_minds_api/api.dart';

import 'session_kpi_presentation.dart';

/// Immutable presentation snapshot — server KPI values only, no client recomputation.
class ParentDashboardViewData {
  const ParentDashboardViewData({
    required this.windowLabel,
    required this.freshnessLabel,
    required this.completenessLabel,
    required this.sampleLabel,
    required this.eligibleSessions,
    required this.completedSessions,
    required this.interruptedSessions,
    required this.inProgressSessions,
    required this.abandonedSessions,
    required this.totalPlayDurationLabel,
    required this.completedRateLabel,
    required this.completedRateUnavailable,
    required this.distinctPlayDays,
    required this.firstAttemptAccuracyLabel,
    required this.firstAttemptAccuracyUnavailable,
    required this.activityRows,
    required this.isEmpty,
    required this.isStale,
    required this.isPartial,
    required this.maxActivityPlaySeconds,
  });

  final String windowLabel;
  final String freshnessLabel;
  final String completenessLabel;
  final String sampleLabel;
  final int eligibleSessions;
  final int completedSessions;
  final int interruptedSessions;
  final int inProgressSessions;
  final int abandonedSessions;
  final String totalPlayDurationLabel;
  final String completedRateLabel;
  final bool completedRateUnavailable;
  final int distinctPlayDays;
  final String firstAttemptAccuracyLabel;
  final bool firstAttemptAccuracyUnavailable;
  final List<ParentDashboardActivityRow> activityRows;
  final bool isEmpty;
  final bool isStale;
  final bool isPartial;
  final int maxActivityPlaySeconds;
}

class ParentDashboardActivityRow {
  const ParentDashboardActivityRow({
    required this.activityId,
    required this.sessionCount,
    required this.playDurationLabel,
    required this.playDurationSeconds,
  });

  final String activityId;
  final int sessionCount;
  final String playDurationLabel;
  final int playDurationSeconds;
}

/// Maps [SessionKpiResponse] to localized display strings without altering metrics.
ParentDashboardViewData mapSessionKpiToView(SessionKpiResponse response) {
  final metrics = response.metrics;
  final freshness = response.freshness;
  final sample = response.sample;

  final completedRate = formatSessionKpiRate(metrics.completedSessionRate);
  final accuracy = formatSessionKpiRate(metrics.firstAttemptAccuracy);

  final isStale = freshness.status == SessionKpiResponseFreshnessStatusEnum.stale;
  final isPartial =
      freshness.dataCompleteness == SessionKpiResponseFreshnessDataCompletenessEnum.partial;
  final isEmpty = metrics.eligibleSessionCount == 0 ||
      freshness.status == SessionKpiResponseFreshnessStatusEnum.noData;

  final activityRows = metrics.byActivity
      .map(
        (row) => ParentDashboardActivityRow(
          activityId: row.contentVersionId,
          sessionCount: row.sessionStarts,
          playDurationLabel: formatPlayDuration(row.playDurationSeconds),
          playDurationSeconds: row.playDurationSeconds,
        ),
      )
      .toList(growable: false);
  final maxActivityPlay = activityRows.isEmpty
      ? 0
      : activityRows.map((row) => row.playDurationSeconds).reduce((a, b) => a > b ? a : b);

  return ParentDashboardViewData(
    windowLabel:
        '${response.window.from.toUtc().toIso8601String()} – ${response.window.to.toUtc().toIso8601String()} (${response.window.timezone})',
    freshnessLabel: freshnessStatusLabel(freshness.status),
    completenessLabel: completenessLabel(freshness.dataCompleteness),
    sampleLabel:
        'Uygun: ${sample.eligibleSessions}, terminal: ${sample.terminalSessions}, '
        'hariç (şema): ${sample.excludedUnsupportedSchema}, '
        'hariç (onay): ${sample.excludedConsent}',
    eligibleSessions: metrics.eligibleSessionCount,
    completedSessions: metrics.completedSessionCount,
    interruptedSessions: metrics.interruptedSessionCount,
    inProgressSessions: metrics.inProgressSessionCount,
    abandonedSessions: metrics.abandonedSessionCount,
    totalPlayDurationLabel: formatPlayDuration(metrics.totalPlayDurationSeconds),
    completedRateLabel: completedRate.label,
    completedRateUnavailable: completedRate.unavailable,
    distinctPlayDays: metrics.distinctPlayDays,
    firstAttemptAccuracyLabel: accuracy.label,
    firstAttemptAccuracyUnavailable: accuracy.unavailable,
    activityRows: activityRows,
    isEmpty: isEmpty,
    isStale: isStale,
    isPartial: isPartial,
    maxActivityPlaySeconds: maxActivityPlay,
  );
}

import 'package:little_minds_api/api.dart';

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
  });

  final String windowLabel;
  final String freshnessLabel;
  final String completenessLabel;
  final String sampleLabel;
  final int eligibleSessions;
  final int completedSessions;
  final int interruptedSessions;
  final int inProgressSessions;
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
}

class ParentDashboardActivityRow {
  const ParentDashboardActivityRow({
    required this.activityId,
    required this.sessionCount,
    required this.playDurationLabel,
  });

  final String activityId;
  final int sessionCount;
  final String playDurationLabel;
}

/// Maps [SessionKpiResponse] to localized display strings without altering metrics.
ParentDashboardViewData mapSessionKpiToView(SessionKpiResponse response) {
  final metrics = response.metrics;
  final freshness = response.freshness;
  final sample = response.sample;

  final completedRate = _formatRate(metrics.completedSessionRate);
  final accuracy = _formatRate(metrics.firstAttemptAccuracy);

  final isStale = freshness.status == SessionKpiResponseFreshnessStatusEnum.stale;
  final isPartial =
      freshness.dataCompleteness == SessionKpiResponseFreshnessDataCompletenessEnum.partial;
  final isEmpty = metrics.eligibleSessionCount == 0 ||
      freshness.status == SessionKpiResponseFreshnessStatusEnum.noData;

  return ParentDashboardViewData(
    windowLabel:
        '${response.window.from.toUtc().toIso8601String()} – ${response.window.to.toUtc().toIso8601String()} (${response.window.timezone})',
    freshnessLabel: freshness.status.toJson(),
    completenessLabel: freshness.dataCompleteness.toJson(),
    sampleLabel:
        'Uygun: ${sample.eligibleSessions}, terminal: ${sample.terminalSessions}, '
        'hariç (şema): ${sample.excludedUnsupportedSchema}, '
        'hariç (onay): ${sample.excludedConsent}',
    eligibleSessions: metrics.eligibleSessionCount,
    completedSessions: metrics.completedSessionCount,
    interruptedSessions: metrics.interruptedSessionCount,
    inProgressSessions: metrics.inProgressSessionCount,
    totalPlayDurationLabel: _formatDuration(metrics.totalPlayDurationSeconds),
    completedRateLabel: completedRate.label,
    completedRateUnavailable: completedRate.unavailable,
    distinctPlayDays: metrics.distinctPlayDays,
    firstAttemptAccuracyLabel: accuracy.label,
    firstAttemptAccuracyUnavailable: accuracy.unavailable,
    activityRows: metrics.byActivity
        .map(
          (row) => ParentDashboardActivityRow(
            activityId: row.contentVersionId,
            sessionCount: row.sessionStarts,
            playDurationLabel: _formatDuration(row.playDurationSeconds),
          ),
        )
        .toList(growable: false),
    isEmpty: isEmpty,
    isStale: isStale,
    isPartial: isPartial,
  );
}

({String label, bool unavailable}) _formatRate(SessionKpiRateMetric metric) {
  if (metric.availabilityStatus ==
      SessionKpiRateMetricAvailabilityStatusEnum.unavailable) {
    final reason = metric.reasonCode;
    return (
      label: reason == null || reason.isEmpty ? '—' : reason,
      unavailable: true,
    );
  }
  final value = metric.value;
  if (value == null) {
    return (label: '—', unavailable: true);
  }
  final pct = (value * 100).toStringAsFixed(0);
  return (label: '$pct% (${metric.numerator}/${metric.denominator})', unavailable: false);
}

String _formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '0 dk';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes == 0) return '$seconds sn';
  if (seconds == 0) return '$minutes dk';
  return '$minutes dk $seconds sn';
}

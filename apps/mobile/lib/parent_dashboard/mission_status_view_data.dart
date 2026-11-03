import 'package:little_minds_api/api.dart';

/// How parent-reported facts appear for one occurrence row.
enum MissionReportPresentation {
  reported,
  noReport,
  interactionOnly,
}

class MissionStatusRowView {
  const MissionStatusRowView({
    required this.missionId,
    required this.occurrenceId,
    required this.interactionLabel,
    required this.reportLabel,
    required this.reportPresentation,
  });

  final String missionId;
  final String occurrenceId;
  final String interactionLabel;
  final String reportLabel;
  final MissionReportPresentation reportPresentation;
}

/// Immutable mission panel snapshot — server values only (LMP-130 / LMP-53).
class MissionStatusViewData {
  const MissionStatusViewData({
    required this.windowLabel,
    required this.freshnessLabel,
    required this.rows,
    required this.truncated,
    required this.isEmpty,
  });

  final String windowLabel;
  final String freshnessLabel;
  final List<MissionStatusRowView> rows;
  final bool truncated;
  final bool isEmpty;
}

MissionStatusViewData mapMissionStatusToView(MissionStatusListResponse response) {
  final window = response.window;
  final windowLabel =
      '${window.from?.toUtc().toIso8601String() ?? '—'} – '
      '${window.to?.toUtc().toIso8601String() ?? '—'} '
      '(${window.bounds.toJson()})';
  final freshnessLabel = response.generatedAt.toUtc().toIso8601String();

  final rows = response.items.map(_mapRow).toList(growable: false);
  return MissionStatusViewData(
    windowLabel: windowLabel,
    freshnessLabel: freshnessLabel,
    rows: rows,
    truncated: response.pagination.truncated,
    isEmpty: rows.isEmpty,
  );
}

MissionStatusRowView _mapRow(MissionStatusOccurrenceRow row) {
  final interaction = row.interaction;
  final offered = interaction.offeredAt?.toUtc().toIso8601String();
  final opened = interaction.openedAt?.toUtc().toIso8601String();
  final interactionLabel = [
    if (offered != null) 'Sunuldu: $offered',
    if (opened != null) 'Açıldı: $opened',
    if (offered == null && opened == null) 'Etkileşim kaydı yok',
  ].join(' · ');

  final report = row.parentReport;
  final presentation = switch (report.availability) {
    MissionParentReportFactsAvailabilityEnum.reported => MissionReportPresentation.reported,
    MissionParentReportFactsAvailabilityEnum.noReport => MissionReportPresentation.noReport,
  };

  final statusLabel = _formatParentStatus(report.status);
  final reportLabel = switch (presentation) {
    MissionReportPresentation.noReport =>
      'Ebeveyn bildirimi yok (yalnızca uygulama etkileşimi)',
    MissionReportPresentation.reported => [
      'Ebeveyn bildirimi: $statusLabel',
      if (report.recordedAt != null)
        'Kayıt: ${report.recordedAt!.toUtc().toIso8601String()}',
      'Kaynak: ${_formatReportSource(report.source_)} · Aktör: ${_formatReportActor(report.actor)}',
      if (report.authoritative) 'Yetkili kayıt',
    ].join(' · '),
    MissionReportPresentation.interactionOnly => interactionLabel,
  };

  return MissionStatusRowView(
    missionId: row.missionId,
    occurrenceId: row.occurrenceId,
    interactionLabel: interactionLabel,
    reportLabel: reportLabel,
    reportPresentation: presentation,
  );
}

String _formatReportSource(MissionParentReportFactsSource_Enum source) {
  return switch (source) {
    MissionParentReportFactsSource_Enum.caregiverReport => 'Ebeveyn bildirimi',
    MissionParentReportFactsSource_Enum() => 'Sunucu kaydı',
  };
}

String _formatReportActor(MissionParentReportFactsActorEnum actor) {
  return switch (actor) {
    MissionParentReportFactsActorEnum.parent => 'Ebeveyn',
    MissionParentReportFactsActorEnum() => 'Bilinmiyor',
  };
}

String _formatParentStatus(MissionParentReportFactsStatusEnum? status) {
  if (status == null) return '—';
  return switch (status) {
    MissionParentReportFactsStatusEnum.completed => 'Tamamlandı',
    MissionParentReportFactsStatusEnum.skipped => 'Atlandı',
    MissionParentReportFactsStatusEnum.notNow => 'Şimdi değil',
    MissionParentReportFactsStatusEnum.partial => 'Kısmen',
  };
}

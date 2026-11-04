import type { components } from '../../../../generated/typescript/schema';

type Rate = components['schemas']['SessionKpiRateMetric'];
type Kpi = components['schemas']['SessionKpiResponse'];

export const rateUnavailableReasons: Record<string, string> = {
  zero_denominator: 'Hesaplamak için henüz uygun veri yok',
  insufficient_denominator: 'Güvenilir bir oran için yeterli oturum yok',
  insufficient_data: 'Henüz yeterli veri yok',
  no_signal: 'Bu dönemde ölçülebilir sonuç yok',
  insufficient_sample: 'Henüz yeterli örnek yok',
};

export function friendlyRateReason(reason?: string | null): string {
  if (!reason?.trim()) return 'Bu oran şu anda hesaplanamıyor';
  return rateUnavailableReasons[reason.trim()] ?? 'Bu oran şu anda hesaplanamıyor';
}

export function freshnessStatusLabel(status: string): string {
  return ({ fresh: 'Güncel', stale: 'Güncelliğini yitirmiş', no_data: 'Henüz veri yok' } as Record<string, string>)[status]
    ?? 'Durum bilinmiyor';
}

export function completenessLabel(status: string): string {
  return ({ complete: 'Tam', partial: 'Kısmi' } as Record<string, string>)[status]
    ?? 'Bilinmiyor';
}

export function formatSessionKpiRate(metric: Rate): { label: string; unavailable: boolean } {
  if (metric.availability_status === 'unavailable') {
    return { label: friendlyRateReason(metric.reason_code), unavailable: true };
  }
  if (metric.value == null) return { label: friendlyRateReason(metric.reason_code), unavailable: true };
  const pct = (metric.value * 100).toFixed(0);
  return { label: `${pct}% (${metric.numerator}/${metric.denominator})`, unavailable: false };
}

export function missionReportSourceLabel(source: string): string {
  return ({ caregiver_report: 'Ebeveyn bildirimi' } as Record<string, string>)[source]
    ?? 'Sunucu kaydı';
}

export function missionReportActorLabel(actor: string): string {
  return ({ parent: 'Ebeveyn' } as Record<string, string>)[actor] ?? 'Bilinmiyor';
}

export function formatPlayDuration(totalSeconds: number) {
  if (totalSeconds <= 0) return '0 dk';
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  if (minutes === 0) return `${seconds} sn`;
  if (seconds === 0) return `${minutes} dk`;
  return `${minutes} dk ${seconds} sn`;
}

export function mapSessionKpiView(kpi: Kpi) {
  const completedRate = formatSessionKpiRate(kpi.metrics.completed_session_rate);
  const accuracy = formatSessionKpiRate(kpi.metrics.first_attempt_accuracy);
  const isStale = kpi.freshness.status === 'stale';
  const isPartial = kpi.freshness.data_completeness === 'partial';
  const isEmpty = kpi.metrics.eligible_session_count === 0 || kpi.freshness.status === 'no_data';
  const activityRows = kpi.metrics.by_activity.map((row) => ({
    key: row.content_version_id,
    label: row.content_version_id,
    sessionCount: row.session_starts,
    playSeconds: row.play_duration_seconds,
    playLabel: formatPlayDuration(row.play_duration_seconds),
  }));
  const maxPlaySeconds = activityRows.reduce((max, row) => Math.max(max, row.playSeconds), 0);
  return {
    completedRate,
    accuracy,
    isStale,
    isPartial,
    isEmpty,
    sampleLabel: `Uygun: ${kpi.sample.eligible_sessions}, terminal: ${kpi.sample.terminal_sessions}, `
      + `hariç (şema): ${kpi.sample.excluded_unsupported_schema}, `
      + `hariç (onay): ${kpi.sample.excluded_consent}`,
    activityRows,
    maxPlaySeconds,
  };
}

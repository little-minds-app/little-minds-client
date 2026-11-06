'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import type { components } from '../../../../generated/typescript/schema';
import { ActivityDurationChart, SessionCompositionDonut, TrendsPlaceholderChart } from './dashboard-charts';
import { LmButton, LmCard, LmDisclosure, LmKpiMetric } from './lm-ui';
import { ParentFeedback } from './parent-feedback';
import {
  completenessLabel,
  formatPlayDuration,
  freshnessStatusLabel,
  mapSessionKpiView,
  missionReportActorLabel,
  missionReportSourceLabel,
} from './session-kpi-presentation';

type Kpi = components['schemas']['SessionKpiResponse'];
type Missions = components['schemas']['MissionStatusListResponse'];
type Phase<T> = { state: 'loading' | 'empty' | 'error' | 'ready'; value?: T; message?: string };
type Snapshot = { parentId: string; childId: string; kpi: Phase<Kpi>; missions: Phase<Missions>; blocked: boolean };

const failure = (status: number) => status === 401 || status === 403 || status === 404;

function isAbortError(error: unknown): boolean {
  return error instanceof DOMException && error.name === 'AbortError';
}

export function dashboardWindow(now = new Date()) {
  const date = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(now);
  const part = (name: string) => date.find((item) => item.type === name)?.value ?? '';
  const midnight = Date.UTC(Number(part('year')), Number(part('month')) - 1, Number(part('day'))) - 3 * 3600000;
  return {
    from: new Date(midnight - 7 * 86400000).toISOString(),
    to: new Date(midnight + 86400000).toISOString(),
    timezone: 'Europe/Istanbul',
  };
}

export { formatPlayDuration, mapSessionKpiView } from './session-kpi-presentation';
export { formatSessionKpiRate } from './session-kpi-presentation';

function statusLabel(status: string | null) {
  return ({ completed: 'Tamamlandı', skipped: 'Atlandı', not_now: 'Şimdi değil', partial: 'Kısmen' } as Record<string, string>)[status ?? ''] ?? 'Bilinmiyor';
}
function dateLabel(value: string | null | undefined) {
  if (!value) return 'Bilinmiyor';
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? 'Bilinmiyor' : date.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' });
}

function blockedSnapshot(childId: string): Snapshot {
  return { parentId: '', childId, blocked: true, kpi: { state: 'error' }, missions: { state: 'error' } };
}

export function WebParentDashboard({ selectedChildId }: { selectedChildId: string | null }) {
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [retry, setRetry] = useState(0);
  const generation = useRef(0);

  const refresh = useCallback(() => setRetry((n) => n + 1), []);
  // Revalidate visible dashboards without requiring a manual sync action.
  // Polling is bounded to one request cycle per 15 seconds; server remains authoritative.
  useEffect(() => {
    if (!selectedChildId) return;
    const timer = window.setInterval(() => {
      if (document.visibilityState !== 'visible' || !navigator.onLine) return;
      refresh();
    }, 15000);
    return () => window.clearInterval(timer);
  }, [selectedChildId, refresh]);
  const invalidateProtectedData = useCallback((childId: string) => {
    generation.current += 1;
    setSnapshot(blockedSnapshot(childId));
  }, []);

  useEffect(() => {
    const generationId = ++generation.current;
    const abort = new AbortController();
    if (!selectedChildId) {
      setSnapshot(null);
      return () => abort.abort();
    }
    // Retain the current child's numbers during routine polling to avoid
    // blinking KPI cards; child switches still clear immediately.
    setSnapshot((old) => old?.childId === selectedChildId ? old : null);
    const childId = selectedChildId;
    const params = new URLSearchParams(dashboardWindow());
    params.set('child_id', childId);
    const missionParams = new URLSearchParams(dashboardWindow());
    missionParams.set('limit', '50');

    async function load() {
      try {
        const me = await fetch('/api/auth/me', { cache: 'no-store', signal: abort.signal });
        if (!me.ok) throw Error('Oturum doğrulanamadı.');
        const parent = await me.json() as { parent_id?: string };
        if (!parent.parent_id) throw Error('Oturum doğrulanamadı.');
        const owner = parent.parent_id;
        const results = await Promise.all([
          fetch('/api/insights/session-kpis?' + params, { cache: 'no-store', signal: abort.signal }),
          fetch('/api/children/' + childId + '/missions?' + missionParams, { cache: 'no-store', signal: abort.signal }),
        ].map(async (request): Promise<{ status: number; data?: unknown }> => {
          try {
            const response = await request;
            return { status: response.status, data: response.ok ? await response.json() : undefined };
          } catch {
            if (abort.signal.aborted) throw Error('aborted');
            return { status: 503 };
          }
        }));
        if (abort.signal.aborted || generation.current !== generationId) return;
        const verify = await fetch('/api/auth/me', { cache: 'no-store', signal: abort.signal });
        if (!verify.ok || (await verify.json() as { parent_id?: string }).parent_id !== owner) {
          throw Error('Oturum değişti. Yeniden giriş yapın.');
        }
        if (abort.signal.aborted || generation.current !== generationId) return;
        const blocked = results.some((item) => failure(item.status));
        if (blocked) {
          setSnapshot({ parentId: owner, childId, blocked: true, kpi: { state: 'error' }, missions: { state: 'error' } });
          return;
        }
        const [kr, mr] = results;
        const kpiData = kr.status === 200 && kr.data && typeof kr.data === 'object' && 'metrics' in kr.data
          ? kr.data as Kpi
          : null;
        const kpiView = kpiData ? mapSessionKpiView(kpiData) : null;
        const kpi: Phase<Kpi> = kpiData && kpiView
          ? { state: kpiView.isEmpty ? 'empty' : 'ready', value: kpiData }
          : { state: 'error', message: 'Oturum özeti yüklenemedi.' };
        const missions: Phase<Missions> = mr.status === 200 && mr.data && typeof mr.data === 'object' && 'items' in mr.data && Array.isArray((mr.data as Missions).items)
          ? { state: (mr.data as Missions).items.length === 0 ? 'empty' : 'ready', value: mr.data as Missions }
          : { state: 'error', message: 'Görev durumları yüklenemedi.' };
        setSnapshot({ parentId: owner, childId, kpi, missions, blocked: false });
      } catch {
        if (abort.signal.aborted || generation.current !== generationId) return;
        setSnapshot(blockedSnapshot(childId));
      }
    }
    void load();
    return () => { abort.abort(); generation.current++; };
  }, [selectedChildId, retry]);

  useEffect(() => {
    if (!snapshot || snapshot.blocked || !selectedChildId || snapshot.childId !== selectedChildId) return;
    const expectedParent = snapshot.parentId;
    const childId = snapshot.childId;
    let revalidateEpoch = 0;
    let inFlightAbort: AbortController | null = null;

    async function revalidateSession() {
      const epoch = ++revalidateEpoch;
      inFlightAbort?.abort();
      const abort = new AbortController();
      inFlightAbort = abort;
      try {
        const me = await fetch('/api/auth/me', { cache: 'no-store', signal: abort.signal });
        if (epoch !== revalidateEpoch || abort.signal.aborted) return;
        if (!me.ok) {
          invalidateProtectedData(childId);
          return;
        }
        const parent = await me.json() as { parent_id?: string };
        if (epoch !== revalidateEpoch || abort.signal.aborted) return;
        if (!parent.parent_id || parent.parent_id !== expectedParent) {
          invalidateProtectedData(childId);
        }
      } catch (error) {
        const aborted = abort.signal.aborted;
        const superseded = epoch !== revalidateEpoch;
        if (aborted && superseded) return;
        if (aborted && !isAbortError(error)) {
          invalidateProtectedData(childId);
          return;
        }
        if (!aborted) invalidateProtectedData(childId);
      } finally {
        if (inFlightAbort === abort) inFlightAbort = null;
      }
    }

    function onFocus() {
      void revalidateSession();
    }

    function onVisibilityChange() {
      if (document.visibilityState === 'visible') void revalidateSession();
    }

    window.addEventListener('focus', onFocus);
    document.addEventListener('visibilitychange', onVisibilityChange);
    return () => {
      revalidateEpoch += 1;
      inFlightAbort?.abort();
      inFlightAbort = null;
      window.removeEventListener('focus', onFocus);
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, [snapshot, selectedChildId, invalidateProtectedData]);

  if (!selectedChildId) {
    return (
      <section aria-label="Ebeveyn özeti" className="parent-dashboard">
        <h2>Oyun ve görev özeti</h2>
        <ParentFeedback kind="info" title="Profil seçin" message="Özeti görmek için bir çocuk profili seçin." />
      </section>
    );
  }
  if (!snapshot || snapshot.childId !== selectedChildId) {
    return (
      <section aria-label="Ebeveyn özeti" className="parent-dashboard">
        <h2>Oyun ve görev özeti</h2>
        <p role="status">Özet yükleniyor…</p>
      </section>
    );
  }
  if (snapshot.blocked) {
    return (
      <section aria-label="Ebeveyn özeti" className="parent-dashboard">
        <h2>Oyun ve görev özeti</h2>
        <ParentFeedback
          kind="error"
          title="Erişim doğrulanamadı"
          message="Oturum veya çocuk erişimi doğrulanamadı. Korumalı bilgiler gizlendi."
          onRetry={refresh}
        />
      </section>
    );
  }

  const { kpi, missions } = snapshot;
  const kpiView = kpi.value ? mapSessionKpiView(kpi.value) : null;
  const windowMeta = dashboardWindow();

  const metrics = kpi.value?.metrics;

  return (
    <section aria-label="Ebeveyn özeti" className="parent-dashboard">
      <div className="parent-dashboard__toolbar">
        <div>
          <h2 className="parent-dashboard__heading">Oyun ve görev özeti</h2>
          <p className="parent-dashboard__hero">Son 7 tamamlanmış gün ve bugün</p>
        </div>

      </div>

      <LmCard title="Oturum KPI" subtitle="Sunucu oturum metrikleri">
        {kpi.state === 'error' ? (
          <ParentFeedback kind="error" title="Oturum özeti" message={kpi.message ?? 'Yüklenemedi.'} onRetry={refresh} />
        ) : (
          <>
            {kpi.state === 'empty' && (
              <ParentFeedback
                kind="info"
                title="Henüz oturum yok"
                message="Bu dönemde uygun oturum bulunamadı. Kartlar ve grafikler sunucudan gelen gerçek değerlerle doldurulur."
              />
            )}
            {kpi.value && kpiView && metrics && (
              <>
                <div className="parent-dashboard__kpi-grid">
                  <LmKpiMetric label="Uygun oturum" value={String(metrics.eligible_session_count)} emphasis />
                  <LmKpiMetric label="Tamamlanan" value={String(metrics.completed_session_count)} />
                  <LmKpiMetric label="Yarıda kalan" value={String(metrics.interrupted_session_count)} />
                  <LmKpiMetric label="Devam eden" value={String(metrics.in_progress_session_count)} />
                  <LmKpiMetric label="Toplam oyun süresi" value={formatPlayDuration(metrics.total_play_duration_seconds)} emphasis />
                  <LmKpiMetric
                    label="Tamamlanma oranı"
                    value={kpiView.completedRate.label}
                    unavailable={kpiView.completedRate.unavailable}
                  />
                  <LmKpiMetric label="Farklı oyun günü" value={String(metrics.distinct_play_days)} />
                  <LmKpiMetric
                    label="İlk deneme doğruluğu"
                    value={kpiView.accuracy.label}
                    unavailable={kpiView.accuracy.unavailable}
                  />
                </div>
                {kpiView.isStale && <ParentFeedback kind="warning" title="Güncellik" message="Veriler güncel olmayabilir." />}
                {kpiView.isPartial && <ParentFeedback kind="warning" title="Kısmi veri" message="Veri seti kısmi olabilir." />}
                <p className="parent-dashboard__status-line" role="status">
                  Tazelik: {freshnessStatusLabel(kpi.value.freshness.status)} · Bütünlük: {completenessLabel(kpi.value.freshness.data_completeness)} · {kpiView.sampleLabel}
                </p>
                <div className="parent-dashboard__charts">
                  <SessionCompositionDonut
                    eligible={metrics.eligible_session_count}
                    completed={metrics.completed_session_count}
                    interrupted={metrics.interrupted_session_count}
                    inProgress={metrics.in_progress_session_count}
                    abandoned={metrics.abandoned_session_count}
                  />
                  <ActivityDurationChart rows={kpiView.activityRows} maxSeconds={kpiView.maxPlaySeconds} />
                  <TrendsPlaceholderChart />
                </div>
                <LmDisclosure summary="Teknik ayrıntılar ve zaman aralığı">
                  <dl className="parent-dashboard__meta-list">
                    <div><dt>Güncellendi</dt><dd>{dateLabel(kpi.value.generated_at)}</dd></div>
                    <div><dt>Aralık</dt><dd>{dateLabel(kpi.value.window.from)} – {dateLabel(kpi.value.window.to)} (üst sınır hariç)</dd></div>
                    <div><dt>Saat dilimi</dt><dd>{windowMeta.timezone}</dd></div>
                  </dl>
                </LmDisclosure>
              </>
            )}
          </>
        )}
      </LmCard>

      <LmCard title="Gerçek dünya görevleri" subtitle="Sunucu kayıtlı etkileşim ve ebeveyn bildirimi">
        {missions.state === 'error' ? (
          <ParentFeedback kind="error" title="Görev durumları" message={missions.message ?? 'Yüklenemedi.'} onRetry={refresh} />
        ) : (
          <>
            {missions.state === 'empty' && (
              <p className="parent-dashboard__empty-copy" role="status">Bu dönemde görev kaydı bulunamadı.</p>
            )}
            {missions.value && (
              <>
                {missions.value.pagination.truncated && (
                  <ParentFeedback kind="warning" title="Sınırlı liste" message="En fazla 50 kayıt gösteriliyor; sonuçlar sınırlı." />
                )}
                <ul className="parent-dashboard__mission-list">
                  {missions.value.items.map((item) => (
                    <li key={item.occurrence_id} className="parent-dashboard__mission-item">
                      <p className="parent-dashboard__mission-title">Görev {item.mission_id}</p>
                      <p className="parent-dashboard__mission-copy">
                        {item.parent_report.availability === 'reported'
                          ? <>Ebeveyn bildirimi: {statusLabel(item.parent_report.status)} · {dateLabel(item.parent_report.recorded_at)}</>
                          : <>Ebeveyn bildirimi yok (uygulama etkileşimi tamamlanma kanıtı değildir)</>}
                      </p>
                    </li>
                  ))}
                </ul>
                <LmDisclosure summary="Görev kaynağı ve pencere ayrıntıları">
                  <dl className="parent-dashboard__meta-list">
                    <div><dt>Güncellendi</dt><dd>{dateLabel(missions.value.generated_at)}</dd></div>
                    <div><dt>Aralık</dt><dd>{dateLabel(missions.value.window.from)} – {dateLabel(missions.value.window.to)} (üst sınır hariç)</dd></div>
                    {missions.value.items.map((item) => item.parent_report.availability === 'reported' && (
                      <div key={`${item.occurrence_id}-prov`}>
                        <dt>{item.mission_id} kaynağı</dt>
                        <dd>{missionReportSourceLabel(item.parent_report.source)} · {missionReportActorLabel(item.parent_report.actor)} · {item.parent_report.authoritative ? 'Yetkili kayıt' : 'Bilgilendirici'}</dd>
                      </div>
                    ))}
                  </dl>
                </LmDisclosure>
              </>
            )}
          </>
        )}
      </LmCard>
    </section>
  );
}

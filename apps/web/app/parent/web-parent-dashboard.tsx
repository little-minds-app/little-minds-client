'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import type { components } from '../../../../generated/typescript/schema';
import { ActivityDurationChart } from './dashboard-charts';
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
    setSnapshot(null);
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

  return (
    <section aria-label="Ebeveyn özeti" className="parent-dashboard">
      <h2>Oyun ve görev özeti</h2>
      <p className="parent-dashboard__hero">Son 7 tamamlanmış gün ve bugün · {windowMeta.timezone}</p>
      <button type="button" onClick={refresh}>Özeti yenile</button>

      <section aria-label="Oturum KPI" className="parent-dashboard__panel">
        <h3>Oturum istatistikleri</h3>
        {kpi.state === 'error' ? (
          <ParentFeedback kind="error" title="Oturum özeti" message={kpi.message ?? 'Yüklenemedi.'} onRetry={refresh} />
        ) : (
          <>
            {kpi.state === 'empty' && (
              <ParentFeedback
                kind="info"
                title="Henüz oturum yok"
                message="Bu dönemde uygun oturum bulunamadı. Aşağıdaki sayılar ve örnek bilgileri sunucudan gelmektedir."
              />
            )}
            {kpi.value && kpiView && (
              <>
                <dl className="parent-dashboard__metrics">
                  <div><dt>Uygun oturum</dt><dd>{kpi.value.metrics.eligible_session_count}</dd></div>
                  <div><dt>Tamamlanan</dt><dd>{kpi.value.metrics.completed_session_count}</dd></div>
                  <div><dt>Yarıda kalan</dt><dd>{kpi.value.metrics.interrupted_session_count}</dd></div>
                  <div><dt>Devam eden</dt><dd>{kpi.value.metrics.in_progress_session_count}</dd></div>
                  <div><dt>Toplam oyun süresi</dt><dd>{formatPlayDuration(kpi.value.metrics.total_play_duration_seconds)}</dd></div>
                  <div>
                    <dt>Tamamlanma oranı</dt>
                    <dd>{kpiView.completedRate.unavailable
                      ? <span aria-label="Oran kullanılamıyor">{kpiView.completedRate.label}</span>
                      : kpiView.completedRate.label}</dd>
                  </div>
                  <div><dt>Farklı oyun günü</dt><dd>{kpi.value.metrics.distinct_play_days}</dd></div>
                  <div>
                    <dt>İlk deneme doğruluğu</dt>
                    <dd>{kpiView.accuracy.unavailable
                      ? <span aria-label="Oran kullanılamıyor">{kpiView.accuracy.label}</span>
                      : kpiView.accuracy.label}</dd>
                  </div>
                </dl>
                <p>Tazelik: {freshnessStatusLabel(kpi.value.freshness.status)} · Bütünlük: {completenessLabel(kpi.value.freshness.data_completeness)}</p>
                <p>{kpiView.sampleLabel}</p>
                {kpiView.isStale && <ParentFeedback kind="warning" title="Güncellik" message="Veriler güncel olmayabilir." />}
                {kpiView.isPartial && <ParentFeedback kind="warning" title="Kısmi veri" message="Veri seti kısmi olabilir." />}
                <p>Güncellendi: {dateLabel(kpi.value.generated_at)}</p>
                <p>Aralık: {dateLabel(kpi.value.window.from)} – {dateLabel(kpi.value.window.to)} (üst sınır hariç)</p>
                <ActivityDurationChart rows={kpiView.activityRows} maxSeconds={kpiView.maxPlaySeconds} />
              </>
            )}
          </>
        )}
      </section>

      <section aria-label="Gerçek dünya görevleri" className="parent-dashboard__panel">
        <h3>Gerçek dünya görevleri</h3>
        {missions.state === 'error' ? (
          <ParentFeedback kind="error" title="Görev durumları" message={missions.message ?? 'Yüklenemedi.'} onRetry={refresh} />
        ) : (
          <>
            {missions.state === 'empty' && <p>Bu dönemde görev kaydı bulunamadı.</p>}
            {missions.value && (
              <>
                {missions.value.pagination.truncated && (
                  <ParentFeedback kind="warning" title="Sınırlı liste" message="En fazla 50 kayıt gösteriliyor; sonuçlar sınırlı." />
                )}
                <p>Güncellendi: {dateLabel(missions.value.generated_at)} · Kaynak: sunucu</p>
                <p>Aralık: {dateLabel(missions.value.window.from)} – {dateLabel(missions.value.window.to)} (üst sınır hariç)</p>
                <ul>{missions.value.items.map((item) => (
                  <li key={item.occurrence_id}>
                    <strong>Görev {item.mission_id}</strong>{' — '}
                    {item.parent_report.availability === 'reported'
                      ? <>Ebeveyn bildirimi: {statusLabel(item.parent_report.status)} · Kaynak: {missionReportSourceLabel(item.parent_report.source)} · Aktör: {missionReportActorLabel(item.parent_report.actor)} · {item.parent_report.authoritative ? 'Yetkili kayıt' : 'Bilgilendirici'} · {dateLabel(item.parent_report.recorded_at)}</>
                      : <>Ebeveyn bildirimi yok (uygulama etkileşimi tamamlanma kanıtı değildir)</>}
                  </li>
                ))}</ul>
              </>
            )}
          </>
        )}
      </section>
    </section>
  );
}

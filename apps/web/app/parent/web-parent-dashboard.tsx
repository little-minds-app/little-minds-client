'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import type { components } from '../../../../generated/typescript/schema';

type Kpi = components['schemas']['SessionKpiResponse'];
type Missions = components['schemas']['MissionStatusListResponse'];
type Phase<T> = { state: 'loading' | 'empty' | 'error' | 'ready'; value?: T; message?: string };
type Snapshot = { parentId: string; childId: string; kpi: Phase<Kpi>; missions: Phase<Missions>; blocked: boolean };

const failure = (status: number) => status === 401 || status === 403 || status === 404;

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

function statusLabel(status: string | null) {
  return ({ completed: 'Tamamlandı', skipped: 'Atlandı', not_now: 'Şimdi değil', partial: 'Kısmen' } as Record<string, string>)[status ?? ''] ?? 'Bilinmiyor';
}
function readable(seconds: number) { return Math.round(seconds / 60) + ' dk'; }
function dateLabel(value: string | null | undefined) {
  if (!value) return 'Bilinmiyor';
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? 'Bilinmiyor' : date.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' });
}

export function WebParentDashboard({ selectedChildId }: { selectedChildId: string | null }) {
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [retry, setRetry] = useState(0);
  const generation = useRef(0);

  const refresh = useCallback(() => setRetry((n) => n + 1), []);

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
        // No protected data may be committed until the session has been re-checked.
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
        const kpi: Phase<Kpi> = kr.status === 200 && kr.data && typeof kr.data === 'object' && 'metrics' in kr.data
          ? { state: (kr.data as Kpi).sample.eligible_sessions === 0 ? 'empty' : 'ready', value: kr.data as Kpi }
          : { state: 'error', message: 'Oturum özeti yüklenemedi.' };
        const missions: Phase<Missions> = mr.status === 200 && mr.data && typeof mr.data === 'object' && 'items' in mr.data && Array.isArray((mr.data as Missions).items)
          ? { state: (mr.data as Missions).items.length === 0 ? 'empty' : 'ready', value: mr.data as Missions }
          : { state: 'error', message: 'Görev durumları yüklenemedi.' };
        setSnapshot({ parentId: owner, childId, kpi, missions, blocked: false });
      } catch {
        if (abort.signal.aborted || generation.current !== generationId) return;
        setSnapshot({ parentId: '', childId, blocked: true, kpi: { state: 'error' }, missions: { state: 'error' } });
      }
    }
    void load();
    return () => { abort.abort(); generation.current++; };
  }, [selectedChildId, retry]);

  if (!selectedChildId) return <section aria-label="Ebeveyn özeti"><h2>Oyun ve görev özeti</h2><p>Özeti görmek için bir çocuk profili seçin.</p></section>;
  if (!snapshot || snapshot.childId !== selectedChildId) return <section aria-label="Ebeveyn özeti"><h2>Oyun ve görev özeti</h2><p role="status">Özet yükleniyor…</p></section>;
  if (snapshot.blocked) return <section aria-label="Ebeveyn özeti"><h2>Oyun ve görev özeti</h2><p role="alert">Oturum veya çocuk erişimi doğrulanamadı. Korumalı bilgiler gizlendi.</p><button onClick={refresh}>Yeniden dene</button></section>;

  const { kpi, missions } = snapshot;
  return <section aria-label="Ebeveyn özeti">
    <h2>Oyun ve görev özeti</h2>
    <p>Son 7 tamamlanmış gün ve bugün · Europe/Istanbul</p>
    <button onClick={refresh}>Özeti yenile</button>
    <section aria-label="Oturum KPI">
      <h3>Oturum istatistikleri</h3>
      {kpi.state === 'error' ? <p role="alert">{kpi.message} <button onClick={refresh}>Yeniden dene</button></p> : <>
        {kpi.state === 'empty' && <p>Bu dönemde uygun oturum bulunamadı.</p>}
        {kpi.value && <>
          <dl>
            <dt>Uygun oturum</dt><dd>{kpi.value.metrics.eligible_session_count}</dd>
            <dt>Tamamlanan oturum</dt><dd>{kpi.value.metrics.completed_session_count}</dd>
            <dt>Oyun süresi</dt><dd>{readable(kpi.value.metrics.total_play_duration_seconds)}</dd>
            <dt>Oynanan gün</dt><dd>{kpi.value.metrics.distinct_play_days}</dd>
          </dl>
          <p>Veri: {kpi.value.freshness.status} · Kapsam: {kpi.value.freshness.data_completeness}</p>
          <p>Güncellendi: {dateLabel(kpi.value.generated_at)}</p>
          <p>Aralık: {dateLabel(kpi.value.window.from)} – {dateLabel(kpi.value.window.to)} (üst sınır hariç)</p>
        </>}
      </>}
    </section>
    <section aria-label="Gerçek dünya görevleri">
      <h3>Gerçek dünya görevleri</h3>
      {missions.state === 'error' ? <p role="alert">{missions.message} <button onClick={refresh}>Yeniden dene</button></p> : <>
        {missions.state === 'empty' && <p>Bu dönemde görev kaydı bulunamadı.</p>}
        {missions.value && <>
          {missions.value.pagination.truncated && <p role="status">En fazla 50 kayıt gösteriliyor; sonuçlar sınırlı.</p>}
          <p>Güncellendi: {dateLabel(missions.value.generated_at)} · Kaynak: sunucu</p>
          <p>Aralık: {dateLabel(missions.value.window.from)} – {dateLabel(missions.value.window.to)} (üst sınır hariç)</p>
          <ul>{missions.value.items.map((item) => <li key={item.occurrence_id}>
            <strong>Görev {item.mission_id}</strong>{' — '}
            {item.parent_report.availability === 'reported'
              ? <>Ebeveyn bildirimi: {statusLabel(item.parent_report.status)} · Kaynak: {item.parent_report.source} · Aktör: {item.parent_report.actor} · {item.parent_report.authoritative ? 'Yetkili kayıt' : 'Bilgilendirici'} · {dateLabel(item.parent_report.recorded_at)}</>
              : <>Ebeveyn bildirimi yok (uygulama etkileşimi tamamlanma kanıtı değildir)</>}
          </li>)}</ul>
        </>}
      </>}
    </section>
  </section>;
}

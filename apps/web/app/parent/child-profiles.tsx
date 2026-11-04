'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import { LmButton, LmDisclosure, LmField, LmInput, LmCard } from './lm-ui';
import { ParentFeedback, type ParentFeedbackKind } from './parent-feedback';

type Profile = { child_id: string; nickname: string | null; age_months: number; preferred_locale: string };
type Form = { nickname: string; age_months: string };
type RetryAction = 'reload' | 'save';
type FeedbackState = { kind: ParentFeedbackKind; title: string; message: string; retry: RetryAction } | null;

const emptyForm = { nickname: '', age_months: '32' };

/** Matches Flutter child profile repository and OpenAPI IANA default. */
export const PROFILE_REFERENCE_TIMEZONE = 'Europe/Istanbul';

export function istanbulToday(): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const read = (part: string) => parts.find((item) => item.type === part)?.value ?? '';
  return `${read('year')}-${read('month')}-${read('day')}`;
}

export function profileSaveErrorMessage(status: number): string {
  switch (status) {
    case 400:
      return 'Girilen profil bilgisi sunucu tarafından kabul edilmedi. Yaş ve takma adı kontrol edin.';
    case 401:
      return 'Oturum sona erdi. Yeniden giriş yapın.';
    case 403:
      return 'Bu işlem için yetkiniz yok.';
    case 404:
      return 'Profil bulunamadı veya size ait değil.';
    case 409:
      return 'Profil çakışması. Listeyi yenileyip tekrar deneyin.';
    case 502:
    case 503:
      return 'Sunucu geçici olarak kullanılamıyor. Kaydı tekrar deneyin.';
    default:
      if (status >= 500) return 'Sunucu hatası. Kaydı tekrar deneyin.';
      return 'Profil kaydedilemedi.';
  }
}

function profileListErrorMessage(status: number): string {
  switch (status) {
    case 401:
      return 'Oturum sona erdi. Yeniden giriş yapın.';
    case 403:
      return 'Profil listesine erişim reddedildi.';
    case 502:
    case 503:
      return 'Sunucu geçici olarak kullanılamıyor. Listeyi tekrar yükleyin.';
    default:
      if (status >= 500) return 'Sunucu hatası. Listeyi tekrar yükleyin.';
      return 'Profiller yüklenemedi.';
  }
}

export function ChildProfiles({
  onSelectionChange,
  dashboardBetween,
  profilesPanel,
}: {
  onSelectionChange?: (childId: string | null, label?: string | null) => void;
  dashboardBetween?: (selectedChildId: string | null) => React.ReactNode;
  profilesPanel?: React.ReactNode;
} = {}) {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [form, setForm] = useState<Form>(emptyForm);
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState<FeedbackState>(null);
  const [loading, setLoading] = useState(true);
  const requestGeneration = useRef(0);
  const parentIdentity = useRef<string | null>(null);

  const refreshChildrenList = useCallback(async (generation: number): Promise<Profile[] | false> => {
    const me = await fetch('/api/auth/me', { cache: 'no-store' });
    if (generation !== requestGeneration.current) return false;
    if (me.status === 401) throw new Error(profileListErrorMessage(401));
    if (!me.ok) throw new Error('Oturum doğrulanamadı.');
    const identity = await me.json() as { parent_id?: string };
    if (generation !== requestGeneration.current) return false;
    if (!identity.parent_id) throw new Error('Geçersiz ebeveyn oturumu.');
    const response = await fetch('/api/children', { cache: 'no-store' });
    if (generation !== requestGeneration.current) return false;
    if (response.status === 401) throw new Error(profileListErrorMessage(401));
    if (!response.ok) throw new Error(profileListErrorMessage(response.status));
    const data = await response.json() as { children: Profile[] };
    const verify = await fetch('/api/auth/me', { cache: 'no-store' });
    if (generation !== requestGeneration.current) return false;
    if (!verify.ok || (await verify.json() as { parent_id?: string }).parent_id !== identity.parent_id) {
      throw new Error('Oturum değişti. Yeniden deneyin.');
    }
    if (generation !== requestGeneration.current) return false;
    const children = Array.isArray(data.children) ? data.children : [];
    setProfiles(children);
    return children;
  }, []);

  const reload = useCallback(async (): Promise<boolean> => {
    const generation = ++requestGeneration.current;
    setLoading(true);
    setFeedback(null);
    setProfiles([]);
    setSelected(null);
    onSelectionChange?.(null);
    try {
      const me = await fetch('/api/auth/me', { cache: 'no-store' });
      if (generation !== requestGeneration.current) return false;
      if (me.status === 401) throw new Error(profileListErrorMessage(401));
      if (!me.ok) throw new Error('Oturum doğrulanamadı.');
      const identity = await me.json() as { parent_id?: string };
      if (generation !== requestGeneration.current) return false;
      if (!identity.parent_id) throw new Error('Geçersiz ebeveyn oturumu.');
      if (parentIdentity.current !== identity.parent_id) {
        parentIdentity.current = identity.parent_id;
        setEditing(null);
        setForm(emptyForm);
      }
      return (await refreshChildrenList(generation)) !== false;
    } catch (e) {
      if (generation !== requestGeneration.current) return false;
      setProfiles([]);
      setSelected(null);
      onSelectionChange?.(null);
      const message = e instanceof Error ? e.message : 'Bağlantı hatası. Listeyi tekrar yükleyin.';
      setFeedback({
        kind: 'error',
        title: 'Profil listesi yüklenemedi',
        message,
        retry: 'reload',
      });
      return false;
    } finally {
      if (generation === requestGeneration.current) setLoading(false);
    }
  }, [onSelectionChange, refreshChildrenList]);

  useEffect(() => {
    void reload();
    return () => { requestGeneration.current += 1; };
  }, [reload]);

  function profileLabel(profile: Profile) {
    return profile.nickname || 'Çocuk profili';
  }

  function selectProfile(profile: Profile) {
    setSelected(profile.child_id);
    onSelectionChange?.(profile.child_id, `${profileLabel(profile)} · ${profile.age_months} ay`);
  }

  const performSave = useCallback(async () => {
    const months = Number(form.age_months);
    if (!Number.isInteger(months) || months < 0 || months > 2147483647) {
      setFeedback({
        kind: 'error',
        title: 'Geçersiz yaş',
        message: 'Yaş geçerli bir ay sayısı olmalı.',
        retry: 'save',
      });
      return;
    }
    const referenceDate = istanbulToday();
    const body = editing
      ? {
          nickname: form.nickname.trim() || null,
          age_months: months,
          reference_date: referenceDate,
          timezone: PROFILE_REFERENCE_TIMEZONE,
        }
      : {
          nickname: form.nickname.trim() || undefined,
          age_months: months,
          reference_date: referenceDate,
          timezone: PROFILE_REFERENCE_TIMEZONE,
        };
    setBusy(true);
    setFeedback(null);
    const generation = ++requestGeneration.current;
    try {
      const url = editing ? '/api/children/' + editing : '/api/children';
      const res = await fetch(url, {
        method: editing ? 'PATCH' : 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (generation !== requestGeneration.current) return;
      if (!res.ok) {
        setFeedback({
          kind: 'error',
          title: 'Profil kaydedilemedi',
          message: profileSaveErrorMessage(res.status),
          retry: 'save',
        });
        return;
      }
      setEditing(null);
      setForm(emptyForm);
      try {
        const refreshed = await refreshChildrenList(generation);
        if (generation !== requestGeneration.current) return;
        if (refreshed === false) {
          setFeedback({
            kind: 'warning',
            title: 'Kayıt alındı',
            message: 'Profil sunucuda kaydedildi ancak liste güncellenemedi. Listeyi yeniden yükleyin.',
            retry: 'reload',
          });
          return;
        }
        if (selected) {
          const profile = refreshed.find((row) => row.child_id === selected);
          if (profile) {
            onSelectionChange?.(selected, `${profileLabel(profile)} · ${profile.age_months} ay`);
          }
        }
        setFeedback({
          kind: 'success',
          title: 'Kaydedildi',
          message: 'Profil sunucuda kaydedildi.',
          retry: 'reload',
        });
      } catch (e) {
        if (generation !== requestGeneration.current) return;
        const message = e instanceof Error ? e.message : 'Liste güncellenemedi.';
        setFeedback({
          kind: 'warning',
          title: 'Kayıt alındı',
          message: `Profil sunucuda kaydedildi ancak liste güncellenemedi. ${message}`,
          retry: 'reload',
        });
      }
    } catch {
      if (generation !== requestGeneration.current) return;
      setFeedback({
        kind: 'error',
        title: 'Bağlantı hatası',
        message: 'Ağ hatası nedeniyle profil kaydedilemedi. Kaydı tekrar deneyin.',
        retry: 'save',
      });
    } finally {
      if (generation === requestGeneration.current) setBusy(false);
    }
  }, [editing, form, onSelectionChange, refreshChildrenList, selected]);

  async function save(event: React.FormEvent) {
    event.preventDefault();
    await performSave();
  }

  function handleRetry() {
    if (feedback?.retry === 'save') void performSave();
    else void reload();
  }

  const picker = (
    <div className="child-picker" aria-label="Çocuk profili seçimi">
      {loading ? <p role="status">Profiller yükleniyor…</p> : profiles.length === 0 ? (
        <p className="child-picker__empty">Henüz çocuk profili yok. Aşağıdaki profil bölümünden ekleyin.</p>
      ) : (
        <div className="child-picker__chips" role="list">
          {profiles.map((profile) => (
            <LmButton
              key={profile.child_id}
              variant="chip"
              aria-pressed={selected === profile.child_id}
              onClick={() => selectProfile(profile)}
            >
              {profileLabel(profile)} · {profile.age_months} ay
            </LmButton>
          ))}
        </div>
      )}
    </div>
  );

  const editor = (
    <LmCard title="Çocuk profilleri" subtitle="Kesin doğum tarihi gerekmiyor; yaşı ay olarak girin.">
      {feedback && (
        <ParentFeedback
          kind={feedback.kind}
          title={feedback.title}
          message={feedback.message}
          onRetry={feedback.kind === 'success' ? undefined : handleRetry}
          retryLabel={feedback.retry === 'save' ? 'Kaydı tekrar dene' : 'Listeyi tekrar yükle'}
        />
      )}
      {loading ? <p role="status">Profiller yükleniyor…</p> : profiles.length === 0 ? <p>Henüz çocuk profili yok.</p> : (
        <ul className="child-profile-list">
          {profiles.map((profile) => (
            <li key={profile.child_id}>
              <span>{profileLabel(profile)} — {profile.age_months} ay</span>
              <LmButton
                variant="ghost"
                onClick={() => {
                  setEditing(profile.child_id);
                  setForm({ nickname: profile.nickname ?? '', age_months: String(profile.age_months) });
                }}
              >
                Düzenle
              </LmButton>
            </li>
          ))}
        </ul>
      )}
      <div className="child-profile-actions">
        <LmButton variant="secondary" onClick={() => { setEditing(null); setForm(emptyForm); }}>Yeni profil</LmButton>
      </div>
      <form className="lm-form" onSubmit={(event) => void save(event)}>
        <h3 className="lm-form__title">{editing ? 'Profili düzenle' : 'Profil oluştur'}</h3>
        <LmField label="Takma ad (isteğe bağlı)" htmlFor="child-nickname">
          <LmInput id="child-nickname" maxLength={80} value={form.nickname} onChange={(e) => setForm((f) => ({ ...f, nickname: e.target.value }))} />
        </LmField>
        <LmField label="Yaş (ay)" htmlFor="child-age">
          <LmInput id="child-age" type="number" required min={0} max={2147483647} step={1} value={form.age_months} onChange={(e) => setForm((f) => ({ ...f, age_months: e.target.value }))} />
        </LmField>
        <LmButton type="submit" disabled={busy}>{busy ? 'Kaydediliyor…' : 'Kaydet'}</LmButton>
      </form>
    </LmCard>
  );

  if (dashboardBetween) {
    return (
      <>
        {picker}
        {dashboardBetween(selected)}
        <LmDisclosure summary="Profil ve hesap ayarları" defaultOpen={false}>
          {editor}
          {profilesPanel}
        </LmDisclosure>
      </>
    );
  }

  return (
    <section aria-label="Çocuk profilleri">
      {picker}
      {editor}
    </section>
  );
}

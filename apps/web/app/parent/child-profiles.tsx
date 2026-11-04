'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ParentFeedback, type ParentFeedbackKind } from './parent-feedback';

type Profile = { child_id: string; nickname: string | null; age_months: number; preferred_locale: string };
type Form = { nickname: string; age_months: string };
type RetryAction = 'reload' | 'save';
type FeedbackState = { kind: ParentFeedbackKind; title: string; message: string; retry: RetryAction } | null;

const emptyForm = { nickname: '', age_months: '32' };

function istanbulToday(): string {
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

export function ChildProfiles({ onSelectionChange }: { onSelectionChange?: (childId: string | null) => void } = {}) {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [form, setForm] = useState<Form>(emptyForm);
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState<FeedbackState>(null);
  const [loading, setLoading] = useState(true);
  const requestGeneration = useRef(0);
  const parentIdentity = useRef<string | null>(null);

  const refreshChildrenList = useCallback(async (generation: number): Promise<boolean> => {
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
    setProfiles(Array.isArray(data.children) ? data.children : []);
    return true;
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
      const ok = await refreshChildrenList(generation);
      return ok;
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
    const body = editing
      ? { nickname: form.nickname.trim() || null, age_months: months, reference_date: istanbulToday() }
      : { nickname: form.nickname.trim() || undefined, age_months: months, reference_date: istanbulToday() };
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
        if (!refreshed) {
          setFeedback({
            kind: 'warning',
            title: 'Kayıt alındı',
            message: 'Profil sunucuda kaydedildi ancak liste güncellenemedi. Listeyi yeniden yükleyin.',
            retry: 'reload',
          });
          return;
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
  }, [editing, form, refreshChildrenList]);

  async function save(event: React.FormEvent) {
    event.preventDefault();
    await performSave();
  }

  function handleRetry() {
    if (feedback?.retry === 'save') void performSave();
    else void reload();
  }

  return (
    <section aria-label="Çocuk profilleri">
      <h2>Çocuk profilleri</h2>
      <p>Kesin doğum tarihi gerekmiyor. Çocuğunuzun yaklaşık yaşını ay olarak girin.</p>
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
        <ul>{profiles.map((profile) => (
          <li key={profile.child_id}>
            <button type="button" aria-pressed={selected === profile.child_id} onClick={() => { setSelected(profile.child_id); onSelectionChange?.(profile.child_id); }}>
              {profile.nickname || 'Çocuk profili'} — {profile.age_months} ay
            </button>{' '}
            <button type="button" onClick={() => { setEditing(profile.child_id); setForm({ nickname: profile.nickname ?? '', age_months: String(profile.age_months) }); }}>Düzenle</button>
          </li>
        ))}</ul>
      )}
      {selected && <p role="status">Seçili profil: {profiles.find((p) => p.child_id === selected)?.nickname || 'Çocuk profili'}</p>}
      <button type="button" onClick={() => { setEditing(null); setForm(emptyForm); }}>Yeni profil</button>
      <form onSubmit={(event) => void save(event)}>
        <h3>{editing ? 'Profili düzenle' : 'Profil oluştur'}</h3>
        <label>Takma ad (isteğe bağlı)<input maxLength={80} value={form.nickname} onChange={(e) => setForm((f) => ({ ...f, nickname: e.target.value }))}/></label>
        <label>Yaş (ay)<input type="number" required min={0} max={2147483647} step={1} value={form.age_months} onChange={(e) => setForm((f) => ({ ...f, age_months: e.target.value }))}/></label>
        <button type="submit" disabled={busy}>{busy ? 'Kaydediliyor…' : 'Kaydet'}</button>
      </form>
    </section>
  );
}

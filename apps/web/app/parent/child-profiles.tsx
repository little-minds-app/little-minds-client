'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ParentFeedback } from './parent-feedback';

type Profile = { child_id: string; nickname: string | null; age_months: number; preferred_locale: string };
type Form = { nickname: string; age_months: string };
const emptyForm = { nickname: '', age_months: '32' };

function istanbulToday(): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const read = (part: string) => parts.find((item) => item.type === part)?.value ?? '';
  return `${read('year')}-${read('month')}-${read('day')}`;
}

function profileSaveErrorMessage(status: number): string {
  switch (status) {
    case 400:
      return 'Girilen profil bilgisi sunucu tarafından kabul edilmedi. Yaş ve takma adı kontrol edin.';
    case 401:
      return 'Oturum sona erdi. Yeniden giriş yapın.';
    case 403:
      return 'Bu işlem için yetkiniz yok.';
    case 404:
      return 'Profil bulunamadı veya size ait değil.';
    default:
      return 'Profil kaydedilemedi.';
  }
}

export function ChildProfiles({ onSelectionChange }: { onSelectionChange?: (childId: string | null) => void } = {}) {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [form, setForm] = useState<Form>(emptyForm);
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(true);
  const requestGeneration = useRef(0);
  const parentIdentity = useRef<string | null>(null);

  const reload = useCallback(async () => {
    const generation = ++requestGeneration.current;
    setLoading(true);
    setError('');
    setProfiles([]);
    setSelected(null);
    onSelectionChange?.(null);
    try {
      const me = await fetch('/api/auth/me', { cache: 'no-store' });
      if (generation !== requestGeneration.current) return;
      if (me.status === 401) throw new Error('Oturum sona erdi. Yeniden giriş yapın.');
      if (!me.ok) throw new Error('Oturum doğrulanamadı.');
      const identity = await me.json() as { parent_id?: string };
      if (generation !== requestGeneration.current) return;
      if (!identity.parent_id) throw new Error('Geçersiz ebeveyn oturumu.');
      if (parentIdentity.current !== identity.parent_id) {
        parentIdentity.current = identity.parent_id;
        setEditing(null);
        setForm(emptyForm);
      }
      const response = await fetch('/api/children', { cache: 'no-store' });
      if (generation !== requestGeneration.current) return;
      if (response.status === 401) throw new Error('Oturum sona erdi. Yeniden giriş yapın.');
      if (!response.ok) throw new Error('Profiller yüklenemedi.');
      const data = await response.json() as { children: Profile[] };
      const verify = await fetch('/api/auth/me', { cache: 'no-store' });
      if (generation !== requestGeneration.current) return;
      if (!verify.ok || (await verify.json() as { parent_id?: string }).parent_id !== identity.parent_id) {
        throw new Error('Oturum değişti. Yeniden deneyin.');
      }
      if (generation !== requestGeneration.current) return;
      setProfiles(Array.isArray(data.children) ? data.children : []);
    } catch (e) {
      if (generation !== requestGeneration.current) return;
      setProfiles([]);
      setSelected(null);
      onSelectionChange?.(null);
      setError(e instanceof Error ? e.message : 'Bağlantı hatası');
    } finally {
      if (generation === requestGeneration.current) setLoading(false);
    }
  }, [onSelectionChange]);

  useEffect(() => {
    void reload();
    return () => { requestGeneration.current++; };
  }, [reload]);

  async function save(event: React.FormEvent) {
    event.preventDefault();
    const months = Number(form.age_months);
    if (!Number.isInteger(months) || months < 0 || months > 2147483647) {
      setError('Yaş geçerli bir ay sayısı olmalı.');
      setSuccess('');
      return;
    }
    const body = editing
      ? { nickname: form.nickname.trim() || null, age_months: months, reference_date: istanbulToday() }
      : { nickname: form.nickname.trim() || undefined, age_months: months, reference_date: istanbulToday() };
    setBusy(true);
    setError('');
    setSuccess('');
    try {
      const url = editing ? '/api/children/' + editing : '/api/children';
      const res = await fetch(url, {
        method: editing ? 'PATCH' : 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error(profileSaveErrorMessage(res.status));
      setEditing(null);
      setForm(emptyForm);
      await reload();
      setSuccess('Profil sunucuda kaydedildi.');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Bağlantı hatası');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section aria-label="Çocuk profilleri">
      <h2>Çocuk profilleri</h2>
      <p>Kesin doğum tarihi gerekmiyor. Çocuğunuzun yaklaşık yaşını ay olarak girin.</p>
      {success && <ParentFeedback kind="success" title="Kaydedildi" message={success} />}
      {error && (
        <ParentFeedback
          kind="error"
          title="Profil işlemi başarısız"
          message={error}
          onRetry={() => void reload()}
          retryLabel="Tekrar dene"
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

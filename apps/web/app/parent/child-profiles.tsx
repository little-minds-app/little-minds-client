'use client';

import { useCallback, useEffect, useState } from 'react';

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

export function ChildProfiles() {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [form, setForm] = useState<Form>(emptyForm);
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  const reload = useCallback(async () => {
    setError('');
    try {
      const res = await fetch('/api/children', { cache: 'no-store' });
      if (res.status === 401) { setProfiles([]); setSelected(null); throw new Error('Oturum sona erdi. Yeniden giriş yapın.'); }
      if (!res.ok) throw new Error('Profiller yüklenemedi.');
      const data = await res.json() as { children: Profile[] };
      setProfiles(data.children);
      setSelected((current) => data.children.some((p) => p.child_id === current) ? current : null);
    } catch (e) { setError(e instanceof Error ? e.message : 'Bağlantı hatası'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { void reload(); }, [reload]);

  async function save(event: React.FormEvent) {
    event.preventDefault();
    const months = Number(form.age_months);
    if (!Number.isInteger(months) || months < 0 || months > 2147483647) { setError('Yaş geçerli bir ay sayısı olmalı.'); return; }
    const body = editing
      ? { nickname: form.nickname.trim() || null, age_months: months, reference_date: istanbulToday() }
      : { nickname: form.nickname.trim() || undefined, age_months: months, reference_date: istanbulToday() };
    setBusy(true); setError('');
    try {
      const url = editing ? '/api/children/' + editing : '/api/children';
      const res = await fetch(url, { method: editing ? 'PATCH' : 'POST',
        headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
      if (!res.ok) throw new Error(res.status === 401 ? 'Oturum sona erdi.' : 'Profil kaydedilemedi.');
      setEditing(null); setForm(emptyForm);
      await reload();
    } catch (e) { setError(e instanceof Error ? e.message : 'Bağlantı hatası'); }
    finally { setBusy(false); }
  }

  return <section aria-label="Çocuk profilleri">
    <h2>Çocuk profilleri</h2>
    <p>Kesin doğum tarihi gerekmiyor. Çocuğunuzun yaklaşık yaşını ay olarak girin.</p>
    {loading ? <p role="status">Profiller yükleniyor…</p> : profiles.length === 0 ? <p>Henüz çocuk profili yok.</p> : (
      <ul>{profiles.map((profile) => <li key={profile.child_id}>
        <button type="button" aria-pressed={selected === profile.child_id} onClick={() => setSelected(profile.child_id)}>
          {profile.nickname || 'Çocuk profili'} — {profile.age_months} ay
        </button>{' '}
        <button type="button" onClick={() => { setEditing(profile.child_id); setForm({ nickname: profile.nickname ?? '', age_months: String(profile.age_months) }); }}>Düzenle</button>
      </li>)}</ul>
    )}
    {selected && <p role="status">Seçili profil: {profiles.find((p) => p.child_id === selected)?.nickname || 'Çocuk profili'}</p>}
    <button type="button" onClick={() => { setEditing(null); setForm(emptyForm); }}>Yeni profil</button>
    <form onSubmit={(event) => void save(event)}>
      <h3>{editing ? 'Profili düzenle' : 'Profil oluştur'}</h3>
      <label>Takma ad (isteğe bağlı)<input maxLength={80} value={form.nickname} onChange={(e) => setForm((f) => ({ ...f, nickname: e.target.value }))}/></label>
      <label>Yaş (ay)<input type="number" required min={0} max={2147483647} step={1} value={form.age_months} onChange={(e) => setForm((f) => ({ ...f, age_months: e.target.value }))}/></label>
      <button type="submit" disabled={busy}>{busy ? 'Kaydediliyor…' : 'Kaydet'}</button>
    </form>
    {error && <p role="alert">{error} <button type="button" onClick={() => void reload()}>Tekrar dene</button></p>}
  </section>;
}

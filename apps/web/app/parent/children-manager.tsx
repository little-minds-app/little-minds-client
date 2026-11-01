'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';

type ChildProfile = { child_id: string; nickname: string | null; age_months: number; preferred_locale: string };
type SaveMode = { kind: 'new' } | { kind: 'edit'; child: ChildProfile };
function todayLocal(): string {
  const d = new Date();
  return [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join('-');
}

export default function ChildrenManager() {
  const [children, setChildren] = useState<ChildProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [mode, setMode] = useState<SaveMode | null>(null);
  const [nickname, setNickname] = useState('');
  const [age, setAge] = useState('32');

  const load = useCallback(async (signal?: AbortSignal) => {
    setLoading(true);
    setError(null);
    try {
      const result = await fetch('/api/children', { cache: 'no-store', signal });
      if (result.status === 401) {
        setChildren([]); setSelected(null);
        throw new Error('Oturum sona erdi. Yeniden giriş yapın.');
      }
      if (!result.ok) throw new Error('Profiller yüklenemedi. Yeniden deneyin.');
      const data: { children?: ChildProfile[] } = await result.json();
      setChildren(Array.isArray(data.children) ? data.children : []);
      setSelected((previous) => (data.children ?? []).some((child) => child.child_id === previous) ? previous : null);
    } catch (caught) {
      if (signal?.aborted) return;
      setError(caught instanceof Error ? caught.message : 'Beklenmeyen hata');
    } finally {
      if (!signal?.aborted) setLoading(false);
    }
  }, []);
  useEffect(() => {
    const controller = new AbortController();
    void load(controller.signal);
    return () => controller.abort();
  }, [load]);

  function openForm(next: SaveMode) {
    setError(null);
    setMode(next);
    setNickname(next.kind === 'edit' ? (next.child.nickname ?? '') : '');
    setAge(String(next.kind === 'edit' ? next.child.age_months : 32));
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!mode || busy) return;
    const months = Number(age);
    if (!Number.isInteger(months) || months < 0 || months > 2147483647 || nickname.length > 80) {
      setError('Geçerli bir ay yaşı ve en fazla 80 karakterlik takma ad girin.');
      return;
    }
    setBusy(true);
    setError(null);
    const creating = mode.kind === 'new';
    try {
      const response = await fetch(
        creating ? '/api/children' : '/api/children/' + encodeURIComponent(mode.child.child_id),
        {
          method: creating ? 'POST' : 'PATCH',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ age_months: months, reference_date: todayLocal(), nickname: nickname || (creating ? undefined : null) }),
        },
      );
      if (response.status === 401) {
        setChildren([]); setSelected(null);
        throw new Error('Oturum sona erdi. Yeniden giriş yapın.');
      }
      if (!response.ok) throw new Error(response.status === 400 ? 'Bilgileri kontrol edin.' : 'Kaydedilemedi. Yeniden deneyin.');
      setMode(null);
      await load();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Kaydetme hatası');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section aria-label="Çocuk profilleri" style={{ maxWidth: 640, margin: '2rem auto', padding: '1rem' }}>
      <h2>Çocuk profilleri</h2>
      <p>Kesin doğum tarihi gerekmez. Yaşı ay olarak yaklaşık girin.</p>
      {loading && <p role="status">Profiller yükleniyor…</p>}
      {error && <p role="alert">{error} <button type="button" onClick={() => void load()}>Yeniden dene</button></p>}
      {!loading && children.length === 0 && <p>Henüz çocuk profili bulunmuyor.</p>}
      <ul style={{ listStyle: 'none', padding: 0 }}>
        {children.map((child) => (
          <li key={child.child_id} style={{ border: '1px solid #aaa', borderRadius: 8, padding: 12, marginBottom: 8 }}>
            <strong>{child.nickname || 'İsimsiz profil'}</strong> — {child.age_months} ay
            <div>
              <button type="button" aria-pressed={selected === child.child_id} onClick={() => setSelected(child.child_id)}>
                {selected === child.child_id ? 'Seçili profil' : 'Seç'}
              </button>{' '}
              <button type="button" onClick={() => openForm({ kind: 'edit', child })}>Düzenle</button>
            </div>
          </li>
        ))}
      </ul>
      <button type="button" onClick={() => openForm({ kind: 'new' })}>Yeni profil oluştur</button>
      {mode && (
        <form onSubmit={(event) => void save(event)} style={{ marginTop: 16 }}>
          <h3>{mode.kind === 'new' ? 'Profil oluştur' : 'Profili düzenle'}</h3>
          <label>Takma ad (isteğe bağlı)
            <input value={nickname} maxLength={80} onChange={(event) => setNickname(event.target.value)} />
          </label>
          <label>Yaklaşık yaş (ay)
            <input type="number" min={0} max={2147483647} required value={age} onChange={(event) => setAge(event.target.value)} />
          </label>
          <div><button type="submit" disabled={busy}>{busy ? 'Kaydediliyor…' : 'Kaydet'}</button>{' '}
            <button type="button" disabled={busy} onClick={() => setMode(null)}>İptal</button></div>
        </form>
      )}
      {selected && <p aria-live="polite">Aktif seçim: {children.find((child) => child.child_id === selected)?.nickname || 'İsimsiz profil'}</p>}
    </section>
  );
}

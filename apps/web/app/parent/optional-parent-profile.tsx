'use client';
import React, { useCallback, useEffect, useRef, useState } from 'react';

type Profile = {
  first_name: string | null; last_name: string | null;
  age_band_optional: string | null; gender_optional: string | null;
  number_of_children_optional: number | null; occupation_optional: string | null;
};
const empty: Profile = {
  first_name: null, last_name: null, age_band_optional: null, gender_optional: null,
  number_of_children_optional: null, occupation_optional: null,
};
const ageBands = [
  ['18-24', '18–24'], ['25-34', '25–34'], ['35-44', '35–44'],
  ['45-54', '45–54'], ['55+', '55+'], ['prefer_not_to_say', 'Belirtmek istemiyorum'],
];
const genders = [
  ['woman', 'Kadın'], ['man', 'Erkek'], ['non_binary', 'İkili olmayan'],
  ['self_describe', 'Kendim tanımlıyorum'], ['prefer_not_to_say', 'Belirtmek istemiyorum'],
];
const occupations = [
  ['education', 'Eğitim'], ['healthcare', 'Sağlık'], ['technology', 'Teknoloji'],
  ['finance_business', 'Finans ve iş dünyası'], ['public_service', 'Kamu'],
  ['retail_services', 'Perakende ve hizmet'], ['manufacturing_trades', 'Üretim ve zanaat'],
  ['creative_media', 'Yaratıcı işler ve medya'], ['homemaker_caregiver', 'Ev ve bakım işleri'],
  ['student', 'Öğrenci'], ['retired', 'Emekli'], ['not_currently_employed', 'Şu an çalışmıyorum'],
  ['other', 'Diğer'], ['prefer_not_to_say', 'Belirtmek istemiyorum'],
];
export function OptionalParentProfile() {
  const [form, setForm] = useState<Profile>(empty);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');
  const generation = useRef(0);

  const reload = useCallback(async () => {
    const current = ++generation.current;
    setLoading(true); setError(''); setInfo(''); setForm(empty);
    try {
      const me = await fetch('/api/auth/me', { cache: 'no-store' });
      if (!me.ok) throw new Error('Ebeveyn oturumu doğrulanamadı.');
      const identity = await me.json() as { parent_id?: string };
      if (!identity.parent_id) throw new Error('Geçersiz oturum.');
      const response = await fetch('/api/parent-profile', { cache: 'no-store' });
      if (!response.ok) throw new Error('Profil yüklenemedi.');
      const result = await response.json() as Profile;
      const again = await fetch('/api/auth/me', { cache: 'no-store' });
      const check = again.ok ? await again.json() as { parent_id?: string } : {};
      if (current !== generation.current) return;
      if (check.parent_id !== identity.parent_id) throw new Error('Oturum değişti; yeniden deneyin.');
      setForm(result);
    } catch (caught) {
      if (current === generation.current) setError(caught instanceof Error ? caught.message : 'Bağlantı hatası');
    } finally {
      if (current === generation.current) setLoading(false);
    }
  }, []);
  useEffect(() => { void reload(); return () => { generation.current++; }; }, [reload]);

  const update = (key: keyof Profile, value: string | number | null) =>
    setForm((current) => ({ ...current, [key]: value }));
  async function persist(method: 'PATCH' | 'DELETE') {
    if (saving) return;
    setSaving(true); setError(''); setInfo('');
    try {
      const response = await fetch('/api/parent-profile', {
        method,
        headers: { 'content-type': 'application/json' },
        ...(method === 'PATCH' ? { body: JSON.stringify(form) } : {}),
      });
      if (!response.ok) throw new Error(response.status === 401
        ? 'Oturum sona erdi.' : 'İşlem tamamlanamadı.');
      setForm(await response.json() as Profile);
      setInfo(method === 'DELETE' ? 'İsteğe bağlı bilgiler temizlendi.' : 'Profil kaydedildi.');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Kaydetme hatası');
    } finally { setSaving(false); }
  }
  if (loading) return <section aria-label="Ebeveyn profili"><p role="status">Profil yükleniyor…</p></section>;
  return <section aria-label="Ebeveyn profili">
    <h2>Ebeveyn profili (isteğe bağlı)</h2>
    <p>Bu bilgiler zorunlu değildir. Dilerseniz şimdi atlayabilir, sonra değiştirebilir veya silebilirsiniz. Analitik izni bu formdan alınmaz.</p>
    {error && <p role="alert">{error} <button type="button" onClick={() => void reload()}>Yeniden dene</button></p>}
    {info && <p role="status">{info}</p>}
    <form onSubmit={(event) => { event.preventDefault(); void persist('PATCH'); }}>
      <label>Ad <input maxLength={100} value={form.first_name ?? ''} onChange={(event) => update('first_name', event.target.value || null)} /></label>
      <label>Soyad <input maxLength={100} value={form.last_name ?? ''} onChange={(event) => update('last_name', event.target.value || null)} /></label>
      {([
        ['age_band_optional', 'Yaş aralığı', ageBands],
        ['gender_optional', 'Cinsiyet (isteğe bağlı)', genders],
        ['occupation_optional', 'Çalışma alanınız / mesleki durumunuz', occupations],
      ] as const).map(([key, title, options]) =>
        <label key={key}>{title}
          <select value={form[key] ?? ''} onChange={(event) => update(key, event.target.value || null)}>
            <option value="">Şimdi değil / boş bırak</option>
            {options.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
        </label>)}
      <label>Çocuk sayısı (isteğe bağlı)
        <input type="number" min={0} max={30} step={1} value={form.number_of_children_optional ?? ''}
          onChange={(event) => update('number_of_children_optional',
            event.target.value === '' ? null : Number(event.target.value))} />
      </label>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, paddingTop: 12 }}>
        <button type="submit" disabled={saving}>Kaydet ve devam et</button>
        <button type="button" disabled={saving} onClick={() => { setForm(empty); setInfo('Bu adımı atlayabilirsiniz.'); }}>Şimdi değil / Atla</button>
        <button type="button" disabled={saving} onClick={() => void persist('DELETE')}>Tüm isteğe bağlı bilgileri sil</button>
      </div>
    </form>
  </section>;
}

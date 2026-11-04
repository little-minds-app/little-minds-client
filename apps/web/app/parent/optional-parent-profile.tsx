'use client';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { LmButton, LmCard, LmField, LmInput, LmSelect } from './lm-ui';
import { ParentFeedback } from './parent-feedback';

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
  const loadedParent = useRef<string | null>(null);

  const reload = useCallback(async () => {
    const current = ++generation.current;
    loadedParent.current = null;
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
      loadedParent.current = identity.parent_id;
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
    if (saving || loading) return;
    const expected = loadedParent.current;
    const current = generation.current;
    if (!expected) {
      setError('Oturum doğrulanamadı. Yeniden deneyin.');
      return;
    }
    setSaving(true); setError(''); setInfo('');
    try {
      const me = await fetch('/api/auth/me', { cache: 'no-store' });
      const identity = me.ok ? await me.json() as { parent_id?: string } : {};
      if (current !== generation.current) return;
      if (identity.parent_id !== expected) {
        loadedParent.current = null;
        setForm(empty);
        throw new Error('Ebeveyn oturumu değişti. Profili yeniden yükleyin.');
      }
      const response = await fetch('/api/parent-profile', {
        method,
        headers: {
          'content-type': 'application/json',
          'x-lm-expected-parent-id': expected,
        },
        ...(method === 'PATCH' ? { body: JSON.stringify(form) } : {}),
      });
      if (current !== generation.current) return;
      if (response.status === 409 || response.status === 401) {
        loadedParent.current = null;
        setForm(empty);
        throw new Error('Ebeveyn oturumu değişti veya sona erdi. Yeniden yükleyin.');
      }
      if (!response.ok) throw new Error('İşlem tamamlanamadı.');
      const saved = await response.json() as Profile;
      const after = await fetch('/api/auth/me', { cache: 'no-store' });
      const verified = after.ok ? await after.json() as { parent_id?: string } : {};
      if (current !== generation.current) return;
      if (verified.parent_id !== expected) {
        loadedParent.current = null;
        setForm(empty);
        throw new Error('Oturum değişti. Profili yeniden yükleyin.');
      }
      setForm(saved);
      setInfo(method === 'DELETE' ? 'İsteğe bağlı bilgiler temizlendi.' : 'Profil kaydedildi.');
    } catch (caught) {
      if (current === generation.current) {
        setError(caught instanceof Error ? caught.message : 'Kaydetme hatası');
      }
    } finally {
      if (current === generation.current) setSaving(false);
    }
  }

  if (loading) {
    return (
      <LmCard title="Ebeveyn profili (isteğe bağlı)" subtitle="Zorunlu değil">
        <p role="status">Profil yükleniyor…</p>
      </LmCard>
    );
  }
  return (
    <LmCard title="Ebeveyn profili (isteğe bağlı)" subtitle="Analitik izni bu formdan alınmaz.">
      <p className="lm-field__hint">Bu bilgiler zorunlu değildir. Dilerseniz şimdi atlayabilir, sonra değiştirebilir veya silebilirsiniz.</p>
      {error && <ParentFeedback kind="error" title="Profil hatası" message={error} onRetry={() => void reload()} retryLabel="Yeniden dene" />}
      {info && <ParentFeedback kind="success" title="Profil" message={info} />}
      <form className="lm-form" onSubmit={(event) => { event.preventDefault(); void persist('PATCH'); }}>
        <LmField label="Ad" htmlFor="parent-first-name">
          <LmInput id="parent-first-name" maxLength={100} value={form.first_name ?? ''} onChange={(event) => update('first_name', event.target.value || null)} />
        </LmField>
        <LmField label="Soyad" htmlFor="parent-last-name">
          <LmInput id="parent-last-name" maxLength={100} value={form.last_name ?? ''} onChange={(event) => update('last_name', event.target.value || null)} />
        </LmField>
        {([
          ['age_band_optional', 'Yaş aralığı', ageBands],
          ['gender_optional', 'Cinsiyet (isteğe bağlı)', genders],
          ['occupation_optional', 'Çalışma alanınız / mesleki durumunuz', occupations],
        ] as const).map(([key, title, options]) => (
          <LmField key={key} label={title} htmlFor={`parent-${key}`}>
            <LmSelect id={`parent-${key}`} value={form[key] ?? ''} onChange={(event) => update(key, event.target.value || null)}>
              <option value="">Şimdi değil / boş bırak</option>
              {options.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </LmSelect>
          </LmField>
        ))}
        <LmField label="Çocuk sayısı (isteğe bağlı)" htmlFor="parent-children-count">
          <LmInput
            id="parent-children-count"
            type="number"
            min={0}
            max={30}
            step={1}
            value={form.number_of_children_optional ?? ''}
            onChange={(event) => update('number_of_children_optional', event.target.value === '' ? null : Number(event.target.value))}
          />
        </LmField>
        <div className="child-profile-actions">
          <LmButton type="submit" disabled={saving}>Kaydet ve devam et</LmButton>
          <LmButton type="button" variant="secondary" disabled={saving} onClick={() => { setInfo('Bu adımı atlayabilirsiniz.'); }}>Şimdi değil / Atla</LmButton>
          <LmButton type="button" variant="ghost" disabled={saving} onClick={() => void persist('DELETE')}>Tüm isteğe bağlı bilgileri sil</LmButton>
        </div>
      </form>
    </LmCard>
  );
}

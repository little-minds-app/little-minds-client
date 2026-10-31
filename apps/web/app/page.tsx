'use client';
import { useEffect, useState, type FormEvent } from 'react';

type State = 'loading' | 'signed_out' | 'otp' | 'checking_session' | 'signed_in';
type ErrorResponse = { error?: string; message?: string };

export default function ParentHome() {
  const [state, setState] = useState<State>('loading');
  const [phone, setPhone] = useState('');
  const [challenge, setChallenge] = useState('');
  const [code, setCode] = useState('');
  const [parentId, setParentId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function api(path: string, body?: object) {
    const response = await fetch('/api/auth/' + path, {
      method: body ? 'POST' : 'GET',
      headers: body ? { 'content-type': 'application/json' } : undefined,
      body: body ? JSON.stringify(body) : undefined,
      cache: 'no-store',
    });
    const result = (await response.json()) as Record<string, unknown> & ErrorResponse;
    if (!response.ok) throw new Error(result.message || 'İstek tamamlanamadı.');
    return result;
  }

  useEffect(() => {
    let mounted = true;
    api('me').then((result) => {
      if (!mounted) return;
      setParentId(typeof result.parent_id === 'string' ? result.parent_id : '');
      setState('signed_in');
    }).catch(() => { if (mounted) setState('signed_out'); });
    return () => { mounted = false; };
  }, []);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError('');
    try {
      if (state === 'signed_out') {
        const r = await api('start', { phone });
        if (typeof r.challenge_id !== 'string') throw new Error('OTP isteği başarısız.');
        setChallenge(r.challenge_id); setState('otp');
      } else if (state === 'otp') {
        await api('verify', { challenge_id: challenge, code });
        // OTP is consumed on success. Never offer it again if profile load fails.
        setState('checking_session'); setCode('');
        try {
          const me = await api('me');
          setParentId(typeof me.parent_id === 'string' ? me.parent_id : '');
          setState('signed_in');
        } catch {
          setError('Giriş başarılı, ancak profil yüklenemedi. Tekrar kontrol edin.');
        }
      }
    } catch (e) { setError(e instanceof Error ? e.message : 'Beklenmeyen hata.'); }
    finally { setBusy(false); }
  }

  async function logout() {
    setBusy(true); setError('');
    try { await apiPostLogout(); }
    catch { setError('Sunucu çıkış onayı alınamadı. Bu cihazda oturum ekranı kapatıldı; yeniden bağlanınca çıkışı kontrol edin.'); }
    finally { setParentId(''); setState('signed_out'); setCode(''); setChallenge(''); setBusy(false); }
  }

  async function apiPostLogout() { await api('logout', {}); }

  return <main>
    <h1>Little Minds</h1><h2>Parent Web</h2>
    {state === 'loading' && <p>Oturum kontrol ediliyor…</p>}
    {state === 'checking_session' && <section><p>Oturum oluşturuldu. Profil yüklenemedi.</p><button type="button" disabled={busy} onClick={async () => { setBusy(true); setError(''); try { const me = await api('me'); setParentId(typeof me.parent_id === 'string' ? me.parent_id : ''); setState('signed_in'); } catch { setError('Profil şu anda yüklenemiyor.'); } finally { setBusy(false); } }}>Profili yeniden kontrol et</button><button type="button" disabled={busy} onClick={logout}>Çıkış yap</button></section>}
    {state === 'signed_in' && <section><p>Giriş yapıldı.</p><p>Parent ID: {parentId}</p><p><a href="/parent">Ebeveyn alanına git</a></p><button type="button" disabled={busy} onClick={logout}>Çıkış yap</button></section>}
    {(state === 'signed_out' || state === 'otp') && <form onSubmit={submit}>
      {state === 'signed_out' ? <><label htmlFor="phone">Telefon (+90)</label><input id="phone" name="phone" autoComplete="tel" required value={phone} onChange={(e) => setPhone(e.target.value)} style={{ display: 'block', width: '100%', marginBottom: 16 }} /><p>Bu geliştirme sürümünde KVKK aydınlatma metni hukuk onayı beklemektedir. Giriş üretim kullanımı için etkin değildir.</p></> : <><label htmlFor="code">6 haneli SMS kodu</label><input id="code" name="code" inputMode="numeric" maxLength={6} pattern="[0-9]{6}" required value={code} onChange={(e) => setCode(e.target.value)} style={{ display: 'block', marginBottom: 16 }} /></>}
      <button type="submit" disabled={busy}>{busy ? 'İşleniyor…' : state === 'otp' ? 'Doğrula' : 'Kod gönder'}</button>
      {state === 'otp' && <button type="button" disabled={busy} onClick={() => { setCode(''); setState('signed_out'); }}>Geri</button>}
    </form>}
    {error && <p role="alert">{error}</p>}
  </main>;
}

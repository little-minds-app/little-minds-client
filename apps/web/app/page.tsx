'use client';
import { useEffect, useState, type FormEvent } from 'react';
import Link from 'next/link';
import { LmButton, LmCard, LmField, LmInput } from './parent/lm-ui';
import { ParentFeedback } from './parent/parent-feedback';

type State = 'loading' | 'signed_out' | 'otp' | 'checking_session' | 'signed_in';
type ErrorResponse = { error?: string; message?: string };
type AuthFailure = Error & { code?: string; httpStatus?: number };

export default function ParentHome() {
  const [state, setState] = useState<State>('loading');
  const [phone, setPhone] = useState('');
  const [challenge, setChallenge] = useState('');
  const [code, setCode] = useState('');
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
    if (!response.ok) {
      const failure = new Error(result.message || 'İstek tamamlanamadı.') as AuthFailure;
      failure.code = result.error;
      failure.httpStatus = response.status;
      throw failure;
    }
    return result;
  }

  useEffect(() => {
    let mounted = true;
    api('me').then((result) => {
      if (!mounted) return;
      setState('signed_in');
      // Never auto-redirect: authorization failure must not create a redirect loop.
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
          setState('signed_in');
        } catch {
          setError('Giriş başarılı, ancak profil yüklenemedi. Tekrar kontrol edin.');
        }
      }
    } catch (e) {
      // Successful OTP can be consumed even when the subsequent server-only
      // session exchange fails. Never invite replay of the consumed code.
      if (state === 'otp' && (e as AuthFailure)?.code === 'web_session_exchange_failed') {
        setState('signed_out'); setChallenge(''); setCode('');
        setError('SMS kodu doğrulandı ama oturum açılamadı. Yeni kod isteyin.');
      } else {
        setError(e instanceof Error ? e.message : 'Beklenmeyen hata.');
      }
    }
    finally { setBusy(false); }
  }

  async function logout() {
    setBusy(true); setError('');
    try { await apiPostLogout(); setState('signed_out'); setCode(''); setChallenge(''); }
    catch (cause) {
      // An explicit 503 from our server means it cleared HttpOnly cookies but
      // couldn't confirm backend revocation. Network failure means cookies may remain.
      if (cause instanceof Error && cause.message === 'Server logout could not be confirmed') {
        setState('signed_out'); setCode(''); setChallenge('');
        setError('Bu tarayıcıdaki oturum kapatıldı ancak sunucu iptali doğrulanamadı.');
      } else {
        setError('Çıkış tamamlanamadı. Oturum hâlâ açık olabilir; lütfen tekrar deneyin.');
      }
    }
    finally { setBusy(false); }

  }

  async function apiPostLogout() { await api('logout', {}); }

  return <main className="shell auth-shell">
    <section className="auth-intro" aria-label="Little Minds">
      <div className="auth-intro__brand"><span className="parent-app__logo" aria-hidden="true">LM</span><span>Little Minds</span></div>
      <p className="auth-intro__eyebrow">EBEVEYN DENEYİMİ</p>
      <h1>Çocuğunuzun gelişimini birlikte keşfedelim.</h1>
      <p className="auth-intro__description">Oyun sürelerini, öğrenme etkinliklerini ve gerçek dünya görevlerini güvenli ebeveyn alanınızdan takip edin.</p>
      <ul className="auth-intro__features">
        <li><span aria-hidden="true">✓</span> Yaşa uygun oyun ve etkinlik özeti</li>
        <li><span aria-hidden="true">✓</span> Anlaşılır gelişim göstergeleri</li>
        <li><span aria-hidden="true">✓</span> Ebeveyn kontrollü güvenli erişim</li>
      </ul>
    </section>
    <section className="auth-panel" aria-label="Ebeveyn girişi">
      <LmCard title={state === 'signed_in' ? 'Tekrar hoş geldiniz' : state === 'otp' ? 'Telefonunuzu doğrulayın' : 'Ebeveyn girişi'} subtitle={state === 'signed_in' ? 'Ebeveyn paneliniz hazır.' : 'Telefon numaranızla güvenle devam edin.'}>
        {state === 'loading' && <p role="status" className="auth-panel__status">Oturum kontrol ediliyor…</p>}
        {state === 'checking_session' && <div className="auth-panel__actions">
          <ParentFeedback kind="warning" title="Oturum kontrolü" message="Oturum oluşturuldu ancak profil doğrulaması tamamlanamadı." />
          <LmButton disabled={busy} onClick={async () => { setBusy(true); setError(''); try { await api('me'); setState('signed_in'); } catch { setError('Profil şu anda yüklenemiyor.'); } finally { setBusy(false); } }}>Profili yeniden kontrol et</LmButton>
          <LmButton variant="secondary" disabled={busy} onClick={logout}>Çıkış yap</LmButton>
        </div>}
        {state === 'signed_in' && <div className="auth-panel__actions">
          <ParentFeedback kind="success" title="Giriş başarılı" message="Oturumunuz doğrulandı. Çocuğunuzun oyun ve görev özetine geçebilirsiniz." />
          <Link className="lm-btn lm-btn--primary auth-panel__link" href="/parent" onClick={async (event) => { if (!event.nativeEvent.isTrusted) { event.preventDefault(); return; } event.preventDefault(); try { await api('activity', {}); window.location.assign('/parent'); } catch { setError('Oturum doğrulanamadı. Lütfen yeniden deneyin.'); } }}>Ebeveyn paneline git</Link>
          <LmButton variant="secondary" disabled={busy} onClick={logout}>Çıkış yap</LmButton>
        </div>}
        {(state === 'signed_out' || state === 'otp') && <form className="lm-form auth-panel__form" onSubmit={submit}>
          {state === 'signed_out' ? <>
            <LmField label="Telefon numarası (+90)" htmlFor="phone" hint="SMS doğrulama kodu bu numaraya gönderilir.">
              <LmInput id="phone" name="phone" type="tel" autoComplete="tel" inputMode="tel" required value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="5XX XXX XX XX" />
            </LmField>
            <p className="auth-panel__legal">Bu geliştirme sürümünde KVKK aydınlatma metni hukuk onayı beklemektedir. Giriş üretim kullanımı için etkin değildir.</p>
          </> : <>
            <LmField label="6 haneli SMS kodu" htmlFor="code" hint="Telefonunuza gelen altı haneli kodu girin.">
              <LmInput id="code" name="code" inputMode="numeric" autoComplete="one-time-code" maxLength={6} pattern="[0-9]{6}" required value={code} onChange={(e) => setCode(e.target.value)} placeholder="••••••" />
            </LmField>
          </>}
          <div className="auth-panel__actions">
            <LmButton type="submit" disabled={busy}>{busy ? 'İşleniyor…' : state === 'otp' ? 'Doğrula ve devam et' : 'Doğrulama kodu gönder'}</LmButton>
            {state === 'otp' && <LmButton variant="ghost" disabled={busy} onClick={() => { setCode(''); setState('signed_out'); }}>Numarayı değiştir</LmButton>}
          </div>
        </form>}
        {error && <ParentFeedback kind="error" title="İşlem tamamlanamadı" message={error} />}
      </LmCard>
      <p className="auth-panel__footnote">Little Minds · Ebeveynlere özel güvenli alan</p>
    </section>
  </main>;
}

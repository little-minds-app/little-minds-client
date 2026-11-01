import ChildrenManager from './children-manager';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

/** Backend-authoritative auth on every server render; no refresh token in web. */
export default async function ProtectedParentPage() {
  const jar = await cookies();
  const cookieName = process.env.NODE_ENV === 'production' ? '__Host-lm_web_session' : 'lm_dev_web_session';
  const handle = jar.get(cookieName)?.value;
  if (!handle) redirect('/');
  let response: Response;
  try {
    response = await fetch(new URL('/v1/auth/web/me', process.env.LM_API_BASE_URL ?? 'http://127.0.0.1:3001'), {
      headers: { 'x-lm-web-session': handle },
      cache: 'no-store',
      signal: AbortSignal.timeout(8000),
    });
  } catch { return <main><h1>Servise ulaşılamıyor</h1><p>Oturumunuz korunuyor. Daha sonra yeniden deneyin.</p><a href="/parent">Yeniden dene</a></main>; }
  if (response.status === 401 || response.status === 403) redirect('/');
  if (!response.ok) return <main><h1>Servis geçici olarak kullanılamıyor</h1><p>Oturumunuz kapatılmadı.</p><a href="/parent">Yeniden dene</a></main>;
  const parent = await response.json() as { parent_id?: string };
  return <main><h1>Ebeveyn alanı</h1><p>Oturum doğrulandı.</p><p>Parent: {parent.parent_id ?? 'Aktif'}</p><ChildrenManager/><a href='/'>Ana sayfaya dön</a></main>;
}

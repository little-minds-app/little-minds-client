import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

export default async function ProtectedParentPage() {
  const jar = await cookies();
  const access = jar.get('lm_parent_access')?.value;
  if (!access) redirect(jar.get('lm_parent_refresh') ? '/?continue=parent' : '/');
  let response: Response;
  try {
    response = await fetch(new URL('/v1/parent/me', process.env.LM_API_BASE_URL ?? 'http://127.0.0.1:3000'), {
      headers: { authorization: 'Bearer ' + access },
      cache: 'no-store',
      signal: AbortSignal.timeout(8000),
    });
  } catch { redirect('/'); }
  if (!response.ok) redirect(response.status === 401 && jar.get('lm_parent_refresh') ? '/?continue=parent' : '/');
  const parent = await response.json() as { parent_id?: string };
  return <main><h1>Ebeveyn alanı</h1><p>Oturum doğrulandı.</p><p>Parent: {parent.parent_id ?? 'Aktif'}</p><a href='/'>Ana sayfaya dön</a></main>;
}

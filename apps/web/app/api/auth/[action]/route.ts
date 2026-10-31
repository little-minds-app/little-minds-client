import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const WEB_COOKIE = process.env.NODE_ENV === 'production' ? '__Host-lm_web_session' : 'lm_dev_web_session';
const OLD_ACCESS_COOKIE = 'lm_parent_access';
const OLD_REFRESH_COOKIE = 'lm_parent_refresh';
const BACKEND = process.env.LM_API_BASE_URL ?? 'http://127.0.0.1:3001';

function cookieOptions() {
  return { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict' as const, path: '/' };
}
function clear(response: NextResponse) {
  response.cookies.set(WEB_COOKIE, '', { ...cookieOptions(), maxAge: 0 });
  response.cookies.set(OLD_ACCESS_COOKIE, '', { ...cookieOptions(), maxAge: 0 });
  response.cookies.set(OLD_REFRESH_COOKIE, '', { ...cookieOptions(), maxAge: 0 });
}
function json(payload: unknown, status = 200) {
  return NextResponse.json(payload, { status, headers: { 'cache-control': 'no-store' } });
}
function originAllowed(request: NextRequest) {
  const origin = request.headers.get('origin');
  if (!origin) return false;
  try {
    const parsed = new URL(origin);
    // Behind a reverse proxy NextRequest.nextUrl.origin may normalize to localhost;
    // the client-facing Host and scheme remain authoritative for same-origin POST.
    return parsed.host === request.headers.get('host') &&
      parsed.protocol === (request.headers.get('x-forwarded-proto') ?? request.nextUrl.protocol.replace(':', '')) + ':';
  } catch { return false; }
}
type BackendResult = { status: number; data: Record<string, unknown> };
async function backend(path: string, opts: { body?: object; bearer?: string; handle?: string } = {}): Promise<BackendResult> {
  try {
    const response = await fetch(new URL(path, BACKEND), {
      method: opts.body === undefined ? 'GET' : 'POST',
      headers: {
        ...(opts.body !== undefined ? { 'content-type': 'application/json' } : {}),
        ...(opts.bearer ? { authorization: 'Bearer ' + opts.bearer } : {}),
        ...(opts.handle ? { 'x-lm-web-session': opts.handle } : {}),
      },
      body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
      cache: 'no-store',
      signal: AbortSignal.timeout(8000),
    });
    const data = response.status === 204 ? {} : await response.json().catch(() => ({}));
    return { status: response.status, data: data && typeof data === 'object' ? data : {} };
  } catch {
    return { status: 503, data: { error: 'backend_unavailable', message: 'Service temporarily unavailable' } };
  }
}
function error(result: BackendResult) {
  const message = typeof result.data.message === 'string' ? result.data.message : 'Authentication failed';
  const code = typeof result.data.error === 'string' ? result.data.error : 'invalid_request';
  return json({ error: code, message }, result.status);
}
export async function POST(request: NextRequest, context: { params: Promise<{ action: string }> }) {
  if (!originAllowed(request)) return json({ error: 'invalid_request', message: 'Invalid origin' }, 403);
  if (!request.headers.get('content-type')?.startsWith('application/json')) return json({ error: 'invalid_request' }, 415);
  const { action } = await context.params;
  if (!['start', 'verify', 'logout'].includes(action)) return json({ error: 'not_found' }, 404);
  const body = await request.json().catch(() => null);
  if (!body || typeof body !== 'object' || Array.isArray(body)) return json({ error: 'invalid_request' }, 400);
  if (action === 'start') {
    if (typeof body.phone !== 'string') return json({ error: 'invalid_request' }, 400);
    const result = await backend('/v1/auth/phone/start', {
      body: { phone: body.phone, notice_version: 'v1-tr-2026-10', notice_locale: 'tr-TR', client_surface: 'web' },
    });
    return result.status === 200 ? json(result.data) : error(result);
  }
  if (action === 'verify') {
    if (typeof body.challenge_id !== 'string' || typeof body.code !== 'string') return json({ error: 'invalid_request' }, 400);
    const verified = await backend('/v1/auth/phone/verify', {
      body: { challenge_id: body.challenge_id, code: body.code, client_surface: 'web' },
    });
    if (verified.status !== 200) return error(verified);
    // JWT/refresh-token pair stays within trusted Next.js and backend servers.
    const token = verified.data.access_token;
    if (typeof token !== 'string') return json({ error: 'invalid_token' }, 502);
    const exchanged = await backend('/v1/auth/web/session', { body: {}, bearer: token });
    if (exchanged.status !== 201) return error(exchanged);
    const handle = exchanged.data.handle;
    const expiry = exchanged.data.expires_at;
    if (typeof handle !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(handle) ||
        typeof expiry !== 'string') return json({ error: 'invalid_token' }, 502);
    const maxAge = Math.floor((Date.parse(expiry) - Date.now()) / 1000);
    if (!Number.isFinite(maxAge) || maxAge <= 0) return json({ error: 'invalid_token' }, 502);
    const response = json({ signed_in: true });
    clear(response); // remove legacy credential cookies
    response.cookies.set(WEB_COOKIE, handle, { ...cookieOptions(), maxAge });
    return response;
  }
  const handle = request.cookies.get(WEB_COOKIE)?.value;
  const result = handle ? await backend('/v1/auth/web/logout', { body: {}, handle }) : { status: 204, data: {} };
  const success = result.status === 204 || result.status === 200;
  const response = success ? json({ signed_out: true }) :
    json({ error: 'logout_unconfirmed', message: 'Server logout could not be confirmed' }, 503);
  clear(response);
  return response;
}
export async function GET(request: NextRequest, context: { params: Promise<{ action: string }> }) {
  if ((await context.params).action !== 'me') return json({ error: 'not_found' }, 404);
  const handle = request.cookies.get(WEB_COOKIE)?.value;
  if (!handle) return json({ error: 'invalid_token' }, 401);
  const result = await backend('/v1/auth/web/me', { handle });
  if (result.status === 200) return json(result.data);
  const response = error(result);
  if (result.status === 401) clear(response);
  return response;
}

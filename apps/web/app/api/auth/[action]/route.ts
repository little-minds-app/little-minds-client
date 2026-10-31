import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const ACCESS_COOKIE = 'lm_parent_access';
const REFRESH_COOKIE = 'lm_parent_refresh';
const COOKIE_PATH = '/';
const BACKEND = process.env.LM_API_BASE_URL ?? 'http://127.0.0.1:3000';

function options() {
  return { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict' as const, path: COOKIE_PATH };
}
function clear(response: NextResponse) {
  response.cookies.set(ACCESS_COOKIE, '', { ...options(), maxAge: 0 });
  response.cookies.set(REFRESH_COOKIE, '', { ...options(), maxAge: 0 });
}
function save(response: NextResponse, tokens: Record<string, unknown>) {
  if (typeof tokens.access_token !== 'string' || typeof tokens.refresh_token !== 'string') {
    throw new Error('Invalid token response');
  }
  const age = typeof tokens.expires_in === 'number' ? tokens.expires_in : 900;
  response.cookies.set(ACCESS_COOKIE, tokens.access_token, { ...options(), maxAge: age });
  response.cookies.set(REFRESH_COOKIE, tokens.refresh_token, { ...options() });
}
function json(payload: unknown, status = 200) { return NextResponse.json(payload, { status, headers: { 'cache-control': 'no-store' } }); }
function originAllowed(request: NextRequest) {
  const origin = request.headers.get('origin');
  return !!origin && origin === request.nextUrl.origin;
}
async function backend(path: string, body?: unknown, bearer?: string) {
  try {
    const response = await fetch(new URL(path, BACKEND), {
      method: body === undefined ? 'GET' : 'POST',
      headers: {
        ...(body === undefined ? {} : { 'content-type': 'application/json' }),
        ...(bearer ? { authorization: 'Bearer ' + bearer } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      cache: 'no-store',
      signal: AbortSignal.timeout(8_000),
    });
    const data = response.status === 204 ? {} : await response.json().catch(() => ({}));
    return { status: response.status, data };
  } catch {
    return { status: 503, data: { error: 'backend_unavailable', message: 'Service temporarily unavailable' } };
  }
}
function error(result: { status: number; data: unknown }) {
  const value = result.data as Record<string, unknown>;
  const message = typeof value?.message === 'string' ? value.message : 'Authentication failed';
  const code = typeof value?.error === 'string' ? value.error : 'invalid_request';
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
      phone: body.phone,
      notice_version: 'v1-tr-2026-10',
      notice_locale: 'tr-TR',
      client_surface: 'web',
    });
    return result.status === 200 ? json(result.data) : error(result);
  }
  if (action === 'verify') {
    if (typeof body.challenge_id !== 'string' || typeof body.code !== 'string') return json({ error: 'invalid_request' }, 400);
    const result = await backend('/v1/auth/phone/verify', {
      challenge_id: body.challenge_id,
      code: body.code,
      client_surface: 'web',
    });
    if (result.status !== 200) return error(result);
    try {
      const response = json({ signed_in: true });
      save(response, result.data as Record<string, unknown>);
      return response;
    } catch { return json({ error: 'invalid_request' }, 502); }
  }
  const token = request.cookies.get(REFRESH_COOKIE)?.value;
  if (token) await backend('/v1/auth/logout', { refresh_token: token });
  const response = json({ signed_out: true });
  clear(response);
  return response;
}

export async function GET(request: NextRequest, context: { params: Promise<{ action: string }> }) {
  if ((await context.params).action !== 'me') return json({ error: 'not_found' }, 404);
  const access = request.cookies.get(ACCESS_COOKIE)?.value;
  const refresh = request.cookies.get(REFRESH_COOKIE)?.value;
  if (!access && !refresh) return json({ error: 'invalid_token' }, 401);
  if (access) {
    const first = await backend('/v1/parent/me', undefined, access);
    if (first.status === 200) return json(first.data);
    if (first.status !== 401) return error(first);
  }
  if (!refresh) {
    const response = json({ error: 'invalid_token' }, 401);
    clear(response);
    return response;
  }
  const rotated = await backend('/v1/auth/token/refresh', { refresh_token: refresh });
  if (rotated.status !== 200) {
    const response = error(rotated);
    if (rotated.status === 401) clear(response);
    return response;
  }
  const tokens = rotated.data as Record<string, unknown>;
  if (typeof tokens.access_token !== 'string') return json({ error: 'invalid_token' }, 502);
  const profile = await backend('/v1/parent/me', undefined, tokens.access_token);
  if (profile.status !== 200) return error(profile);
  const response = json(profile.data);
  save(response, tokens);
  return response;
}

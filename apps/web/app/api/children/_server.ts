import { NextRequest, NextResponse } from 'next/server';

const COOKIE = process.env.NODE_ENV === 'production' ? '__Host-lm_web_session' : 'lm_dev_web_session';
const BACKEND = process.env.LM_API_BASE_URL ?? 'http://127.0.0.1:3001';

function response(body: unknown, status: number): NextResponse {
  return NextResponse.json(body, { status, headers: { 'cache-control': 'no-store' } });
}

function allowedOrigin(request: NextRequest): boolean {
  const origin = request.headers.get('origin');
  if (!origin) return false;
  try {
    const parsed = new URL(origin);
    const protocol = (request.headers.get('x-forwarded-proto') ??
      request.nextUrl.protocol.replace(':', '')) + ':';
    return parsed.protocol === protocol && parsed.host === request.headers.get('host');
  } catch { return false; }
}

function invalidPayload(body: unknown, partial: boolean): boolean {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) return true;
  const data = body as Record<string, unknown>;
  const keys = Object.keys(data);
  if (keys.length === 0 || keys.some((key) => !['age_months', 'reference_date', 'nickname', 'timezone'].includes(key))) return true;
  if (!partial && (!keys.includes('age_months') || !keys.includes('reference_date'))) return true;
  if (data.age_months !== undefined && (!Number.isInteger(data.age_months) ||
      typeof data.age_months !== 'number' || data.age_months < 0 || data.age_months > 2147483647)) return true;
  if (data.reference_date !== undefined) {
    if (typeof data.reference_date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(data.reference_date)) return true;
    const parsed = new Date(data.reference_date + 'T00:00:00.000Z');
    if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== data.reference_date) return true;
  }
  if (data.nickname !== undefined &&
    !(partial && data.nickname === null) &&
    (typeof data.nickname !== 'string' || data.nickname.length > 80)) return true;
  if (data.timezone !== undefined) {
    if (typeof data.timezone !== 'string') return true;
    try { new Intl.DateTimeFormat('en-US', { timeZone: data.timezone }); }
    catch { return true; }
  }
  return false;
}

export async function childrenProxy(request: NextRequest, method: 'GET' | 'POST' | 'PATCH', childId?: string): Promise<NextResponse> {
  if (method !== 'GET') {
    if (!allowedOrigin(request)) return response({ error: 'invalid_request', message: 'Invalid origin' }, 403);
    if (!request.headers.get('content-type')?.startsWith('application/json')) return response({ error: 'invalid_request' }, 415);
  }
  if (childId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(childId)) {
    return response({ error: 'not_found' }, 404);
  }
  const handle = request.cookies.get(COOKIE)?.value;
  if (!handle) return response({ error: 'invalid_token' }, 401);
  const secret = process.env.LM_WEB_BFF_SECRET;
  if (!secret || secret.length < 32 || secret.includes('CHANGE_ME')) {
    return response({ error: 'backend_unavailable' }, 503);
  }
  let body: Record<string, unknown> | undefined;
  if (method !== 'GET') {
    const raw = await request.json().catch(() => null);
    if (invalidPayload(raw, method === 'PATCH')) return response({ error: 'invalid_request' }, 400);
    body = raw as Record<string, unknown>;
  }
  let upstream: Response;
  try {
    upstream = await fetch(new URL('/v1/web/children' + (childId ? '/' + childId : ''), BACKEND), {
      method,
      headers: {
        'x-lm-web-session': handle,
        'x-lm-bff-secret': secret,
        ...(body ? { 'content-type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      cache: 'no-store',
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    return response({ error: 'backend_unavailable', message: 'Service temporarily unavailable' }, 503);
  }
  const data: unknown = await upstream.json().catch(() => ({}));
  const result = response(data, upstream.status);
  if (upstream.status === 401) {
    result.cookies.set(COOKIE, '', {
      httpOnly: true, secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict', path: '/', maxAge: 0,
    });
  }
  return result;
}

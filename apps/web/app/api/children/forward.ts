import { NextRequest, NextResponse } from 'next/server';

const cookieName = process.env.NODE_ENV === 'production' ? '__Host-lm_web_session' : 'lm_dev_web_session';

function originOk(request: NextRequest) {
  const origin = request.headers.get('origin');
  if (!origin) return false;
  try {
    const url = new URL(origin);
    return url.host === request.headers.get('host') &&
      url.protocol === (request.headers.get('x-forwarded-proto') ?? request.nextUrl.protocol.replace(':', '')) + ':';
  } catch { return false; }
}
export async function forwardChildRequest(request: NextRequest, path: string, method: 'GET' | 'POST' | 'PATCH') {
  if (method !== 'GET' && !originOk(request)) return NextResponse.json({ error: 'invalid_origin' }, { status: 403 });
  const handle = request.cookies.get(cookieName)?.value;
  if (!handle) return NextResponse.json({ error: 'invalid_token' }, { status: 401 });
  const secret = process.env.LM_WEB_BFF_SECRET;
  if (!secret || secret.length < 32 || secret.includes('CHANGE_ME')) {
    return NextResponse.json({ error: 'backend_unavailable' }, { status: 503 });
  }
  let body: unknown;
  if (method !== 'GET') {
    if (!request.headers.get('content-type')?.startsWith('application/json')) {
      return NextResponse.json({ error: 'invalid_request' }, { status: 415 });
    }
    body = await request.json().catch(() => null);
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return NextResponse.json({ error: 'invalid_request' }, { status: 400 });
    }
  }
  try {
    const response = await fetch(new URL(path, process.env.LM_API_BASE_URL ?? 'http://127.0.0.1:3001'), {
      method,
      headers: {
        'x-lm-web-session': handle,
        'x-lm-bff-secret': secret,
        ...(method !== 'GET' ? { 'content-type': 'application/json' } : {}),
      },
      ...(method !== 'GET' ? { body: JSON.stringify(body) } : {}),
      cache: 'no-store',
      signal: AbortSignal.timeout(8000),
    });
    const data = await response.json().catch(() => ({}));
    const outgoing = NextResponse.json(data, { status: response.status, headers: { 'cache-control': 'no-store' } });
    if (response.status === 401) {
      outgoing.cookies.set(cookieName, '', {
        httpOnly: true, secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict', path: '/', maxAge: 0,
      });
    }
    return outgoing;
  } catch {
    return NextResponse.json({ error: 'backend_unavailable' }, { status: 503 });
  }
}


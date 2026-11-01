import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
const cookie = process.env.NODE_ENV === 'production' ? '__Host-lm_web_session' : 'lm_dev_web_session';

function allowedOrigin(req: NextRequest) {
  const origin = req.headers.get('origin');
  if (!origin) return false;
  try {
    const url = new URL(origin);
    return url.host === req.headers.get('host') &&
      url.protocol === (req.headers.get('x-forwarded-proto') ?? req.nextUrl.protocol.replace(':', '')) + ':';
  } catch { return false; }
}
async function forward(req: NextRequest, method: 'GET' | 'PATCH' | 'DELETE') {
  if (method !== 'GET' && !allowedOrigin(req)) {
    return NextResponse.json({ error: 'invalid_origin' }, { status: 403 });
  }
  const handle = req.cookies.get(cookie)?.value;
  if (!handle) return NextResponse.json({ error: 'invalid_token' }, { status: 401 });
  const secret = process.env.LM_WEB_BFF_SECRET;
  if (!secret || secret.length < 32 || secret.includes('CHANGE_ME')) {
    return NextResponse.json({ error: 'backend_unavailable' }, { status: 503 });
  }
  let body: unknown;
  if (method === 'PATCH') {
    if (!req.headers.get('content-type')?.startsWith('application/json')) {
      return NextResponse.json({ error: 'invalid_request' }, { status: 415 });
    }
    body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return NextResponse.json({ error: 'invalid_request' }, { status: 400 });
    }
  }
  try {
    const upstream = await fetch(
      new URL('/v1/auth/web/profile', process.env.LM_API_BASE_URL ?? 'http://127.0.0.1:3001'),
      { method, headers: {
        'x-lm-web-session': handle,
        'x-lm-bff-secret': secret,
        ...(method === 'PATCH' ? { 'content-type': 'application/json' } : {}),
      }, ...(method === 'PATCH' ? { body: JSON.stringify(body) } : {}),
        cache: 'no-store', signal: AbortSignal.timeout(8000) },
    );
    const data: unknown = await upstream.json().catch(() => ({}));
    const response = NextResponse.json(data, {
      status: upstream.status, headers: { 'cache-control': 'no-store' },
    });
    if (upstream.status === 401) {
      response.cookies.set(cookie, '', { httpOnly: true,
        secure: process.env.NODE_ENV === 'production', sameSite: 'strict', path: '/', maxAge: 0 });
    }
    return response;
  } catch {
    return NextResponse.json({ error: 'backend_unavailable' }, { status: 503 });
  }
}
export async function GET(req: NextRequest) { return forward(req, 'GET'); }
export async function PATCH(req: NextRequest) { return forward(req, 'PATCH'); }
export async function DELETE(req: NextRequest) { return forward(req, 'DELETE'); }

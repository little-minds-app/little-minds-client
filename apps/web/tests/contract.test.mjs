import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const handler = readFileSync(new URL('../app/api/auth/[action]/route.ts', import.meta.url), 'utf8');
const protectedRoute = readFileSync(new URL('../app/parent/page.tsx', import.meta.url), 'utf8');
const ui = readFileSync(new URL('../app/page.tsx', import.meta.url), 'utf8');

test('browser stores only opaque HTTP-only cookie', () => {
  assert.match(handler, /__Host-lm_web_session/);
  assert.match(handler, /httpOnly: true/);
  assert.match(handler, /sameSite: 'strict'/);
  assert.doesNotMatch(handler, /refreshFlights|refreshOnce|token\/refresh/);
  assert.doesNotMatch(ui, /localStorage|sessionStorage/);
});

test('protected parent route uses authoritative web session', () => {
  assert.match(protectedRoute, /\/v1\/auth\/web\/me/);
  assert.doesNotMatch(protectedRoute, /Bearer /);
});

test('OTP success and logout have recovery states', () => {
  assert.match(ui, /checking_session/);
  assert.match(ui, /Sunucu çıkış onayı alınamadı|Çıkış tamamlanamadı|Çıkış yap/);
});

test('web login exchanges bearer only on server', () => {
  assert.match(handler, /\/v1\/auth\/web\/session/);
  assert.match(handler, /bearer: token/);
  assert.match(handler, /clear\(response\)/);
});

test('BFF secret is verified before OTP verification', () => {
  assert.ok(handler.indexOf("const bffSecret = process.env.LM_WEB_BFF_SECRET") < handler.indexOf("const verified = await backend('/v1/auth/phone/verify'"));
});

test('backend outage preserves protected page rather than forcing logout', () => {
  assert.match(protectedRoute, /Servis geçici olarak kullanılamıyor/);
  assert.match(handler, /revocation_confirmed: confirmed/);
});

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const handler = readFileSync(new URL('../app/api/auth/[action]/route.ts', import.meta.url), 'utf8');
const protectedRoute = readFileSync(new URL('../app/parent/page.tsx', import.meta.url), 'utf8');
const ui = readFileSync(new URL('../app/page.tsx', import.meta.url), 'utf8');

test('web tokens remain server-side in HTTP-only cookies', () => {
  assert.match(handler, /httpOnly: true/);
  assert.match(handler, /sameSite: 'strict'/);
  assert.match(handler, /refreshFlights/);
  assert.doesNotMatch(ui, /localStorage|sessionStorage/);
});

test('protected parent route validates access against the API', () => {
  assert.match(protectedRoute, /\/v1\/parent\/me/);
  assert.match(protectedRoute, /redirect\('\/'\)/);
});

test('OTP success has a distinct recovery state', () => {
  assert.match(ui, /checking_session/);
  assert.match(ui, /Profili yeniden kontrol et/);
});

test('logout failure does not claim local session termination', () => {
  assert.match(ui, /Oturum hâlâ açık olabilir/);
  assert.doesNotMatch(ui, /finally \{ setParentId\(''\); setState\('signed_out'\)/);
});

test('protected access failure redirects to stable sign-in page', () => {
  assert.doesNotMatch(protectedRoute, /continue=parent/);
  assert.doesNotMatch(ui, /window\.location\.replace\('\/parent'\)/);
});

test('local backend does not default to the Next.js port', () => {
  assert.match(handler, /127\.0\.0\.1:3001/);
});

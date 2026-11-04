#!/usr/bin/env node
/**
 * Captures real Next.js parent UI screenshots (OTP mock backend).
 * Output: pass MEDIA_DIR env or defaults to cwd.
 */
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { createServer } from 'node:http';
import { mkdirSync } from 'node:fs';
import { createServer as createTcpServer } from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.join(__dirname, '../apps/web');
const mediaDir = process.env.MEDIA_DIR || path.join(__dirname, '../artifacts/lmp131-uat');
mkdirSync(mediaDir, { recursive: true });

async function freePort() {
  const server = createTcpServer();
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

function json(res, status, data) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(data));
}

const handle = 'A'.repeat(43);
const backend = createServer((req, res) => {
  const p = req.url?.split('?')[0];
  if (p === '/v1/auth/phone/start') return json(res, 200, { challenge_id: '00000000-0000-4000-8000-000000000001' });
  if (p === '/v1/auth/phone/verify') return json(res, 200, { access_token: 't', refresh_token: 'r' });
  if (p === '/v1/auth/web/session') return json(res, 201, { handle, expires_at: new Date(Date.now() + 3600000).toISOString() });
  if (p === '/v1/auth/web/me') return json(res, 200, { parent_id: '11111111-1111-4111-8111-111111111111' });
  if (p === '/v1/auth/web/activity') return json(res, 200, {});
  if (p === '/v1/auth/web/logout') return json(res, 204, {});
  if (p === '/v1/web/children') return json(res, 200, { children: [{ child_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', nickname: 'Demo', age_months: 32, preferred_locale: 'tr-TR' }] });
  if (p === '/v1/web/insights/session-kpis') {
    return json(res, 200, {
      definition_version: 'session-kpi-v1', source: 'server_activity_sessions', generated_at: '2026-11-03T12:00:00.000Z',
      window: { from: '2026-10-26T21:00:00.000Z', to: '2026-11-03T21:00:00.000Z', timezone: 'Europe/Istanbul', bounds: 'half_open_started_at' },
      freshness: { status: 'fresh', data_completeness: 'complete', stale_threshold_seconds: 7200 },
      sample: { eligible_sessions: 2, terminal_sessions: 2, excluded_unsupported_schema: 0, excluded_consent: 0 },
      metrics: {
        eligible_session_count: 2, completed_session_count: 1, interrupted_session_count: 1,
        abandoned_session_count: 0, in_progress_session_count: 0, total_play_duration_seconds: 240,
        distinct_play_days: 1,
        by_activity: [{ content_version_id: 'activity-alpha', session_starts: 2, completed_sessions: 1, play_duration_seconds: 240 }],
        completed_session_rate: { availability_status: 'available', value: 0.5, numerator: 1, denominator: 2 },
        first_attempt_accuracy: { availability_status: 'unavailable', numerator: 0, denominator: 0, reason_code: 'insufficient_data' },
      },
    });
  }
  if (p?.startsWith('/v1/web/children/') && p.includes('/missions')) {
    return json(res, 200, { schema_version: 'mission-status-v1', definition_version: 'mission-status-v1', generated_at: '2026-11-03T12:00:00.000Z', child_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', window: { from: '2026-10-26T21:00:00.000Z', to: '2026-11-03T21:00:00.000Z', bounds: 'half_open_recorded_at' }, pagination: { limit: 50, truncated: false }, items: [] });
  }
  if (p === '/v1/auth/web/profile') return json(res, 200, { first_name: null, last_name: null, age_band_optional: null, gender_optional: null, number_of_children_optional: null, occupation_optional: null });
  return json(res, 404, { error: 'not_found' });
});

await once(backend.listen(0, '127.0.0.1'), 'listening');
const port = await freePort();
const origin = `http://127.0.0.1:${port}`;
const web = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'start', '-p', String(port), '-H', '127.0.0.1'], {
  cwd: webRoot,
  env: { ...process.env, LM_API_BASE_URL: `http://127.0.0.1:${backend.address().port}`, LM_WEB_BFF_SECRET: 'test-only-bff-secret-32-characters-long' },
  stdio: 'ignore',
});

try {
  let started = false;
  for (let i = 0; i < 100; i++) {
    if (web.exitCode !== null) throw new Error(`Next exited ${web.exitCode}`);
    try {
      if ((await fetch(origin + '/')).status === 200) { started = true; break; }
    } catch { /* wait */ }
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.ok(started);

  const post = (action, data, cookie) => fetch(origin + '/api/auth/' + action, {
    method: 'POST',
    headers: { 'content-type': 'application/json', origin, ...(cookie ? { cookie } : {}) },
    body: JSON.stringify(data),
  });

  const { createRequire } = await import('node:module');
  const require = createRequire(import.meta.url);
  let chromium;
  try {
    ({ chromium } = require('playwright'));
  } catch {
    ({ chromium } = require('/tmp/lmp131-pw/node_modules/playwright'));
  }
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto(origin + '/', { waitUntil: 'networkidle' });
  await page.screenshot({ path: path.join(mediaDir, 'lmp-131-web-auth-signed-out-desktop.png'), fullPage: true });

  await page.getByLabel(/Telefon numarası/i).fill('+905551112233');
  await page.getByRole('button', { name: /Doğrulama kodu gönder/i }).click();
  await page.getByLabel(/6 haneli SMS kodu/i).fill('123456');
  await page.getByRole('button', { name: /Doğrula ve devam et/i }).click();
  await page.getByText(/Giriş başarılı/i).waitFor();
  await page.screenshot({ path: path.join(mediaDir, 'lmp-131-web-auth-signed-in-desktop.png'), fullPage: true });

  const verify = await post('verify', { challenge_id: '00000000-0000-4000-8000-000000000001', code: '123456' });
  const setCookies = verify.headers.getSetCookie();
  const sessionLine = setCookies.find((c) => c.includes('lm_web_session=')) ?? '';
  const [nameValue] = sessionLine.split(';');
  const [cookieName, ...rest] = nameValue.split('=');
  const cookieValue = rest.join('=');
  await context.setExtraHTTPHeaders({ cookie: `${cookieName}=${cookieValue}` });

  await page.goto(origin + '/parent', { waitUntil: 'domcontentloaded' });
  await page.getByText(/Demo · 32 ay/i).click({ timeout: 15000 });
  await page.getByText(/50% \(1\/2\)/i).waitFor({ timeout: 20000 });
  await page.screenshot({ path: path.join(mediaDir, 'lmp-131-web-dashboard-desktop.png'), fullPage: true });

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(origin + '/', { waitUntil: 'networkidle' });
  await page.screenshot({ path: path.join(mediaDir, 'lmp-131-web-auth-signed-out-mobile.png'), fullPage: true });
  await page.goto(origin + '/parent', { waitUntil: 'domcontentloaded' });
  await page.getByText(/Demo · 32 ay/i).click({ timeout: 15000 });
  await page.getByText(/50% \(1\/2\)/i).waitFor({ timeout: 20000 });
  await page.screenshot({ path: path.join(mediaDir, 'lmp-131-web-dashboard-mobile.png'), fullPage: true });

  await page.getByText(/Profil ve hesap ayarları/i).click();
  await page.screenshot({ path: path.join(mediaDir, 'lmp-131-web-profile-mobile.png'), fullPage: true });

  await browser.close();
  console.log('Saved UAT screenshots to', mediaDir);
} finally {
  web.kill('SIGTERM');
  backend.close();
}

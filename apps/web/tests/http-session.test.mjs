import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { test } from 'node:test';
import { createServer as createTcpServer } from 'node:net';

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

test('HTTP: OTP exchange, opaque cookie, concurrent profile, CSRF, revocation, protected route', { timeout: 60000 }, async () => {
  let issued = false;
  let revoked = false;
  let meCount = 0;
  let refreshCount = 0;
  let backendUnavailable = false;
  let activityCount = 0;
  let childApiCount = 0;
  let children = [];
  let profileCalls = 0;
  let parentInfo = { first_name: null, occupation_optional: null };
  const backend = createServer(async (req, res) => {
    const path = req.url;
    if (path === '/v1/auth/phone/start') return json(res, 200, { challenge_id: '00000000-0000-4000-8000-000000000001' });
    if (path === '/v1/auth/phone/verify') return json(res, 200, { access_token: 'backend-only-access', refresh_token: 'backend-only-refresh' });
    if (path === '/v1/auth/web/session') {
      assert.equal(req.headers.authorization, 'Bearer backend-only-access');
      assert.equal(req.headers['x-lm-bff-secret'], 'test-only-bff-secret-32-characters-long');
      issued = true;
      return json(res, 201, { handle, expires_at: new Date(Date.now() + 3600_000).toISOString() });
    }
    if (path === '/v1/auth/web/me') {
      meCount += 1;
      if (backendUnavailable) return json(res, 503, { error: 'backend_unavailable' });
      if (!issued || revoked || req.headers['x-lm-web-session'] !== handle) return json(res, 401, { error: 'invalid_token' });
      return json(res, 200, { parent_id: '11111111-1111-4111-8111-111111111111', locale: 'tr-TR', timezone: 'Europe/Istanbul' });
    }
    if (path === '/v1/auth/web/activity') {
      activityCount += 1;
      assert.equal(req.headers['x-lm-bff-secret'], 'test-only-bff-secret-32-characters-long');
      return json(res, 200, { parent_id: '11111111-1111-4111-8111-111111111111' });
    }
    if (path === '/v1/auth/web/logout') {
      revoked = true;
      res.writeHead(204); return res.end();
    }
    if (path === '/v1/web/children' || path?.startsWith('/v1/web/children/')) {
      childApiCount += 1;
      assert.equal(req.headers['x-lm-bff-secret'], 'test-only-bff-secret-32-characters-long');
      if (!issued || revoked || req.headers['x-lm-web-session'] !== handle) return json(res, 401, { error: 'invalid_token' });
      if (req.method === 'GET') return json(res, 200, { children });
      let raw = '';
      for await (const chunk of req) raw += chunk;
      const input = JSON.parse(raw);
      const childId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      if (req.method === 'POST') {
        children = [{ child_id: childId, nickname: input.nickname ?? null, age_months: input.age_months, preferred_locale: 'tr-TR' }];
        return json(res, 201, { child_id: childId });
      }
      if (req.method === 'PATCH' && path === '/v1/web/children/' + childId) {
        children[0] = { ...children[0], nickname: input.nickname, age_months: input.age_months };
        return json(res, 200, children[0]);
      }
      return json(res, 404, { error: 'not_found' });
    }
    if (path === '/v1/auth/web/profile') {
      profileCalls++;
      if (req.headers['x-lm-bff-secret'] !== 'test-only-bff-secret-32-characters-long') return json(res, 401, {});
      if (!issued || revoked || req.headers['x-lm-web-session'] !== handle) return json(res, 401, {});
      if (req.method === 'GET') return json(res, 200, parentInfo);
      if (req.method === 'DELETE') {
        parentInfo = { first_name: null, occupation_optional: null };
        return json(res, 200, parentInfo);
      }
      let content = '';
      for await (const piece of req) content += piece;
      parentInfo = { ...parentInfo, ...JSON.parse(content) };
      return json(res, 200, parentInfo);
    }
    if (path === '/v1/auth/token/refresh') refreshCount += 1;
    return json(res, 404, { error: 'not_found' });
  });
  backend.listen(0, '127.0.0.1');
  await once(backend, 'listening');
  const port = await freePort();
  const origin = 'http://127.0.0.1:' + port;
  const web = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'start', '-p', String(port), '-H', '127.0.0.1'], {
    cwd: process.cwd(),
    env: { ...process.env, LM_API_BASE_URL: 'http://127.0.0.1:' + backend.address().port, LM_WEB_BFF_SECRET: 'test-only-bff-secret-32-characters-long' },
    stdio: 'ignore',
  });
  try {
    let started = false;
    for (let i = 0; i < 100; i++) {
      if (web.exitCode !== null) throw new Error('Next server exited: ' + web.exitCode);
      try {
        const res = await fetch(origin + '/');
        if (res.status === 200) { started = true; break; }
      } catch { /* startup */ }
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    assert.ok(started, 'Next web server must start');
    const post = (action, data, cookie, withOrigin = true) => fetch(origin + '/api/auth/' + action, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...(withOrigin ? { origin } : {}), ...(cookie ? { cookie } : {}) },
      body: JSON.stringify(data),
    });
    assert.equal((await post('start', { phone: '+905551112233' }, undefined, false)).status, 403);
    assert.equal((await post('start', { phone: '+905551112233' })).status, 200);
    const verify = await post('verify', { challenge_id: '00000000-0000-4000-8000-000000000001', code: '123456' });
    assert.equal(verify.status, 200);
    const verifyBody = await verify.text();
    assert.doesNotMatch(verifyBody, /backend-only-access|backend-only-refresh/);
    const cookies = verify.headers.getSetCookie();
    assert.ok(cookies.some((c) => c.startsWith('__Host-lm_web_session=') || c.startsWith('lm_dev_web_session=')));
    const active = cookies.find((c) => c.includes('lm_web_session='));
    const browserCookie = active.split(';')[0];
    const profile = await Promise.all(Array.from({ length: 8 }, () => fetch(origin + '/api/auth/me', { headers: { cookie: browserCookie } })));
    assert.ok(profile.every((r) => r.status === 200));
    assert.equal(refreshCount, 0, 'browser web sessions do not rotate refresh tokens');
    assert.ok(meCount >= 8);
    assert.equal(activityCount, 0, 'passive profile polling must not touch idle timeout');
    assert.equal((await post('activity', {}, browserCookie)).status, 200);
    assert.equal(activityCount, 1);
    assert.equal((await post('activity', {}, browserCookie, false)).status, 403);
    assert.equal(activityCount, 1, 'cross-origin/CSRF activity denied');
    const protectedPage = await fetch(origin + '/parent', { headers: { cookie: browserCookie }, redirect: 'manual' });
    assert.equal(protectedPage.status, 200);
    assert.match(await protectedPage.text(), /Ebeveyn alanı/);
    const list = await fetch(origin + '/api/children', { headers: { cookie: browserCookie } });
    assert.equal(list.status, 200);
    assert.deepEqual((await list.json()).children, []);
    assert.equal((await fetch(origin + '/api/children')).status, 401, 'missing web cookie denied');
    const childPost = (data, cookie, originHeader = origin) => fetch(origin + '/api/children', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...(originHeader ? { origin: originHeader } : {}), ...(cookie ? { cookie } : {}) },
      body: JSON.stringify(data),
    });
    const data = { nickname: 'Synthetic child', age_months: 32, reference_date: '2026-11-01' };
    assert.equal((await childPost(data, browserCookie, 'https://evil.example')).status, 403, 'cross-origin creation blocked');
    assert.equal((await childPost(data, browserCookie, '')).status, 403, 'no origin blocked');
    assert.equal((await childPost(data, undefined)).status, 401, 'unauthenticated create blocked');
    const created = await childPost(data, browserCookie);
    assert.equal(created.status, 201);
    const newId = (await created.json()).child_id;
    const patch = (id) => fetch(origin + '/api/children/' + id, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', origin, cookie: browserCookie },
      body: JSON.stringify({ nickname: 'Updated', age_months: 33, reference_date: '2026-11-01' }),
    });
    const edit = await patch(newId);
    assert.equal(edit.status, 200);
    assert.equal((await edit.json()).nickname, 'Updated');
    assert.equal((await patch('not-a-uuid')).status, 404, 'invalid ID blocked at BFF');
    const after = await fetch(origin + '/api/children', { headers: { cookie: browserCookie } });
    assert.equal((await after.json()).children[0].nickname, 'Updated');
    assert.equal(childApiCount, 4, 'invalid requests never reach backend');
    assert.equal((await fetch(origin + '/api/parent-profile')).status, 401);
    const submitParent = (requestOrigin, expectedParent = '11111111-1111-4111-8111-111111111111') => fetch(origin + '/api/parent-profile', {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', origin: requestOrigin, cookie: browserCookie, 'x-lm-expected-parent-id': expectedParent },
      body: JSON.stringify({ first_name: 'Sample', occupation_optional: 'technology' }),
    });
    const initialCalls = profileCalls;
    assert.equal((await submitParent('https://invalid.example')).status, 403);
    assert.equal(profileCalls, initialCalls);
    assert.equal((await submitParent(origin, '22222222-2222-4222-8222-222222222222')).status, 409, 'wrong parent context must fail closed');
    assert.equal(profileCalls, initialCalls, 'rejected owner mismatch must not reach profile mutation');
    assert.equal((await submitParent(origin)).status, 200);
    const viewed = await fetch(origin + '/api/parent-profile', { headers: { cookie: browserCookie } });
    assert.equal((await viewed.json()).first_name, 'Sample');
    const cleared = await fetch(origin + '/api/parent-profile', {
      method: 'DELETE', headers: { origin, cookie: browserCookie, 'x-lm-expected-parent-id': '11111111-1111-4111-8111-111111111111' },
    });
    assert.equal(cleared.status, 200);
    assert.equal((await cleared.json()).first_name, null);
    backendUnavailable = true;
    const unavailable = await fetch(origin + '/parent', { headers: { cookie: browserCookie }, redirect: 'manual' });
    assert.equal(unavailable.status, 200, 'backend outage must not redirect to sign-in');
    assert.match(await unavailable.text(), /Servis geçici olarak kullanılamıyor/);
    backendUnavailable = false;
    const logout = await post('logout', {}, browserCookie);
    assert.equal(logout.status, 200);
    assert.equal((await fetch(origin + '/api/auth/me', { headers: { cookie: browserCookie } })).status, 401);
    const deniedChildren = await fetch(origin + '/api/children', { headers: { cookie: browserCookie } });
    assert.equal(deniedChildren.status, 401, 'revoked web session denies child profiles');
    assert.ok(deniedChildren.headers.getSetCookie().some((c) => c.toLowerCase().includes('max-age=0')),
      'revoked web session clears the stale browser cookie');
    assert.equal((await fetch(origin + '/parent', { headers: { cookie: browserCookie }, redirect: 'manual' })).status, 307);
  } finally {
    web.kill('SIGTERM');
    await new Promise((resolve) => backend.close(resolve));
  }
});

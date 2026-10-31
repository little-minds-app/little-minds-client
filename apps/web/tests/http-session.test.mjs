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
      if (!issued || revoked || req.headers['x-lm-web-session'] !== handle) return json(res, 401, { error: 'invalid_token' });
      return json(res, 200, { parent_id: 'parent-1', locale: 'tr-TR', timezone: 'Europe/Istanbul' });
    }
    if (path === '/v1/auth/web/logout') {
      revoked = true;
      res.writeHead(204); return res.end();
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
    const protectedPage = await fetch(origin + '/parent', { headers: { cookie: browserCookie }, redirect: 'manual' });
    assert.equal(protectedPage.status, 200);
    assert.match(await protectedPage.text(), /Ebeveyn alanı/);
    const logout = await post('logout', {}, browserCookie);
    assert.equal(logout.status, 200);
    assert.equal((await fetch(origin + '/api/auth/me', { headers: { cookie: browserCookie } })).status, 401);
    assert.equal((await fetch(origin + '/parent', { headers: { cookie: browserCookie }, redirect: 'manual' })).status, 307);
  } finally {
    web.kill('SIGTERM');
    await new Promise((resolve) => backend.close(resolve));
  }
});

import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import React from 'react';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>', { url: 'http://localhost/' });
Object.assign(globalThis, {
  window: dom.window,
  document: dom.window.document,
  HTMLElement: dom.window.HTMLElement,
  MutationObserver: dom.window.MutationObserver,
});
Object.defineProperty(globalThis, 'navigator', { configurable: true, value: dom.window.navigator });
const { cleanup, fireEvent, render, screen, waitFor } = require('@testing-library/react') as typeof import('@testing-library/react');
const { ChildProfiles, profileSaveErrorMessage } = require('../app/parent/child-profiles') as typeof import('../app/parent/child-profiles');

afterEach(() => {
  cleanup();
  delete (globalThis as { fetch?: unknown }).fetch;
});

function reply(status: number, data: unknown): Response {
  return { ok: status >= 200 && status < 300, status, json: async () => data } as Response;
}
const a = { child_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', nickname: 'Demo', age_months: 32, preferred_locale: 'tr-TR' };

test('loading, empty state, create, select and edit in parent UI', async () => {
  let rows = [] as typeof a[];
  let saves = 0;
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url === '/api/children' && !init?.method) return reply(200, { children: rows });
    if (init?.method === 'POST') {
      saves++;
      const body = JSON.parse(init.body as string) as { nickname: string; age_months: number };
      rows = [{ ...a, nickname: body.nickname, age_months: body.age_months }];
      return reply(201, { child_id: a.child_id });
    }
    if (init?.method === 'PATCH') {
      saves++;
      const body = JSON.parse(init.body as string) as { nickname: string; age_months: number };
      rows = [{ ...a, nickname: body.nickname, age_months: body.age_months }];
      return reply(200, rows[0]);
    }
    throw new Error('Unexpected request ' + url);
  }) as typeof fetch;
  render(React.createElement(ChildProfiles));
  await waitFor(() => assert.ok(screen.getByText('Henüz çocuk profili yok.')));
  fireEvent.change(screen.getByLabelText('Takma ad (isteğe bağlı)'), { target: { value: 'Demo' } });
  fireEvent.change(screen.getByLabelText('Yaş (ay)'), { target: { value: '32' } });
  fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
  await waitFor(() => assert.ok(screen.getByRole('button', { name: /Demo · 32 ay/ })));
  fireEvent.click(screen.getByRole('button', { name: /Demo · 32 ay/ }));
  assert.equal(screen.getByRole('button', { name: /Demo · 32 ay/ }).getAttribute('aria-pressed'), 'true');
  fireEvent.click(screen.getByRole('button', { name: 'Düzenle' }));
  fireEvent.change(screen.getByLabelText('Takma ad (isteğe bağlı)'), { target: { value: 'Updated' } });
  fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
  await waitFor(() => assert.ok(screen.getByRole('button', { name: /Updated · 32 ay/ })));
  assert.equal(saves, 2);
  assert.ok(screen.getByText(/Profil sunucuda kaydedildi/));
});

test('profile PATCH failure maps status to actionable message and keeps form', async () => {
  const rows = [a];
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url === '/api/children' && !init?.method) return reply(200, { children: rows });
    if (init?.method === 'PATCH') return reply(400, { error: 'invalid_age' });
    throw new Error('Unexpected');
  }) as typeof fetch;
  render(React.createElement(ChildProfiles));
  await waitFor(() => assert.ok(screen.getByRole('button', { name: /Demo · 32 ay/ })));
  fireEvent.click(screen.getByRole('button', { name: 'Düzenle' }));
  fireEvent.change(screen.getByLabelText('Yaş (ay)'), { target: { value: '17' } });
  fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
  await waitFor(() => assert.match(screen.getByRole('alert').textContent ?? '', /sunucu tarafından kabul edilmedi/));
  assert.equal((screen.getByLabelText('Yaş (ay)') as HTMLInputElement).value, '17');
});

test('backend outage shows recovery action and retry clears error', async () => {
  let fail = true;
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (fail) return reply(503, { error: 'backend_unavailable' });
    return reply(200, { children: [] });
  }) as typeof fetch;
  render(React.createElement(ChildProfiles));
  await waitFor(() => assert.ok(screen.getByRole('alert')));
  fail = false;
  fireEvent.click(screen.getByRole('button', { name: 'Listeyi tekrar yükle' }));
  await waitFor(() => assert.ok(screen.getByText('Henüz çocuk profili yok.')));
  assert.equal(screen.queryByRole('alert'), null);
});

test('stale child request cannot repopulate a changed parent', async () => {
  let release!: (value: Response) => void;
  const slow = new Promise<Response>((resolve) => { release = resolve; });
  let parent = 'parent-a';
  let first = true;
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: parent });
    if (first) { first = false; return slow; }
    return reply(200, { children: [] });
  }) as typeof fetch;
  render(React.createElement(ChildProfiles));
  await waitFor(() => assert.equal(first, false));
  parent = 'parent-b';
  release(reply(200, { children: [a] }));
  await waitFor(() => assert.ok(screen.getByRole('alert')));
  assert.equal(screen.queryByRole('button', { name: /Demo · 32 ay/ }), null);
  fireEvent.click(screen.getByRole('button', { name: 'Listeyi tekrar yükle' }));
  await waitFor(() => assert.ok(screen.getByText('Henüz çocuk profili yok.')));
});

test('profile save error mapping covers 409 and 5xx distinctly', () => {
  assert.match(profileSaveErrorMessage(409), /çakışması/);
  assert.match(profileSaveErrorMessage(503), /Kaydı tekrar/);
  assert.match(profileSaveErrorMessage(500), /Sunucu hatası/);
});

test('PATCH ok then session identity change on verify fails closed without success', async () => {
  const rows = [a];
  let patchHappened = false;
  let authMeSincePatch = 0;
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/me') {
      if (patchHappened) {
        authMeSincePatch += 1;
        if (authMeSincePatch >= 2) return reply(200, { parent_id: 'parent-b' });
      }
      return reply(200, { parent_id: 'parent-a' });
    }
    if (url === '/api/children' && !init?.method) return reply(200, { children: rows });
    if (init?.method === 'PATCH') {
      patchHappened = true;
      authMeSincePatch = 0;
      rows[0] = { ...a, nickname: 'Updated' };
      return reply(200, rows[0]);
    }
    throw new Error('Unexpected');
  }) as typeof fetch;
  render(React.createElement(ChildProfiles));
  await waitFor(() => assert.ok(screen.getByRole('button', { name: /Demo · 32 ay/ })));
  fireEvent.click(screen.getByRole('button', { name: 'Düzenle' }));
  fireEvent.change(screen.getByLabelText('Takma ad (isteğe bağlı)'), { target: { value: 'Updated' } });
  fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
  assert.ok(await screen.findByText(/liste güncellenemedi/i, {}, { timeout: 3000 }));
  assert.equal(screen.queryByText(/^Profil sunucuda kaydedildi\.$/), null);
});

test('save network error retries PATCH not only reload', async () => {
  const rows = [a];
  let patchAttempts = 0;
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url === '/api/children' && !init?.method) return reply(200, { children: rows });
    if (init?.method === 'PATCH') {
      patchAttempts++;
      if (patchAttempts === 1) throw new TypeError('network down');
      rows[0] = { ...a, age_months: 33 };
      return reply(200, rows[0]);
    }
    throw new Error('Unexpected');
  }) as typeof fetch;
  render(React.createElement(ChildProfiles));
  await waitFor(() => assert.ok(screen.getByRole('button', { name: /Demo · 32 ay/ })));
  fireEvent.click(screen.getByRole('button', { name: 'Düzenle' }));
  fireEvent.change(screen.getByLabelText('Yaş (ay)'), { target: { value: '33' } });
  fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
  await waitFor(() => assert.ok(screen.getByRole('alert')));
  fireEvent.click(screen.getByRole('button', { name: 'Kaydı tekrar dene' }));
  await waitFor(() => assert.ok(screen.getByText(/Profil sunucuda kaydedildi/)));
  assert.equal(patchAttempts, 2);
});

test('409 conflict on save offers save retry', async () => {
  const rows = [a];
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url === '/api/children' && !init?.method) return reply(200, { children: rows });
    if (init?.method === 'PATCH') return reply(409, { error: 'conflict' });
    throw new Error('Unexpected');
  }) as typeof fetch;
  render(React.createElement(ChildProfiles));
  await waitFor(() => assert.ok(screen.getByRole('button', { name: /Demo · 32 ay/ })));
  fireEvent.click(screen.getByRole('button', { name: 'Düzenle' }));
  fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
  await waitFor(() => assert.match(screen.getByRole('alert').textContent ?? '', /çakışması/));
  assert.ok(screen.getByRole('button', { name: 'Kaydı tekrar dene' }));
});

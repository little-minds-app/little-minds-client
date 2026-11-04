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
const ParentHome = require('../app/page').default as typeof import('../app/page').default;
const { AuthLogoutButton } = require('../app/parent/auth-logout-button') as typeof import('../app/parent/auth-logout-button');

afterEach(() => {
  cleanup();
  delete (globalThis as { fetch?: unknown }).fetch;
});

function reply(status: number, data: unknown): Response {
  return { ok: status >= 200 && status < 300, status, json: async () => data } as Response;
}

test('auth landing shows loading then signed-out phone form with lm-ui controls', async () => {
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(401, { error: 'invalid_token' });
    throw new Error(url);
  }) as typeof fetch;
  render(React.createElement(ParentHome));
  assert.ok(screen.getByText(/Oturum kontrol ediliyor/));
  await waitFor(() => assert.ok(screen.getByLabelText(/Telefon numarası/)));
  assert.ok(screen.getByRole('button', { name: /Doğrulama kodu gönder/ }));
  assert.equal(screen.queryByText(/Parent ID/i), null);
});

test('phone OTP flow reaches authenticated landing without exposing UUID', async () => {
  let authed = false;
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/me') {
      return authed
        ? reply(200, { parent_id: 'secret-parent-id' })
        : reply(401, { error: 'invalid_token' });
    }
    if (url === '/api/auth/start') return reply(200, { challenge_id: '00000000-0000-4000-8000-000000000001' });
    if (url === '/api/auth/verify') {
      authed = true;
      return reply(200, {});
    }
    throw new Error(url);
  }) as typeof fetch;
  render(React.createElement(ParentHome));
  await waitFor(() => assert.ok(screen.getByLabelText(/Telefon numarası/)));
  fireEvent.change(screen.getByLabelText(/Telefon numarası/), { target: { value: '+905551112233' } });
  fireEvent.click(screen.getByRole('button', { name: /Doğrulama kodu gönder/ }));
  await waitFor(() => assert.ok(screen.getByLabelText(/6 haneli SMS kodu/)));
  fireEvent.change(screen.getByLabelText(/6 haneli SMS kodu/), { target: { value: '123456' } });
  fireEvent.click(screen.getByRole('button', { name: /Doğrula ve devam et/ }));
  await waitFor(() => assert.ok(screen.getByText(/Giriş başarılı/)));
  assert.ok(screen.getByText(/Ebeveyn paneline git/));
  assert.equal(screen.queryByText(/secret-parent-id/), null);
});

test('verify failure shows accessible error and keeps OTP step', async () => {
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/me') return reply(401, {});
    if (url === '/api/auth/start') return reply(200, { challenge_id: 'c1' });
    if (url === '/api/auth/verify') return reply(400, { message: 'Geçersiz kod.' });
    throw new Error(url);
  }) as typeof fetch;
  render(React.createElement(ParentHome));
  await waitFor(() => assert.ok(screen.getByLabelText(/Telefon numarası/)));
  fireEvent.change(screen.getByLabelText(/Telefon numarası/), { target: { value: '5551112233' } });
  fireEvent.click(screen.getByRole('button', { name: /Doğrulama kodu gönder/ }));
  await waitFor(() => assert.ok(screen.getByLabelText(/6 haneli SMS kodu/)));
  fireEvent.change(screen.getByLabelText(/6 haneli SMS kodu/), { target: { value: '000000' } });
  fireEvent.click(screen.getByRole('button', { name: /Doğrula ve devam et/ }));
  await waitFor(() => assert.ok(screen.getByRole('alert')));
  assert.match(screen.getByRole('alert').textContent ?? '', /Geçersiz kod/);
  assert.ok(screen.getByLabelText(/6 haneli SMS kodu/));
});

test('logout button calls logout API', async () => {
  let logoutCalls = 0;
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/logout' && init?.method === 'POST') {
      logoutCalls += 1;
      return reply(200, {});
    }
    throw new Error(url);
  }) as typeof fetch;
  render(React.createElement(AuthLogoutButton));
  fireEvent.click(screen.getByRole('button', { name: 'Çıkış yap' }));
  await waitFor(() => assert.equal(logoutCalls, 1));
});

test('signed-in landing logout clears session via API', async () => {
  let logoutCalls = 0;
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'p1' });
    if (url === '/api/auth/logout' && init?.method === 'POST') {
      logoutCalls += 1;
      return reply(200, {});
    }
    throw new Error(url);
  }) as typeof fetch;
  render(React.createElement(ParentHome));
  await waitFor(() => assert.ok(screen.getByText(/Giriş başarılı/)));
  const logoutButtons = await screen.findAllByRole('button', { name: /Çıkış yap/ });
  fireEvent.click(logoutButtons[0]!);
  await waitFor(() => assert.equal(logoutCalls, 1));
});

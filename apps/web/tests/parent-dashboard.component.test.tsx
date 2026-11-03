import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import React from 'react';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>', { url: 'http://localhost/' });
Object.assign(globalThis, {
  window: dom.window, document: dom.window.document, HTMLElement: dom.window.HTMLElement,
  MutationObserver: dom.window.MutationObserver,
});
Object.defineProperty(globalThis, 'navigator', { configurable: true, value: dom.window.navigator });
const { cleanup, render, screen, waitFor, fireEvent } = require('@testing-library/react') as typeof import('@testing-library/react');
const { WebParentDashboard, dashboardWindow, formatSessionKpiRate } = require('../app/parent/web-parent-dashboard') as typeof import('../app/parent/web-parent-dashboard');

const childA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const childB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const kpi = {
  definition_version: 'session-kpi-v1', source: 'server_activity_sessions',
  generated_at: '2026-11-03T12:00:00.000Z',
  window: { from: '2026-10-26T21:00:00.000Z', to: '2026-11-03T21:00:00.000Z', timezone: 'Europe/Istanbul', bounds: 'half_open_started_at' },
  freshness: { status: 'fresh', data_completeness: 'complete', stale_threshold_seconds: 7200 },
  sample: { eligible_sessions: 2, terminal_sessions: 2, excluded_unsupported_schema: 0, excluded_consent: 0 },
  metrics: { eligible_session_count: 2, completed_session_count: 1, interrupted_session_count: 1,
    abandoned_session_count: 0, in_progress_session_count: 0, total_play_duration_seconds: 240,
    distinct_play_days: 1,
    by_activity: [{ content_version_id: 'activity-alpha', session_starts: 2, completed_sessions: 1, play_duration_seconds: 240 }],
    completed_session_rate: { availability_status: 'available', value: 0.5, numerator: 1, denominator: 2 },
    first_attempt_accuracy: { availability_status: 'unavailable', numerator: 0, denominator: 0, reason_code: 'insufficient_data' } },
};
const mission = {
  schema_version: 'mission-status-v1', definition_version: 'mission-status-v1',
  generated_at: '2026-11-03T12:00:00.000Z', child_id: childA,
  window: { from: '2026-10-26T21:00:00.000Z', to: '2026-11-03T21:00:00.000Z', bounds: 'half_open_recorded_at' },
  pagination: { limit: 50, truncated: false },
  items: [{ occurrence_id: 'occurrence-1', mission_id: 'water-plants',
    interaction: { offered_at: '2026-11-03T11:00:00.000Z', opened_at: null, source: 'child_play_events' },
    parent_report: { availability: 'no_report', status: null, authoritative: false, recorded_at: null, assertion_id: null,
      revision: null, actor: 'parent', source: 'caregiver_report' } }],
};
function reply(status: number, data: unknown): Response {
  return { ok: status >= 200 && status < 300, status, json: async () => data } as Response;
}
afterEach(() => { cleanup(); delete (globalThis as { fetch?: unknown }).fetch; });

test('window matches previous seven Istanbul dates and today, half-open UTC', () => {
  const window = dashboardWindow(new Date('2026-11-03T12:00:00Z'));
  assert.deepEqual(window, { from: '2026-10-26T21:00:00.000Z', to: '2026-11-03T21:00:00.000Z', timezone: 'Europe/Istanbul' });
});

test('no selected child never fetches protected dashboard data', () => {
  let called = false;
  globalThis.fetch = (async () => { called = true; throw Error('unexpected'); }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: null }));
  assert.ok(screen.getByText(/Özeti görmek için/));
  assert.equal(called, false);
});

test('renders canonical KPI and reports no_report without inferring completion', async () => {
  const urls: string[] = [];
  globalThis.fetch = (async (url: string) => {
    urls.push(url);
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url.startsWith('/api/insights/')) return reply(200, kpi);
    if (url.includes('/missions?')) return reply(200, mission);
    throw Error('Unexpected URL ' + url);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/Ebeveyn bildirimi yok/)));
  assert.ok(screen.getByText('Uygun oturum'));
  assert.ok(screen.getByText('Toplam oyun süresi'));
  assert.ok(screen.getByText(/50% \(1\/2\)/));
  assert.ok(screen.getByText('insufficient_data'));
  assert.ok(screen.getByText(/Tazelik: fresh/));
  assert.ok(screen.getByText(/activity-alpha/));
  assert.equal(urls.filter((url) => url === '/api/auth/me').length, 2);
  assert.ok(urls.some((url) => url.includes('child_id=' + childA)));
  assert.ok(urls.some((url) => url.includes('/children/' + childA + '/missions?')));
});

test('recoverable KPI outage leaves successful mission data visible', async () => {
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url.startsWith('/api/insights/')) return reply(503, {});
    return reply(200, mission);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/Ebeveyn bildirimi yok/)));
  assert.ok(screen.getByText(/Oturum özeti yüklenemedi/));
});

test('401 on either source hides both protected panels', async () => {
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url.startsWith('/api/insights/')) return reply(401, {});
    return reply(200, mission);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/Korumalı bilgiler gizlendi/)));
  assert.equal(screen.queryByText(/Ebeveyn bildirimi yok/), null);
  assert.equal(screen.queryByText('Uygun oturum'), null);
});

test('child switch ignores stale response from previous child', async () => {
  let resolveOld!: (r: Response) => void;
  const old = new Promise<Response>((resolve) => { resolveOld = resolve; });
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url.includes('/children/' + childA + '/missions?')) return old;
    if (url.includes('/children/' + childB + '/missions?')) return reply(200, { ...mission, child_id: childB, items: [] });
    return reply(200, kpi);
  }) as typeof fetch;
  const view = render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/Özet yükleniyor/)));
  view.rerender(React.createElement(WebParentDashboard, { selectedChildId: childB }));
  await waitFor(() => assert.ok(screen.getByText(/Bu dönemde görev kaydı bulunamadı/)));
  resolveOld(reply(200, mission));
  await waitFor(() => assert.equal(screen.queryByText(/Ebeveyn bildirimi yok/), null));
});

test('parent switch between fetch and publish fails closed', async () => {
  let checks = 0;
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: ++checks === 1 ? 'parent-a' : 'parent-b' });
    if (url.startsWith('/api/insights/')) return reply(200, kpi);
    return reply(200, mission);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/Korumalı bilgiler gizlendi/)));
  assert.equal(screen.queryByText(/Ebeveyn bildirimi yok/), null);
});

test('formatSessionKpiRate uses server availability without recomputing', () => {
  assert.deepEqual(formatSessionKpiRate({
    availability_status: 'available', value: 0.25, numerator: 1, denominator: 4,
  }), { label: '25% (1/4)', unavailable: false });
  assert.deepEqual(formatSessionKpiRate({
    availability_status: 'unavailable', numerator: 0, denominator: 0, reason_code: 'no_signal',
  }), { label: 'no_signal', unavailable: true });
});

test('stale and partial freshness metadata show warnings', async () => {
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url.startsWith('/api/insights/')) {
      return reply(200, {
        ...kpi,
        freshness: { status: 'stale', data_completeness: 'partial', stale_threshold_seconds: 7200 },
      });
    }
    return reply(200, mission);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/Veriler güncel olmayabilir/)));
  assert.ok(screen.getByText(/Veri seti kısmi olabilir/));
});

test('tab focus revalidates session and clears data after logout', async () => {
  let authed = true;
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return authed ? reply(200, { parent_id: 'parent-a' }) : reply(401, {});
    if (url.startsWith('/api/insights/')) return reply(200, kpi);
    return reply(200, mission);
  }) as typeof fetch;
  Object.defineProperty(document, 'visibilityState', { configurable: true, value: 'visible' });
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/50% \(1\/2\)/)));
  authed = false;
  fireEvent(window, new dom.window.Event('focus'));
  await waitFor(() => assert.ok(screen.getByText(/Korumalı bilgiler gizlendi/)));
  assert.equal(screen.queryByText(/50% \(1\/2\)/), null);
});

test('tab focus clears dashboard when parent identity changes', async () => {
  let parent = 'parent-a';
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: parent });
    if (url.startsWith('/api/insights/')) return reply(200, kpi);
    return reply(200, mission);
  }) as typeof fetch;
  Object.defineProperty(document, 'visibilityState', { configurable: true, value: 'visible' });
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/Ebeveyn bildirimi yok/)));
  parent = 'parent-b';
  fireEvent(window, new dom.window.Event('focus'));
  await waitFor(() => assert.ok(screen.getByText(/Korumalı bilgiler gizlendi/)));
  assert.equal(screen.queryByText(/Ebeveyn bildirimi yok/), null);
});

test('tab focus network error on session revalidation fails closed', async () => {
  let meCalls = 0;
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') {
      meCalls += 1;
      if (meCalls > 2) throw new TypeError('Failed to fetch');
      return reply(200, { parent_id: 'parent-a' });
    }
    if (url.startsWith('/api/insights/')) return reply(200, kpi);
    return reply(200, mission);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/50% \(1\/2\)/)));
  fireEvent(window, new dom.window.Event('focus'));
  await waitFor(() => assert.ok(screen.getByText(/Korumalı bilgiler gizlendi/)));
  assert.equal(screen.queryByText(/50% \(1\/2\)/), null);
});

test('retry refetches both independent data panels', async () => {
  let kpis = 0;
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url.startsWith('/api/insights/')) return ++kpis === 1 ? reply(503, {}) : reply(200, kpi);
    return reply(200, mission);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/Oturum özeti yüklenemedi/)));
  fireEvent.click(screen.getByRole('button', { name: 'Özeti yenile' }));
  await waitFor(() => assert.ok(screen.getByText('Uygun oturum')));
  assert.equal(kpis, 2);
});

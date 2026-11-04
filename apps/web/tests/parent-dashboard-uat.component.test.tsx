/** LMP-53/54 functional UAT regression cases.
 * Uses synthetic responses only; does not access real accounts or mutate UAT data.
 */
import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import React from 'react';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>', { url: 'http://localhost/' });
Object.assign(globalThis, {
  window: dom.window, document: dom.window.document,
  HTMLElement: dom.window.HTMLElement, MutationObserver: dom.window.MutationObserver,
});
Object.defineProperty(globalThis, 'navigator', { configurable: true, value: dom.window.navigator });
const { cleanup, fireEvent, render, screen, waitFor } = require('@testing-library/react') as typeof import('@testing-library/react');
const { WebParentDashboard } = require('../app/parent/web-parent-dashboard') as typeof import('../app/parent/web-parent-dashboard');

const child = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const parent = '11111111-1111-4111-8111-111111111111';
const otherParent = '22222222-2222-4222-8222-222222222222';
const instant = '2026-11-03T12:00:00.000Z';

const kpis = {
  definition_version: 'session-kpi-v1', source: 'server_activity_sessions', generated_at: instant,
  freshness: { status: 'fresh', data_completeness: 'complete', stale_threshold_seconds: 3600 },
  window: { from: '2026-10-26T21:00:00.000Z', to: '2026-11-03T21:00:00.000Z',
    timezone: 'Europe/Istanbul', bounds: 'half_open_started_at' },
  sample: { eligible_sessions: 5, terminal_sessions: 4, excluded_unsupported_schema: 0, excluded_consent: 0 },
  metrics: {
    eligible_session_count: 5, completed_session_count: 3, interrupted_session_count: 1,
    abandoned_session_count: 0, in_progress_session_count: 1, total_play_duration_seconds: 255,
    distinct_play_days: 2, by_activity: [],
    completed_session_rate: { availability_status: 'available', value: 0.6, numerator: 3, denominator: 5 },
    first_attempt_accuracy: { availability_status: 'unavailable', numerator: 0, denominator: 0, reason_code: 'no_signal' },
  },
};
const mission = {
  schema_version: 'mission-status-v1', definition_version: 'mission-status-v1',
  generated_at: instant, child_id: child,
  window: { from: '2026-10-26T21:00:00.000Z', to: '2026-11-03T21:00:00.000Z',
    bounds: 'half_open_recorded_at' },
  pagination: { limit: 50, truncated: false },
  items: [{
    occurrence_id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    mission_id: 'sample-mission',
    interaction: { offered_at: instant, opened_at: instant, source: 'child_play_events' },
    parent_report: { availability: 'reported', status: 'completed', authoritative: true,
      recorded_at: instant, assertion_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      revision: 1, actor: 'parent', source: 'caregiver_report' },
  }],
};
function response(status: number, body: unknown): Response {
  return { ok: status >= 200 && status < 300, status, json: async () => body } as Response;
}
afterEach(() => { cleanup(); delete (globalThis as { fetch?: unknown }).fetch; });

test('UAT-04: renders only authoritative caregiver completion and server KPI values', async () => {
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return response(200, { parent_id: parent });
    if (url.startsWith('/api/insights/')) return response(200, kpis);
    if (url.includes('/missions?')) return response(200, mission);
    throw Error('unexpected ' + url);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: child }));
  await waitFor(() => assert.ok(screen.getByText(/Ebeveyn bildirimi: Tamamlandı/)));
  assert.ok(screen.getByText(/60% \(3\/5\)/));
  const missionDetails = screen.getByText(/Görev kaynağı ve pencere ayrıntıları/).closest('details');
  assert.ok(missionDetails);
  missionDetails!.open = true;
  await waitFor(() => assert.ok(screen.getAllByText(/Ebeveyn bildirimi/).length >= 1));
  assert.ok(screen.getByText(/Yetkili kayıt/));
});

for (const [source, denied] of [['KPI', 403], ['mission', 404]] as const) {
  test(`UAT-06: ${source} ownership HTTP ${denied} fails closed even if other request returns sensitive data`, async () => {
    globalThis.fetch = (async (url: string) => {
      if (url === '/api/auth/me') return response(200, { parent_id: otherParent });
      if (url.startsWith('/api/insights/')) return response(source === 'KPI' ? denied : 200, kpis);
      if (url.includes('/missions?')) return response(source === 'mission' ? denied : 200, mission);
      throw Error('unexpected ' + url);
    }) as typeof fetch;
    render(React.createElement(WebParentDashboard, { selectedChildId: child }));
    await waitFor(() => assert.ok(screen.getByText(/Korumalı bilgiler gizlendi/)));
    assert.equal(screen.queryByText(/Ebeveyn bildirimi: Tamamlandı/), null);
    assert.equal(screen.queryByText(/60% \(3\/5\)/), null);
  });
}

test('UAT-08: recoverable mission outage retains canonical successful KPI panel', async () => {
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return response(200, { parent_id: parent });
    if (url.startsWith('/api/insights/')) return response(200, kpis);
    if (url.includes('/missions?')) return response(503, { error: 'backend_unavailable' });
    throw Error('unexpected ' + url);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: child }));
  await waitFor(() => assert.ok(screen.getByText(/Görev durumları yüklenemedi/)));
  assert.ok(screen.getByText(/60% \(3\/5\)/));
  assert.equal(screen.queryByText(/Ebeveyn bildirimi: Tamamlandı/), null);
});

test('UAT-05: truncated mission history is explicitly labeled as incomplete', async () => {
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return response(200, { parent_id: parent });
    if (url.startsWith('/api/insights/')) return response(200, kpis);
    if (url.includes('/missions?')) return response(200, { ...mission, pagination: { limit: 50, truncated: true } });
    throw Error('unexpected ' + url);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: child }));
  await waitFor(() => assert.ok(screen.getByText(/sonuçlar sınırlı/)));
  assert.ok(screen.getByText(/Ebeveyn bildirimi: Tamamlandı/));
});

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
const { cleanup, render, screen, waitFor } = require('@testing-library/react') as typeof import('@testing-library/react');
const {
  SessionCompositionDonut,
  ActivityDurationChart,
  TrendsPlaceholderChart,
} = require('../app/parent/dashboard-charts') as typeof import('../app/parent/dashboard-charts');
const { WebParentDashboard } = require('../app/parent/web-parent-dashboard') as typeof import('../app/parent/web-parent-dashboard');

afterEach(() => {
  cleanup();
  delete (globalThis as { fetch?: unknown }).fetch;
});

function reply(status: number, data: unknown): Response {
  return { ok: status >= 200 && status < 300, status, json: async () => data } as Response;
}

test('session donut shows honest empty shell when eligible count is zero', () => {
  render(React.createElement(SessionCompositionDonut, {
    eligible: 0, completed: 0, interrupted: 0, inProgress: 0, abandoned: 0,
  }));
  assert.ok(screen.getByText(/uygun oturum yok/i));
});

test('activity chart empty card explains missing by_activity rows', () => {
  render(React.createElement(ActivityDurationChart, { rows: [], maxSeconds: 0 }));
  assert.ok(screen.getByText(/etkinlik bazlı oyun süresi kaydı yok/i));
});

test('trends placeholder defers to LMP-87/LMP-90 without fabricated values', () => {
  render(React.createElement(TrendsPlaceholderChart));
  assert.ok(screen.getByText(/LMP-87 \/ LMP-90/));
  assert.ok(screen.getByText(/uydurma günlük değer üretilmiyor/i));
});

test('dashboard renders KPI metric cards and donut for seeded KPI fixture', async () => {
  const childA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const kpi = {
    definition_version: 'session-kpi-v1', source: 'server_activity_sessions',
    generated_at: '2026-11-03T12:00:00.000Z',
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
  };
  const mission = { schema_version: 'mission-status-v1', definition_version: 'mission-status-v1', generated_at: '2026-11-03T12:00:00.000Z', child_id: childA, window: { from: '2026-10-26T21:00:00.000Z', to: '2026-11-03T21:00:00.000Z', bounds: 'half_open_recorded_at' }, pagination: { limit: 50, truncated: false }, items: [] };
  globalThis.fetch = (async (url: string) => {
    if (url === '/api/auth/me') return reply(200, { parent_id: 'parent-a' });
    if (url.startsWith('/api/insights/')) return reply(200, kpi);
    return reply(200, mission);
  }) as typeof fetch;
  render(React.createElement(WebParentDashboard, { selectedChildId: childA }));
  await waitFor(() => assert.ok(screen.getByText(/50% \(1\/2\)/)));
  assert.ok(screen.getAllByText(/Oturum dağılımı/).length >= 1);
  assert.ok(screen.getByText(/Zaman içi trend/));
  assert.equal(screen.queryByRole('button', { name: /Özeti yenile/ }), null);
});

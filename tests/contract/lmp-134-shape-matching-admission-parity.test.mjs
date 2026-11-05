import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import Ajv from 'ajv';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '../..');
const schemaDir = join(repoRoot, 'contracts/schemas/activity');

const deviceId = '3d15ad77-4bd6-50b8-9422-3db5738c39f1';
const contentVersionId = '018f1340-0000-4000-8000-000000000001';
const playSessionId = '55555555-5555-4555-8555-555555555555';
const policy = 'synthetic-policy-v1';

const provenance = {
  emitter: 'kids_mode_client',
  actor_scope: 'child_play',
  source: 'instrumented',
  clock_trust: 'wall_clock_only',
};

function baseEvent(eventType, payload, extra = {}) {
  return {
    schema_version: '1.0.0',
    event_id: '66666666-6666-4666-8666-666666666666',
    event_type: eventType,
    play_session_id: playSessionId,
    device_id: deviceId,
    content_version_id: contentVersionId,
    occurred_at: '2026-11-04T12:00:00.000Z',
    consent_scope: 'essential_play_events',
    consent_policy_version: policy,
    provenance,
    payload,
    ...extra,
  };
}

function compileValidator() {
  const ajv = new Ajv({ allErrors: true, strict: false });
  ajv.addSchema(
    JSON.parse(readFileSync(join(schemaDir, 'defs.schema.json'), 'utf8')),
  );
  const eventSchema = JSON.parse(
    readFileSync(join(schemaDir, 'activity-event-v1.schema.json'), 'utf8'),
  );
  return ajv.compile(eventSchema);
}

const shapeMatchingWireByType = {
  activity_started: { age_months: 36, age_band: '36_47' },
  activity_attempted: { attempt_index: 0 },
  activity_hint_used: { hint_level: 1 },
  activity_completed: {
    completion_status: 'completed',
    scoring: 'neutral',
    hints_used: 0,
    eligible_first_attempts: 3,
    correct_first_attempts: 2,
  },
  activity_abandoned: { completion_status: 'abandoned' },
};

test('LMP-134 Shape Matching canonical payloads pass activity-event-v1 AJV', () => {
  const validate = compileValidator();
  for (const [eventType, payload] of Object.entries(shapeMatchingWireByType)) {
    const extra =
      eventType === 'activity_completed' || eventType === 'activity_abandoned'
        ? { monotonic_duration_seconds: 90 }
        : {};
    const doc = baseEvent(eventType, payload, extra);
    assert.equal(
      validate(doc),
      true,
      `${eventType} should validate: ${JSON.stringify(validate.errors)}`,
    );
  }
});

test('LMP-134 additionalProperties negative on payload (Mac regression)', () => {
  const validate = compileValidator();
  const legacyStarted = baseEvent('activity_started', {
    age_months: 36,
    activity_variant_id: 'shape_matching',
  });
  assert.equal(validate(legacyStarted), false);
  const legacyAttempted = baseEvent('activity_attempted', {
    shape_id: 'circle',
    correct: true,
    round_index: 0,
  });
  assert.equal(validate(legacyAttempted), false);
  const issues = validate.errors ?? [];
  assert.ok(
    issues.some((e) => e.keyword === 'additionalProperties' && e.instancePath.includes('payload')),
    `expected payload additionalProperties issues, got ${JSON.stringify(issues)}`,
  );
});

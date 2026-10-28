/**
 * LMP-27 negative contract tests — stale pin, mutated spec, missing generated output.
 * Uses pure integrity helpers so the working tree is never mutated.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';
import { parse as parseYaml } from 'yaml';
import {
  assertGeneratedClientsPresent,
  assertPinAndArtifactIntegrity,
  evaluateCompatibility,
  gitBlobShaFromBuffer,
} from '../../scripts/contracts/integrity.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const OPENAPI_PATH = join(ROOT, 'contracts', 'openapi.yaml');
const PIN_PATH = join(ROOT, 'contracts', 'pin.json');
const COMPAT_PATH = join(
  ROOT,
  'contracts',
  'compatibility',
  'required-contract.json',
);

function loadBaseline() {
  return JSON.parse(readFileSync(COMPAT_PATH, 'utf8'));
}

function loadGoodPin() {
  return JSON.parse(readFileSync(PIN_PATH, 'utf8'));
}

function loadGoodDocAndRaw() {
  const openApiRaw = readFileSync(OPENAPI_PATH);
  return { openApiRaw, doc: parseYaml(openApiRaw.toString('utf8')) };
}

describe('LMP-27 negative: stale / mismatched pin', () => {
  it('fails when contractVersion disagrees with VERSION', () => {
    const { openApiRaw, doc } = loadGoodDocAndRaw();
    const pin = { ...loadGoodPin(), contractVersion: '9.9.9' };
    assert.throws(
      () =>
        assertPinAndArtifactIntegrity({
          pin,
          version: '0.2.0',
          openApiDoc: doc,
          openApiRaw,
        }),
      /contractVersion/,
    );
  });

  it('fails when artifactBlobSha does not match vendored OpenAPI bytes', () => {
    const { openApiRaw, doc } = loadGoodDocAndRaw();
    const pin = {
      ...loadGoodPin(),
      artifactBlobSha: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    };
    assert.throws(
      () =>
        assertPinAndArtifactIntegrity({
          pin,
          version: '0.2.0',
          openApiDoc: doc,
          openApiRaw,
        }),
      /artifactBlobSha/,
    );
  });

  it('fails when backendCommitSha is not a full git SHA (stale/floating ref)', () => {
    const { openApiRaw, doc } = loadGoodDocAndRaw();
    const pin = { ...loadGoodPin(), backendCommitSha: 'main' };
    assert.throws(
      () =>
        assertPinAndArtifactIntegrity({
          pin,
          version: '0.2.0',
          openApiDoc: doc,
          openApiRaw,
        }),
      /backendCommitSha|floating main/i,
    );
  });

  it('fails when OpenAPI info.version drifts from pin VERSION', () => {
    const { openApiRaw, doc } = loadGoodDocAndRaw();
    const drifted = structuredClone(doc);
    drifted.info.version = '0.3.0';
    assert.throws(
      () =>
        assertPinAndArtifactIntegrity({
          pin: loadGoodPin(),
          version: '0.2.0',
          openApiDoc: drifted,
          openApiRaw,
        }),
      /info\.version/,
    );
  });
});

describe('LMP-27 negative: mutated OpenAPI spec', () => {
  it('fails compatibility when an invented product path is added', () => {
    const { doc } = loadGoodDocAndRaw();
    const mutated = structuredClone(doc);
    mutated.paths['/v1/invented'] = {
      get: { operationId: 'invented', responses: { '200': { description: 'nope' } } },
    };
    const errors = evaluateCompatibility({
      doc: mutated,
      baseline: loadBaseline(),
      version: '0.2.0',
    });
    assert.ok(
      errors.some((e) => e.includes('/v1/invented')),
      `expected invented-path error, got: ${errors.join('; ')}`,
    );
  });

  it('fails compatibility when an event ingest path is invented', () => {
    const { doc } = loadGoodDocAndRaw();
    const mutated = structuredClone(doc);
    mutated.paths['/v1/events/batch'] = {
      post: {
        operationId: 'postEventsBatch',
        responses: { '202': { description: 'nope' } },
      },
    };
    const errors = evaluateCompatibility({
      doc: mutated,
      baseline: loadBaseline(),
      version: '0.2.0',
    });
    assert.ok(
      errors.some((e) => e.includes('/v1/events/batch')),
      `expected ingest-path error, got: ${errors.join('; ')}`,
    );
  });

  it('fails compatibility when a required HealthStatus field is removed', () => {
    const { doc } = loadGoodDocAndRaw();
    const mutated = structuredClone(doc);
    mutated.components.schemas.HealthStatus.required = ['status', 'service'];
    delete mutated.components.schemas.HealthStatus.properties.timestamp;
    const errors = evaluateCompatibility({
      doc: mutated,
      baseline: loadBaseline(),
      version: '0.2.0',
    });
    assert.ok(
      errors.some((e) => /timestamp/i.test(e)),
      `expected timestamp breaking error, got: ${errors.join('; ')}`,
    );
  });

  it('fails compatibility when ActivityEventV1 required fields are removed', () => {
    const { doc } = loadGoodDocAndRaw();
    const mutated = structuredClone(doc);
    mutated.components.schemas.ActivityEventV1.required = ['event_id', 'event_type'];
    const errors = evaluateCompatibility({
      doc: mutated,
      baseline: loadBaseline(),
      version: '0.2.0',
    });
    assert.ok(
      errors.some((e) => /ActivityEventV1/i.test(e)),
      `expected ActivityEventV1 breaking error, got: ${errors.join('; ')}`,
    );
  });

  it('fails pin integrity when vendored bytes are mutated but pin blob SHA is unchanged', () => {
    const { doc } = loadGoodDocAndRaw();
    const mutatedRaw = Buffer.from(
      readFileSync(OPENAPI_PATH, 'utf8').replace(
        'Process liveness',
        'Process liveness MUTATED',
      ),
      'utf8',
    );
    assert.notEqual(gitBlobShaFromBuffer(mutatedRaw), loadGoodPin().artifactBlobSha);
    assert.throws(
      () =>
        assertPinAndArtifactIntegrity({
          pin: loadGoodPin(),
          version: '0.2.0',
          openApiDoc: doc,
          openApiRaw: mutatedRaw,
        }),
      /artifactBlobSha|blob SHA/,
    );
  });
});

describe('LMP-27 negative: missing generated output', () => {
  it('fails when generated client files are absent from a fake root', () => {
    const emptyRoot = join(ROOT, 'tests', 'contract', '__missing_generated_root__');
    assert.throws(
      () => assertGeneratedClientsPresent(emptyRoot),
      /Missing generated client output/,
    );
  });
});

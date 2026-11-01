/**
 * LMP-23 / LMP-27 client contract tests — pin integrity, schema, generated surface.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';
import SwaggerParser from '@apidevtools/swagger-parser';
import { parse as parseYaml } from 'yaml';
import {
  assertGeneratedClientsPresent,
  assertGeneratedPinMetadata,
  assertPinAndArtifactIntegrity,
  gitBlobShaFromFile,
} from '../../scripts/contracts/integrity.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const OPENAPI_PATH = join(ROOT, 'contracts', 'openapi.yaml');
const VERSION_PATH = join(ROOT, 'contracts', 'VERSION');
const PIN_PATH = join(ROOT, 'contracts', 'pin.json');

describe('LMP-23/27 OpenAPI pin and schema', () => {
  it('records a full backend commit SHA pin (not main) plus artifact blob SHA', () => {
    const pin = JSON.parse(readFileSync(PIN_PATH, 'utf8'));
    assert.match(pin.backendCommitSha, /^[0-9a-f]{40}$/i);
    assert.match(pin.artifactBlobSha, /^[0-9a-f]{40}$/i);
    assert.equal(pin.artifactPath, 'contracts/openapi.yaml');
    assert.equal(pin.contractVersion, '0.9.0');
    assert.equal(pin.backendRepository, 'little-minds-app/little-minds-backend');
    assert.equal(
      pin.backendCommitSha,
      '4b9559d6a17a339d8741cf563b0450948840f5eb',
    );
    assert.equal(
      pin.backendPullRequest,
      'https://github.com/little-minds-app/little-minds-backend/pull/25',
    );
    assert.notEqual(pin.backendCommitSha.toLowerCase(), 'main');
  });

  it('keeps VERSION, pin, OpenAPI info.version, and vendored blob SHA aligned', () => {
    const version = readFileSync(VERSION_PATH, 'utf8').trim();
    const pin = JSON.parse(readFileSync(PIN_PATH, 'utf8'));
    const openApiRaw = readFileSync(OPENAPI_PATH);
    const doc = parseYaml(openApiRaw.toString('utf8'));
    assert.equal(version, '0.9.0');
    assertPinAndArtifactIntegrity({ pin, version, openApiDoc: doc, openApiRaw });
    assert.equal(gitBlobShaFromFile(OPENAPI_PATH), pin.artifactBlobSha);
  });

  it('validates OpenAPI 3 document with auth surface (no event ingest)', async () => {
    const api = await SwaggerParser.validate(OPENAPI_PATH);
    assert.ok(String(api.openapi).startsWith('3.'));
    const pathKeys = Object.keys(api.paths ?? {}).sort();
    assert.ok(pathKeys.includes('/health'));
    assert.ok(pathKeys.some((p) => p.startsWith('/v1/auth/')));
    assert.ok(api.paths['/health'].get);
    assert.equal(api.paths['/health'].get.operationId, 'getHealth');
    assert.equal(api.paths['/v1/events/batch'], undefined);
    assert.ok(
      !pathKeys.some((p) => /events/i.test(p)),
      `unexpected event path(s): ${pathKeys.join(', ')}`,
    );
    const schema = api.components.schemas.HealthStatus;
    assert.deepEqual(schema.required.sort(), ['service', 'status', 'timestamp'].sort());
    assert.ok(api.components.schemas.ActivitySessionV1);
    assert.ok(api.components.schemas.ActivityEventV1);
  });

  it('exposes committed TypeScript and Dart generated clients pinned to backend SHA', () => {
    const pin = JSON.parse(readFileSync(PIN_PATH, 'utf8'));
    const version = readFileSync(VERSION_PATH, 'utf8').trim();
    assertGeneratedClientsPresent(ROOT);
    assertGeneratedPinMetadata({ root: ROOT, pin, version });
  });
});

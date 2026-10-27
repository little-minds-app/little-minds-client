/**
 * LMP-23 client contract tests — schema validation, pin integrity, generated surface.
 */
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';
import SwaggerParser from '@apidevtools/swagger-parser';
import { parse as parseYaml } from 'yaml';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const OPENAPI_PATH = join(ROOT, 'contracts', 'openapi.yaml');
const VERSION_PATH = join(ROOT, 'contracts', 'VERSION');
const PIN_PATH = join(ROOT, 'contracts', 'pin.json');
const TS_SCHEMA = join(ROOT, 'generated', 'typescript', 'schema.ts');
const DART_PUBSPEC = join(ROOT, 'generated', 'dart', 'pubspec.yaml');

describe('LMP-23 OpenAPI pin and schema', () => {
  it('records a full backend commit SHA pin (not main)', () => {
    const pin = JSON.parse(readFileSync(PIN_PATH, 'utf8'));
    assert.match(pin.backendCommitSha, /^[0-9a-f]{40}$/i);
    assert.equal(pin.artifactPath, 'contracts/openapi.yaml');
    assert.equal(pin.contractVersion, '0.1.0');
    assert.equal(pin.backendRepository, 'little-minds-app/little-minds-backend');
    assert.notEqual(pin.backendCommitSha.toLowerCase(), 'main');
  });

  it('keeps VERSION, pin, and OpenAPI info.version aligned', () => {
    const version = readFileSync(VERSION_PATH, 'utf8').trim();
    const pin = JSON.parse(readFileSync(PIN_PATH, 'utf8'));
    const doc = parseYaml(readFileSync(OPENAPI_PATH, 'utf8'));
    assert.equal(version, '0.1.0');
    assert.equal(pin.contractVersion, version);
    assert.equal(doc.info.version, version);
  });

  it('validates OpenAPI 3 document with only GET /health', async () => {
    const api = await SwaggerParser.validate(OPENAPI_PATH);
    assert.ok(String(api.openapi).startsWith('3.'));
    assert.deepEqual(Object.keys(api.paths ?? {}).sort(), ['/health']);
    assert.ok(api.paths['/health'].get);
    assert.equal(api.paths['/health'].get.operationId, 'getHealth');
    const schema = api.components.schemas.HealthStatus;
    assert.deepEqual(schema.required.sort(), ['service', 'status', 'timestamp'].sort());
  });

  it('exposes committed TypeScript and Dart generated clients', () => {
    assert.ok(existsSync(TS_SCHEMA), 'generated/typescript/schema.ts missing');
    assert.ok(existsSync(DART_PUBSPEC), 'generated/dart/pubspec.yaml missing');
    const ts = readFileSync(TS_SCHEMA, 'utf8');
    assert.match(ts, /\/health/);
    assert.match(ts, /getHealth/);
    assert.match(ts, /HealthStatus/);
    const pubspec = readFileSync(DART_PUBSPEC, 'utf8');
    assert.match(pubspec, /name:\s*'?little_minds_api'?/);
  });
});

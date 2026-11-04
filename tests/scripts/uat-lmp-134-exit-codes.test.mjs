import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import path from 'node:path';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const script = path.join(repoRoot, 'scripts/uat-lmp-134-shape-matching-production.sh');

function runUat(extraEnv = {}) {
  return spawnSync('bash', [script], {
    cwd: repoRoot,
    env: {
      ...process.env,
      LM_LMP134_UAT_DRY_RUN: '1',
      LM_LMP134_WITH_DB: '1',
      ...extraEnv,
    },
    encoding: 'utf8',
  });
}

test('UAT script exits 1 when DATABASE_URL targets forbidden little_minds', () => {
  const result = runUat({
    DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:5432/little_minds',
    LM_VERIFY_WITH_DB: '1',
  });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stdout + result.stderr, /OVERALL: FAIL/);
  assert.match(result.stdout + result.stderr, /FAIL\s+TC-04/);
});

test('UAT script exits 3 when backend stack unavailable (dry run still probes health)', () => {
  const result = runUat({
    LM_API_BASE_URL: 'http://127.0.0.1:9',
    DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:5433/little_minds_ci',
    LM_VERIFY_WITH_DB: '1',
  });
  assert.equal(result.status, 3, result.stdout + result.stderr);
  assert.match(result.stdout + result.stderr, /OVERALL: NOT_RUN/);
  assert.match(result.stdout + result.stderr, /no partial PASS/);
});

test('UAT script lists all mandatory TC rows in summary', () => {
  const result = runUat({
    LM_API_BASE_URL: 'http://127.0.0.1:9',
  });
  const out = result.stdout;
  for (const id of [
    'TC-01 GET /health',
    'TC-02 GET /health/ready',
    'TC-03 Flutter analyze + LMP-134 tests',
    'TC-04 disposable DATABASE_URL guard',
    'TC-05 backend publication unit',
    'TC-06 backend PG ingest',
  ]) {
    assert.match(out, new RegExp(id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
});

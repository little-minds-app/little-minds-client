import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  assertSafeUatDbTarget,
  isAllowedUatDatabaseName,
  Lmp134UatDbGuardError,
  parseDatabaseUrl,
} from '../../scripts/lmp-134-uat-db-guard.mjs';

test('parseDatabaseUrl rejects non-postgres schemes', () => {
  assert.throws(
    () => parseDatabaseUrl('mysql://127.0.0.1/little_minds_test'),
    Lmp134UatDbGuardError,
  );
});

test('isAllowedUatDatabaseName allows test and ci only', () => {
  assert.equal(isAllowedUatDatabaseName('little_minds_test'), true);
  assert.equal(isAllowedUatDatabaseName('little_minds_ci'), true);
  assert.equal(isAllowedUatDatabaseName('little_minds'), false);
  assert.equal(isAllowedUatDatabaseName('little_minds_dev'), false);
  assert.equal(isAllowedUatDatabaseName('little_minds_local'), false);
});

test('assertSafeUatDbTarget rejects bare little_minds UAT database', () => {
  const url = 'postgresql://postgres:postgres@127.0.0.1:5432/little_minds';
  assert.throws(
    () =>
      assertSafeUatDbTarget(url, {
        LM_VERIFY_WITH_DB: '1',
        DATABASE_URL: url,
      }),
    /little_minds_test or little_minds_ci/,
  );
});

test('assertSafeUatDbTarget accepts disposable ci on loopback', () => {
  const url = 'postgresql://postgres:postgres@127.0.0.1:5433/little_minds_ci';
  const target = assertSafeUatDbTarget(url, {
    LM_VERIFY_WITH_DB: '1',
    DATABASE_URL: url,
  });
  assert.equal(target.database, 'little_minds_ci');
  assert.equal(target.host, '127.0.0.1');
});

test('assertSafeUatDbTarget requires LM_VERIFY_WITH_DB=1', () => {
  const url = 'postgresql://postgres:postgres@127.0.0.1:5433/little_minds_test';
  assert.throws(
    () => assertSafeUatDbTarget(url, { DATABASE_URL: url }),
    /LM_VERIFY_WITH_DB=1/,
  );
});

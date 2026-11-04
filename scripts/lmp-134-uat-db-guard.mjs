/**
 * LMP-134 Mac UAT database safety gate (client script).
 * Mirrors backend scripts/verify-db-guard.ts + db-reset-guard URL parsing;
 * stricter disposable names: little_minds_test | little_minds_ci only.
 */

export const LM_VERIFY_WITH_DB = 'LM_VERIFY_WITH_DB';

export const ALLOWED_UAT_DB_HOSTS = new Set([
  '127.0.0.1',
  'localhost',
  '::1',
  '[::1]',
  'postgres',
]);

/** @typedef {{ host: string, port: string | null, database: string }} ParsedDatabaseUrl */

export class Lmp134UatDbGuardError extends Error {
  constructor(message) {
    super(message);
    this.name = 'Lmp134UatDbGuardError';
  }
}

/**
 * @param {string} raw
 * @returns {ParsedDatabaseUrl}
 */
export function parseDatabaseUrl(raw) {
  const trimmed = raw.trim();
  if (!trimmed) {
    throw new Lmp134UatDbGuardError('DATABASE_URL is empty');
  }

  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new Lmp134UatDbGuardError('DATABASE_URL is not a valid URL');
  }

  if (!/^postgres(ql)?:$/i.test(parsed.protocol)) {
    throw new Lmp134UatDbGuardError(
      `Refusing UAT DB: unsupported scheme "${parsed.protocol}" (expected postgres/postgresql)`,
    );
  }

  const host = (parsed.hostname || '').toLowerCase();
  if (!host) {
    throw new Lmp134UatDbGuardError('Refusing UAT DB: DATABASE_URL has no host');
  }

  const path = parsed.pathname.replace(/^\//, '');
  const database = decodeURIComponent(path.split('/')[0] || '');
  if (!database) {
    throw new Lmp134UatDbGuardError('Refusing UAT DB: DATABASE_URL has no database name');
  }

  return {
    host,
    port: parsed.port || null,
    database,
  };
}

/** @param {string} name */
export function isAllowedUatDatabaseName(name) {
  return /^little_minds_(test|ci)$/.test(name);
}

/** @param {string} host */
export function isAllowedUatDbHost(host) {
  return ALLOWED_UAT_DB_HOSTS.has(host.toLowerCase());
}

/**
 * @param {string} databaseUrl
 * @param {Record<string, string | undefined>} [env]
 * @returns {ParsedDatabaseUrl}
 */
export function assertSafeUatDbTarget(databaseUrl, env = process.env) {
  if (env[LM_VERIFY_WITH_DB] !== '1') {
    throw new Lmp134UatDbGuardError(
      `Refusing UAT database integration: set ${LM_VERIFY_WITH_DB}=1 before migrate/seed.`,
    );
  }

  const target = parseDatabaseUrl(databaseUrl);

  if (!isAllowedUatDbHost(target.host)) {
    throw new Lmp134UatDbGuardError(
      `Refusing UAT DB: host "${target.host}" is not an allowlisted loopback/compose host.`,
    );
  }

  if (!isAllowedUatDatabaseName(target.database)) {
    throw new Lmp134UatDbGuardError(
      `Refusing UAT DB: database "${target.database}" must be little_minds_test or little_minds_ci ` +
        '(never bare little_minds UAT/dev volumes).',
    );
  }

  return target;
}

function main() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('DATABASE_URL is required when LM_VERIFY_WITH_DB=1');
    process.exit(1);
  }
  try {
    const target = assertSafeUatDbTarget(url, process.env);
    console.log(JSON.stringify({ ok: true, host: target.host, database: target.database }));
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Refusing UAT DB: unknown guard error';
    console.error(message);
    process.exit(1);
  }
}

import { fileURLToPath } from 'node:url';

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}

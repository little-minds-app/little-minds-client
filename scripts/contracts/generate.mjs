#!/usr/bin/env node
/**
 * Deterministic OpenAPI → TypeScript + Dart client generation.
 * Outputs under generated/; CI regenerates and fails on drift.
 */
import { spawnSync } from 'node:child_process';
import { mkdirSync, rmSync, unlinkSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import {
  GENERATED_DART_DIR,
  GENERATED_TS_DIR,
  OPENAPI_PATH,
  ROOT,
  readPin,
  readVersion,
} from './lib.mjs';

function run(command, args, opts = {}) {
  const result = spawnSync(command, args, {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    ...opts,
  });
  if (result.status !== 0) {
    const detail = [result.stdout, result.stderr].filter(Boolean).join('\n');
    throw new Error(
      `${command} ${args.join(' ')} failed (exit ${result.status})\n${detail}`,
    );
  }
  return result;
}

function removeIfExists(path) {
  if (existsSync(path)) {
    unlinkSync(path);
  }
}

function generateTypeScript() {
  rmSync(GENERATED_TS_DIR, { recursive: true, force: true });
  mkdirSync(GENERATED_TS_DIR, { recursive: true });

  const outFile = join(GENERATED_TS_DIR, 'schema.ts');
  run('npx', [
    '--no-install',
    'openapi-typescript',
    OPENAPI_PATH,
    '-o',
    outFile,
  ]);

  const pin = readPin();
  writeFileSync(
    join(GENERATED_TS_DIR, 'README.md'),
    [
      '# Generated TypeScript types',
      '',
      'Produced by `openapi-typescript` from the vendored `contracts/openapi.yaml`.',
      'Do not edit by hand. Regenerate with `npm run contracts:generate`.',
      '',
      `Contract version: ${readVersion()}`,
      `Backend pin: ${pin.backendRepository}@${pin.backendCommitSha}`,
      `Artifact: ${pin.artifactPath}`,
      '',
    ].join('\n'),
    'utf8',
  );
}

function generateDart() {
  rmSync(GENERATED_DART_DIR, { recursive: true, force: true });
  mkdirSync(GENERATED_DART_DIR, { recursive: true });

  run('npx', [
    '--no-install',
    '@openapitools/openapi-generator-cli',
    'generate',
    '-i',
    OPENAPI_PATH,
    '-g',
    'dart',
    '-o',
    GENERATED_DART_DIR,
    '--additional-properties=pubName=little_minds_api,pubVersion=' +
      readVersion() +
      ',useEnumExtension=true',
  ]);

  removeIfExists(join(GENERATED_DART_DIR, '.travis.yml'));
  removeIfExists(join(GENERATED_DART_DIR, 'git_push.sh'));

  const pin = readPin();
  writeFileSync(
    join(GENERATED_DART_DIR, 'GENERATED.md'),
    [
      '# Generated Dart client',
      '',
      'Produced by `openapi-generator` (`dart`) from the vendored `contracts/openapi.yaml`.',
      'Do not edit by hand. Regenerate with `npm run contracts:generate`.',
      '',
      `Contract version: ${readVersion()}`,
      `Backend pin: ${pin.backendRepository}@${pin.backendCommitSha}`,
      `Artifact: ${pin.artifactPath}`,
      '',
      'Apps should depend on this package via a path dependency when product',
      'features need the API client. LMP-23 ships generation infrastructure only.',
      '',
    ].join('\n'),
    'utf8',
  );
}

function main() {
  generateTypeScript();
  generateDart();
  console.log(
    `PASS contracts:generate — TypeScript → ${GENERATED_TS_DIR}; Dart → ${GENERATED_DART_DIR}`,
  );
}

try {
  main();
} catch (err) {
  console.error(`FAIL contracts:generate — ${err.message}`);
  process.exit(1);
}

#!/usr/bin/env node
/**
 * Fail on breaking removals (unless major VERSION >= allowBreakingRemovalsFromMajor)
 * and on paths outside the LMP-23 allowlist (prevents invented product APIs).
 */
import { evaluateCompatibility } from './integrity.mjs';
import {
  readCompatibility,
  readOpenApiDocument,
  readVersion,
} from './lib.mjs';

function main() {
  const version = readVersion();
  const baseline = readCompatibility();
  const doc = readOpenApiDocument();
  const errors = evaluateCompatibility({ doc, baseline, version });
  const major = Number(/^(\d+)\./.exec(version)[1]);
  const actualPaths = Object.keys(doc.paths ?? {});

  if (errors.length > 0) {
    console.error('FAIL contracts:compat');
    for (const err of errors) {
      console.error(`  - ${err}`);
    }
    process.exit(1);
  }

  console.log(
    `PASS contracts:compat — version ${version} (major=${major}); ${actualPaths.length} allowed path(s)`,
  );
}

try {
  main();
} catch (err) {
  console.error(`FAIL contracts:compat — ${err.message}`);
  process.exit(1);
}

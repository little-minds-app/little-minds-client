#!/usr/bin/env node
/**
 * Validate contracts/openapi.yaml as a resolvable OpenAPI 3 document
 * and enforce VERSION + pin.json consistency (ADR-014).
 */
import SwaggerParser from '@apidevtools/swagger-parser';
import {
  OPENAPI_PATH,
  readOpenApiDocument,
  readPin,
  readVersion,
} from './lib.mjs';

async function main() {
  const version = readVersion();
  const pin = readPin();
  const doc = readOpenApiDocument();

  if (!pin.backendCommitSha || !/^[0-9a-f]{40}$/i.test(pin.backendCommitSha)) {
    throw new Error(
      `pin.json backendCommitSha must be a 40-char git SHA (got ${pin.backendCommitSha})`,
    );
  }

  if (pin.artifactPath !== 'contracts/openapi.yaml') {
    throw new Error(
      `pin.json artifactPath must be contracts/openapi.yaml (got ${pin.artifactPath})`,
    );
  }

  if (pin.contractVersion !== version) {
    throw new Error(
      `pin.json contractVersion (${pin.contractVersion}) must match contracts/VERSION (${version})`,
    );
  }

  if (!doc.openapi || !String(doc.openapi).startsWith('3.')) {
    throw new Error(`Expected OpenAPI 3.x, got ${String(doc.openapi)}`);
  }

  if (doc.info?.version !== version) {
    throw new Error(
      `OpenAPI info.version (${doc.info?.version}) must match contracts/VERSION (${version})`,
    );
  }

  const api = await SwaggerParser.validate(OPENAPI_PATH);
  const pathCount = Object.keys(api.paths ?? {}).length;
  console.log(
    `PASS contracts:validate — OpenAPI ${api.openapi} "${api.info.title}" v${api.info.version} (${pathCount} path(s)); pin ${pin.backendCommitSha.slice(0, 12)}`,
  );
}

main().catch((err) => {
  console.error(`FAIL contracts:validate — ${err.message}`);
  process.exit(1);
});

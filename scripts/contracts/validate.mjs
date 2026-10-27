#!/usr/bin/env node
/**
 * Validate contracts/openapi.yaml as a resolvable OpenAPI 3 document
 * and enforce VERSION + pin.json + vendored blob SHA consistency (ADR-014 / LMP-27).
 */
import SwaggerParser from '@apidevtools/swagger-parser';
import { assertPinAndArtifactIntegrity } from './integrity.mjs';
import {
  OPENAPI_PATH,
  readOpenApiDocument,
  readOpenApiRaw,
  readPin,
  readVersion,
} from './lib.mjs';

async function main() {
  const version = readVersion();
  const pin = readPin();
  const doc = readOpenApiDocument();
  const openApiRaw = readOpenApiRaw();

  assertPinAndArtifactIntegrity({ pin, version, openApiDoc: doc, openApiRaw });

  const api = await SwaggerParser.validate(OPENAPI_PATH);
  const pathCount = Object.keys(api.paths ?? {}).length;
  console.log(
    `PASS contracts:validate — OpenAPI ${api.openapi} "${api.info.title}" v${api.info.version} (${pathCount} path(s)); pin ${pin.backendCommitSha.slice(0, 12)}; blob ${pin.artifactBlobSha.slice(0, 12)}`,
  );
}

main().catch((err) => {
  console.error(`FAIL contracts:validate — ${err.message}`);
  process.exit(1);
});

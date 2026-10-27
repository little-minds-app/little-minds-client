/**
 * Pin ↔ vendored OpenAPI ↔ generated-client integrity helpers (LMP-27).
 * Pure checks so unit tests can exercise positive and negative paths without
 * mutating the working tree.
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/** Git blob object SHA-1 for file contents (matches `git hash-object`). */
export function gitBlobShaFromBuffer(buf) {
  const header = Buffer.from(`blob ${buf.length}\0`, 'utf8');
  return createHash('sha1').update(header).update(buf).digest('hex');
}

export function gitBlobShaFromFile(filePath) {
  return gitBlobShaFromBuffer(readFileSync(filePath));
}

/**
 * Throws if pin metadata, VERSION, OpenAPI info.version, or vendored blob SHA diverge.
 */
export function assertPinAndArtifactIntegrity({
  pin,
  version,
  openApiDoc,
  openApiRaw,
}) {
  if (!pin || typeof pin !== 'object') {
    throw new Error('pin.json must be an object');
  }

  if (!pin.backendCommitSha || !/^[0-9a-f]{40}$/i.test(pin.backendCommitSha)) {
    throw new Error(
      `pin.json backendCommitSha must be a 40-char git SHA (got ${pin.backendCommitSha})`,
    );
  }

  if (String(pin.backendCommitSha).toLowerCase() === 'main') {
    throw new Error('pin.json must not use floating main');
  }

  if (pin.artifactPath !== 'contracts/openapi.yaml') {
    throw new Error(
      `pin.json artifactPath must be contracts/openapi.yaml (got ${pin.artifactPath})`,
    );
  }

  if (!pin.artifactBlobSha || !/^[0-9a-f]{40}$/i.test(pin.artifactBlobSha)) {
    throw new Error(
      `pin.json artifactBlobSha must be a 40-char git blob SHA (got ${pin.artifactBlobSha})`,
    );
  }

  if (pin.contractVersion !== version) {
    throw new Error(
      `pin.json contractVersion (${pin.contractVersion}) must match contracts/VERSION (${version})`,
    );
  }

  if (!openApiDoc?.openapi || !String(openApiDoc.openapi).startsWith('3.')) {
    throw new Error(`Expected OpenAPI 3.x, got ${String(openApiDoc?.openapi)}`);
  }

  if (openApiDoc.info?.version !== version) {
    throw new Error(
      `OpenAPI info.version (${openApiDoc.info?.version}) must match contracts/VERSION (${version})`,
    );
  }

  const actualBlob = gitBlobShaFromBuffer(
    Buffer.isBuffer(openApiRaw) ? openApiRaw : Buffer.from(openApiRaw, 'utf8'),
  );
  if (actualBlob.toLowerCase() !== String(pin.artifactBlobSha).toLowerCase()) {
    throw new Error(
      `Vendored OpenAPI blob SHA (${actualBlob}) must match pin.json artifactBlobSha (${pin.artifactBlobSha})`,
    );
  }
}

/**
 * Returns error strings for allowlist / required-field compatibility (empty = pass).
 * Mirrors scripts/contracts/check-compatibility.mjs without process.exit.
 */
export function evaluateCompatibility({ doc, baseline, version }) {
  const errors = [];
  const majorMatch = /^(\d+)\./.exec(version);
  if (!majorMatch) {
    throw new Error(`Invalid semver in contracts/VERSION: ${version}`);
  }
  const major = Number(majorMatch[1]);
  const allowBreak = major >= baseline.allowBreakingRemovalsFromMajor;

  function resolveSchema(refOrSchema) {
    if (refOrSchema && typeof refOrSchema === 'object' && !refOrSchema.$ref) {
      return refOrSchema;
    }
    const ref = refOrSchema?.$ref ?? refOrSchema;
    if (typeof ref !== 'string' || !ref.startsWith('#/components/schemas/')) {
      throw new Error(`Unsupported schema ref: ${JSON.stringify(refOrSchema)}`);
    }
    const name = ref.slice('#/components/schemas/'.length);
    const schema = doc.components?.schemas?.[name];
    if (!schema) {
      throw new Error(`Missing schema component: ${name}`);
    }
    return schema;
  }

  const actualPaths = Object.keys(doc.paths ?? {}).sort();
  const allowed = new Set(baseline.allowedPaths);

  for (const path of actualPaths) {
    if (!allowed.has(path)) {
      errors.push(
        `Path outside LMP-23 allowlist (do not invent product APIs): ${path}`,
      );
    }
  }

  for (const op of baseline.requiredOperations) {
    const item = doc.paths?.[op.path];
    if (!item) {
      if (!allowBreak) {
        errors.push(`Missing required path: ${op.path}`);
      }
      continue;
    }
    const operation = item[op.method];
    if (!operation) {
      if (!allowBreak) {
        errors.push(
          `Missing required operation: ${op.method.toUpperCase()} ${op.path}`,
        );
      }
      continue;
    }
    if (operation.operationId !== op.operationId) {
      errors.push(
        `operationId mismatch for ${op.method.toUpperCase()} ${op.path}: expected ${op.operationId}, got ${operation.operationId}`,
      );
    }
    const response = operation.responses?.[op.responseStatus];
    if (!response) {
      if (!allowBreak) {
        errors.push(
          `Missing response ${op.responseStatus} on ${op.method.toUpperCase()} ${op.path}`,
        );
      }
      continue;
    }
    const media = response.content?.['application/json'];
    if (!media?.schema) {
      errors.push(
        `Missing application/json schema on ${op.method.toUpperCase()} ${op.path} ${op.responseStatus}`,
      );
      continue;
    }
    const schema = resolveSchema(media.schema);
    const required = new Set(schema.required ?? []);
    for (const prop of op.requiredProperties) {
      if (!required.has(prop) && !allowBreak) {
        errors.push(
          `Breaking: required property "${prop}" missing on ${op.path} response schema`,
        );
      }
      if (!schema.properties?.[prop]) {
        errors.push(`Missing property "${prop}" on ${op.path} response schema`);
      }
    }
  }

  for (const [name, expected] of Object.entries(baseline.requiredSchemas)) {
    const schema = doc.components?.schemas?.[name];
    if (!schema) {
      if (!allowBreak) {
        errors.push(`Missing required schema: ${name}`);
      }
      continue;
    }
    const required = new Set(schema.required ?? []);
    for (const prop of expected.required) {
      if (!required.has(prop) && !allowBreak) {
        errors.push(`Breaking: schema ${name} missing required "${prop}"`);
      }
    }
    for (const [prop, constraint] of Object.entries(expected.properties)) {
      const actual = schema.properties?.[prop];
      if (!actual) {
        errors.push(`Schema ${name} missing property "${prop}"`);
        continue;
      }
      if (constraint.enum) {
        const actualEnum = actual.enum ?? [];
        for (const value of constraint.enum) {
          if (!actualEnum.includes(value)) {
            errors.push(
              `Schema ${name}.${prop} enum missing value "${value}"`,
            );
          }
        }
      }
      if (constraint.type && actual.type !== constraint.type) {
        errors.push(
          `Schema ${name}.${prop} type expected ${constraint.type}, got ${actual.type}`,
        );
      }
      if (constraint.format && actual.format !== constraint.format) {
        errors.push(
          `Schema ${name}.${prop} format expected ${constraint.format}, got ${actual.format}`,
        );
      }
    }
  }

  return errors;
}

/** Paths that must exist for committed generated clients (pre-generate gate in tests). */
export function requiredGeneratedPaths(root) {
  return [
    join(root, 'generated', 'typescript', 'schema.ts'),
    join(root, 'generated', 'typescript', 'README.md'),
    join(root, 'generated', 'dart', 'pubspec.yaml'),
    join(root, 'generated', 'dart', 'GENERATED.md'),
    join(root, 'generated', 'dart', 'lib', 'api.dart'),
  ];
}

export function assertGeneratedClientsPresent(root) {
  const missing = requiredGeneratedPaths(root).filter((p) => !existsSync(p));
  if (missing.length > 0) {
    throw new Error(
      `Missing generated client output:\n${missing.map((p) => `  - ${p}`).join('\n')}`,
    );
  }
}

export function assertGeneratedPinMetadata({ root, pin, version }) {
  const tsReadme = readFileSync(
    join(root, 'generated', 'typescript', 'README.md'),
    'utf8',
  );
  const dartMeta = readFileSync(
    join(root, 'generated', 'dart', 'GENERATED.md'),
    'utf8',
  );
  const pinLine = `${pin.backendRepository}@${pin.backendCommitSha}`;
  for (const [label, text] of [
    ['generated/typescript/README.md', tsReadme],
    ['generated/dart/GENERATED.md', dartMeta],
  ]) {
    if (!text.includes(pinLine)) {
      throw new Error(`${label} missing backend pin line: ${pinLine}`);
    }
    if (!text.includes(`Contract version: ${version}`)) {
      throw new Error(`${label} missing Contract version: ${version}`);
    }
  }
}

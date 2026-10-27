import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse as parseYaml } from 'yaml';

const __dirname = dirname(fileURLToPath(import.meta.url));
export const ROOT = join(__dirname, '..', '..');
export const OPENAPI_PATH = join(ROOT, 'contracts', 'openapi.yaml');
export const VERSION_PATH = join(ROOT, 'contracts', 'VERSION');
export const PIN_PATH = join(ROOT, 'contracts', 'pin.json');
export const COMPAT_PATH = join(
  ROOT,
  'contracts',
  'compatibility',
  'required-contract.json',
);
export const GENERATED_TS_DIR = join(ROOT, 'generated', 'typescript');
export const GENERATED_DART_DIR = join(ROOT, 'generated', 'dart');

export function readVersion() {
  return readFileSync(VERSION_PATH, 'utf8').trim();
}

export function readPin() {
  return JSON.parse(readFileSync(PIN_PATH, 'utf8'));
}

export function readOpenApiRaw() {
  return readFileSync(OPENAPI_PATH);
}

export function readOpenApiDocument() {
  return parseYaml(readOpenApiRaw().toString('utf8'));
}

export function readCompatibility() {
  return JSON.parse(readFileSync(COMPAT_PATH, 'utf8'));
}

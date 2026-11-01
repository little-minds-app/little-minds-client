#!/usr/bin/env bash
# LMP-23/27 client OpenAPI checks: validate (+ blob pin), compatibility, generate, drift.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "=== LMP-23/27 client contract checks ==="

test -f contracts/openapi.yaml
test -f contracts/VERSION
test -f contracts/pin.json
test -f contracts/compatibility/required-contract.json
test -f contracts/README.md

# Offline pin ↔ vendored blob (no live backend clone required).
EXPECTED_BLOB="$(node --input-type=module -e "import { readPin } from './scripts/contracts/lib.mjs'; console.log(readPin().artifactBlobSha);")"
ACTUAL_BLOB="$(git hash-object contracts/openapi.yaml)"
if [[ "$ACTUAL_BLOB" != "$EXPECTED_BLOB" ]]; then
  echo "FAIL contracts:blob — vendored openapi.yaml ($ACTUAL_BLOB) != pin.artifactBlobSha ($EXPECTED_BLOB)"
  exit 1
fi
echo "PASS contracts:blob — vendored OpenAPI matches pin.artifactBlobSha"

npm run contracts:validate
npm run contracts:compat
npm run contracts:generate

if ! git diff --exit-code -- generated >/dev/null; then
  echo "FAIL contracts:drift — generated/ is out of date. Run: npm run contracts:generate"
  git --no-pager diff -- generated | sed -n '1,200p'
  exit 1
fi

if [[ -n "$(git ls-files --others --exclude-standard -- generated)" ]]; then
  echo "FAIL contracts:drift — untracked files under generated/"
  git ls-files --others --exclude-standard -- generated
  exit 1
fi

echo "PASS contracts:drift — generated clients match git"
echo "=== RESULT: PASSED ==="

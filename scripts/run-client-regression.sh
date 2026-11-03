#!/usr/bin/env bash
# LMP-132: single-command client regression runner (contracts, web, Flutter).
# Safe: synthetic fixtures only; does not reset databases or use production credentials.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_CONTRACTS=1
RUN_WEB=1
RUN_FLUTTER=1
RUN_DASHBOARD_UAT=0
SKIP_INSTALL=0

usage() {
  cat <<'EOF'
Usage: bash scripts/run-client-regression.sh [options]

Runs reproducible Little Minds client checks and prints PASS/FAIL per stage.

Options:
  --contracts-only     OpenAPI pin + root contract tests only
  --web-only           apps/web lint, typecheck, test, build
  --flutter-only       apps/mobile flutter analyze + full test suite
  --dashboard-uat      Also run scripts/uat-dashboard.sh (LMP-53/54 subset; no rewrite)
  --skip-install       Skip npm ci / flutter pub get when node_modules/.dart_tool exist
  -h, --help           Show this help

Default: contracts + root npm test + web checks + Flutter analyze + all Flutter tests.

CI note: .github/workflows/ci.yml keeps PR checks fast (contracts + Flutter + web build).
         .github/workflows/lmp25-web-bootstrap.yml runs full web lint/typecheck/test on PRs.
         Optional live smoke: bash scripts/uat-dashboard.sh --live-smoke (requires local stack).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --contracts-only)
      RUN_WEB=0
      RUN_FLUTTER=0
      ;;
    --web-only)
      RUN_CONTRACTS=0
      RUN_FLUTTER=0
      ;;
    --flutter-only)
      RUN_CONTRACTS=0
      RUN_WEB=0
      ;;
    --dashboard-uat)
      RUN_DASHBOARD_UAT=1
      ;;
    --skip-install)
      SKIP_INSTALL=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

echo "== LMP-132 client regression =="
echo "Repository: little-minds-client"
echo "Branch: $(git -C "$ROOT" branch --show-current)"
echo "Commit: $(git -C "$ROOT" rev-parse HEAD)"

stage_pass() { echo ">> $1: PASS"; }
stage_fail() { echo ">> $1: FAIL" >&2; exit 1; }

if [[ "$RUN_CONTRACTS" -eq 1 ]]; then
  echo "== Stage: OpenAPI contracts =="
  (
    cd "$ROOT"
    if [[ "$SKIP_INSTALL" -eq 0 || ! -d node_modules ]]; then
      npm ci --no-audit --no-fund
    fi
    npm run contracts:check
    npm test
  ) && stage_pass "contracts" || stage_fail "contracts"
fi

if [[ "$RUN_WEB" -eq 1 ]]; then
  echo "== Stage: Next.js parent web =="
  (
    cd "$ROOT/apps/web"
    if [[ "$SKIP_INSTALL" -eq 0 || ! -d node_modules ]]; then
      npm ci --no-audit --no-fund
    fi
    npm run lint
    npm run typecheck
    npm run build
    npm test
  ) && stage_pass "web" || stage_fail "web"
fi

if [[ "$RUN_FLUTTER" -eq 1 ]]; then
  echo "== Stage: Flutter mobile =="
  (
    cd "$ROOT/apps/mobile"
    flutter pub get
    flutter analyze
    flutter test
  ) && stage_pass "flutter" || stage_fail "flutter"
fi

if [[ "$RUN_DASHBOARD_UAT" -eq 1 ]]; then
  echo "== Stage: LMP-53/54 dashboard UAT runner (delegated) =="
  bash "$ROOT/scripts/uat-dashboard.sh" && stage_pass "dashboard-uat" || stage_fail "dashboard-uat"
fi

echo "LMP-132 client regression: ALL PASS"

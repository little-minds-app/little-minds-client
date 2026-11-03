#!/usr/bin/env bash
# LMP-132: single-command client regression runner (contracts, web, Flutter).
# Safe: synthetic fixtures only; does not reset databases or use production credentials.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_CONTRACTS=1
RUN_WEB=1
RUN_FLUTTER=1
RUN_DASHBOARD_UAT=0
SKIP_INSTALL=0

# stage name -> PASS | FAIL | SKIP
declare -A STAGE_RESULT=()

usage() {
  cat <<'EOF'
Usage: bash scripts/run-client-regression.sh [options]

Runs reproducible Little Minds client checks and prints PASS / FAIL / SKIP per stage.

Stages (default: contracts + web + flutter):
  contracts      npm ci (optional), contracts:check, root npm test
  web            apps/web lint, typecheck, build, test
  flutter        apps/mobile pub get, analyze, test
  dashboard-uat  Only with --dashboard-uat → scripts/uat-dashboard.sh (LMP-53/54)

Where stages run in GitHub Actions (this script is the full local superset):

  Stage          | Full runner | ci.yml                    | lmp25-web-bootstrap.yml
  ---------------|-------------|---------------------------|---------------------------
  LMP-19 docs    | SKIP        | ci-smoke-test             | —
  contracts      | yes         | contract-checks job       | —
  flutter        | yes         | flutter-check job         | —
  web build      | yes (web)   | nextjs-check (build only) | yes (before test)
  web lint       | yes (web)   | —                         | yes
  web typecheck  | yes (web)   | —                         | yes
  web test       | yes (web)   | —                         | yes
  dashboard-uat  | optional    | —                         | —

Not run in any client GHA job: dashboard-uat, uat-dashboard.sh --live-smoke,
LMP-51 opt-in HTTP integration (flutter test tag/env). Real Postgres persistence
and backend verify:local migrate/seed live in little-minds-backend (see
docs/lmp-132-coverage-matrix.md).

Options:
  --contracts-only     Run contracts stage only
  --web-only           Run web stage only
  --flutter-only       Run flutter stage only
  --dashboard-uat      Also run dashboard-uat stage
  --skip-install       Skip npm ci when node_modules already present
  -h, --help           Show this help
EOF
}

mark_skip() {
  STAGE_RESULT[$1]="SKIP"
}

mark_pass() {
  STAGE_RESULT[$1]="PASS"
}

mark_fail() {
  STAGE_RESULT[$1]="FAIL"
}

run_contracts() {
  echo "== Stage: contracts =="
  (
    cd "$ROOT"
    if [[ "$SKIP_INSTALL" -eq 0 || ! -d node_modules ]]; then
      npm ci --no-audit --no-fund
    fi
    npm run contracts:check
    npm test
  )
}

run_web() {
  echo "== Stage: web =="
  (
    cd "$ROOT/apps/web"
    if [[ "$SKIP_INSTALL" -eq 0 || ! -d node_modules ]]; then
      npm ci --no-audit --no-fund
    fi
    npm run lint
    npm run typecheck
    npm run build
    npm test
  )
}

run_flutter() {
  echo "== Stage: flutter =="
  if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter: not found on PATH (install Flutter or use CI for this stage)" >&2
    return 127
  fi
  (
    cd "$ROOT/apps/mobile"
    flutter pub get
    flutter analyze
    flutter test
  )
}

run_dashboard_uat() {
  echo "== Stage: dashboard-uat (delegated uat-dashboard.sh) =="
  bash "$ROOT/scripts/uat-dashboard.sh"
}

execute_stage() {
  local name=$1
  shift
  if "$@"; then
    mark_pass "$name"
    echo ">> stage $name: PASS"
  else
    mark_fail "$name"
    echo ">> stage $name: FAIL" >&2
  fi
}

print_summary() {
  echo ""
  echo "== LMP-132 stage summary =="
  local order=(contracts web flutter dashboard-uat)
  local any_fail=0
  for name in "${order[@]}"; do
    local status="${STAGE_RESULT[$name]:-SKIP}"
    printf '  %-16s %s\n' "$name" "$status"
    if [[ "$status" == "FAIL" ]]; then
      any_fail=1
    fi
  done
  echo ""
  if [[ "$any_fail" -eq 1 ]]; then
    echo "LMP-132 client regression: FAILED (see stages above)"
    return 1
  fi
  echo "LMP-132 client regression: ALL PASS (skipped stages omitted or not selected)"
  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --contracts-only)
      RUN_WEB=0
      RUN_FLUTTER=0
      RUN_DASHBOARD_UAT=0
      ;;
    --web-only)
      RUN_CONTRACTS=0
      RUN_FLUTTER=0
      RUN_DASHBOARD_UAT=0
      ;;
    --flutter-only)
      RUN_CONTRACTS=0
      RUN_WEB=0
      RUN_DASHBOARD_UAT=0
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

if [[ "$RUN_CONTRACTS" -eq 1 ]]; then
  execute_stage contracts run_contracts
else
  mark_skip contracts
  echo ">> stage contracts: SKIP (not selected)"
fi

if [[ "$RUN_WEB" -eq 1 ]]; then
  execute_stage web run_web
else
  mark_skip web
  echo ">> stage web: SKIP (not selected)"
fi

if [[ "$RUN_FLUTTER" -eq 1 ]]; then
  execute_stage flutter run_flutter
else
  mark_skip flutter
  echo ">> stage flutter: SKIP (not selected)"
fi

if [[ "$RUN_DASHBOARD_UAT" -eq 1 ]]; then
  execute_stage dashboard-uat run_dashboard_uat
else
  mark_skip dashboard-uat
  echo ">> stage dashboard-uat: SKIP (pass --dashboard-uat to enable)"
fi

print_summary
exit $?

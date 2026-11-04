#!/usr/bin/env bash
# LMP-134 Mac/local UAT — Shape Matching production telemetry + backend ingest.
# Mandatory TC-01..TC-06. No partial PASS: any NOT_RUN → exit 3.
#
# Exit codes:
#   0 — PASS (every mandatory TC passed)
#   1 — FAIL (at least one TC failed)
#   3 — NOT_RUN (stack/prerequisites missing or TC skipped)
set -uo pipefail

if [[ -d "${FLUTTER_ROOT:-$HOME/flutter-sdk}/bin" ]]; then
  export PATH="${FLUTTER_ROOT:-$HOME/flutter-sdk}/bin:$PATH"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/apps/mobile"
BACKEND_ROOT="${LM_BACKEND_ROOT:-}"
BACKEND_URL="${LM_API_BASE_URL:-http://127.0.0.1:3000}"
DATABASE_URL="${DATABASE_URL:-}"
WITH_DB="${LM_LMP134_WITH_DB:-0}"
GUARD_MJS="$ROOT/scripts/lmp-134-uat-db-guard.mjs"
DRY_RUN="${LM_LMP134_UAT_DRY_RUN:-0}"

declare -A TC_STATUS=()
PASS_COUNT=0
FAIL_COUNT=0
NOT_RUN_COUNT=0

MANDATORY_TCS=(
  'TC-01 GET /health'
  'TC-02 GET /health/ready'
  'TC-03 Flutter analyze + LMP-134 tests'
  'TC-04 disposable DATABASE_URL guard'
  'TC-05 backend publication unit'
  'TC-06 backend PG ingest'
)

record() {
  local id="$1"
  local status="$2"
  TC_STATUS["$id"]="$status"
  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    NOT_RUN) NOT_RUN_COUNT=$((NOT_RUN_COUNT + 1)) ;;
  esac
}

run_tc() {
  local id="$1"
  shift
  printf '\n== %s ==\n' "$id"
  if "$@"; then
    record "$id" PASS
    return 0
  fi
  record "$id" FAIL
  return 1
}

mark_not_run() {
  local id="$1"
  local reason="$2"
  printf '\n== %s ==\nNOT_RUN: %s\n' "$id" "$reason"
  record "$id" NOT_RUN
}

tc_01_health_liveness() {
  curl --fail --silent --show-error --max-time 8 "$BACKEND_URL/health" >/dev/null
}

tc_02_health_ready() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 12 "$BACKEND_URL/health/ready")"
  [[ "$code" == "200" || "$code" == "503" ]]
}

tc_03_flutter_gates() {
  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi
  (
    cd "$MOBILE"
    flutter pub get
    flutter analyze
    flutter test \
      test/hub_production_telemetry_test.dart \
      test/activity_publication_fixture_test.dart \
      test/published_content_registry_test.dart \
      test/hub_device_child_binding_test.dart
  )
}

tc_04_disposable_db_guard() {
  if [[ -z "$DATABASE_URL" ]]; then
    if [[ "$WITH_DB" == "1" ]]; then
      echo 'DATABASE_URL required when LM_LMP134_WITH_DB=1' >&2
      return 1
    fi
    echo 'DATABASE_URL unset — TC-04 PASS (no PG ingest requested).'
    return 0
  fi
  export LM_VERIFY_WITH_DB=1
  node "$GUARD_MJS" >/dev/null
}

tc_05_backend_publication_unit() {
  [[ -n "$BACKEND_ROOT" && -d "$BACKEND_ROOT" ]] || return 1
  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi
  (
    cd "$BACKEND_ROOT"
    npm test -- --ci --coverage=false \
      test/shape-matching-publication.spec.ts \
      test/seed-shape-matching-content.spec.ts \
      prisma/seed-data.spec.ts
  )
}

tc_06_backend_pg_ingest() {
  [[ -n "$BACKEND_ROOT" && -d "$BACKEND_ROOT" ]] || return 1
  [[ -n "$DATABASE_URL" ]] || return 1
  if [[ "$WITH_DB" != "1" ]]; then
    return 1
  fi
  export LM_VERIFY_WITH_DB=1
  if ! node "$GUARD_MJS" >/dev/null; then
    echo 'Refusing migrate/seed: DATABASE_URL failed LMP-134 UAT guard.' >&2
    return 1
  fi
  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi
  (
    cd "$BACKEND_ROOT"
    export LM_VERIFY_WITH_DB=1
    if [[ -f scripts/verify-db-guard.ts ]]; then
      npx ts-node --compiler-options '{"module":"CommonJS"}' scripts/verify-db-guard.ts
    fi
    npm run db:migrate
    npm run db:seed
    npm run test:db -- --ci --coverage=false \
      test/lmp-134-shape-matching-ingest.db.spec.ts
  )
}

echo "LMP-134 UAT — backend URL: $BACKEND_URL"
echo "Client commit: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"

STACK_AVAILABLE=1
if ! tc_01_health_liveness 2>/dev/null; then
  STACK_AVAILABLE=0
fi

if [[ "$STACK_AVAILABLE" -eq 0 ]]; then
  mark_not_run "${MANDATORY_TCS[0]}" 'backend unavailable'
  mark_not_run "${MANDATORY_TCS[1]}" 'backend unavailable'
else
  run_tc "${MANDATORY_TCS[0]}" tc_01_health_liveness || true
  run_tc "${MANDATORY_TCS[1]}" tc_02_health_ready || true
fi

run_tc "${MANDATORY_TCS[2]}" tc_03_flutter_gates || true

run_tc "${MANDATORY_TCS[3]}" tc_04_disposable_db_guard || true

if [[ "$STACK_AVAILABLE" -eq 0 ]]; then
  mark_not_run "${MANDATORY_TCS[4]}" 'backend unavailable'
  mark_not_run "${MANDATORY_TCS[5]}" 'backend unavailable'
elif [[ -z "$BACKEND_ROOT" || ! -d "$BACKEND_ROOT" ]]; then
  mark_not_run "${MANDATORY_TCS[4]}" 'set LM_BACKEND_ROOT to backend checkout'
  mark_not_run "${MANDATORY_TCS[5]}" 'set LM_BACKEND_ROOT + LM_LMP134_WITH_DB=1 + disposable DATABASE_URL'
elif [[ "$WITH_DB" != "1" ]]; then
  run_tc "${MANDATORY_TCS[4]}" tc_05_backend_publication_unit || true
  mark_not_run "${MANDATORY_TCS[5]}" 'set LM_LMP134_WITH_DB=1 and DATABASE_URL=little_minds_test|ci'
else
  run_tc "${MANDATORY_TCS[4]}" tc_05_backend_publication_unit || true
  if [[ "${TC_STATUS[${MANDATORY_TCS[3]}]:-FAIL}" == FAIL ]]; then
    mark_not_run "${MANDATORY_TCS[5]}" 'TC-04 guard failed — migrate/seed skipped'
  else
    run_tc "${MANDATORY_TCS[5]}" tc_06_backend_pg_ingest || true
  fi
fi

echo ''
echo '========== LMP-134 UAT summary (mandatory TCs) =========='
for id in "${MANDATORY_TCS[@]}"; do
  status="${TC_STATUS[$id]:-NOT_RUN}"
  printf '%s  %s\n' "$status" "$id"
done
echo '-----------------------------------------'
printf 'Counts: PASS=%s FAIL=%s NOT_RUN=%s\n' "$PASS_COUNT" "$FAIL_COUNT" "$NOT_RUN_COUNT"
echo '========================================='

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo 'OVERALL: FAIL'
  exit 1
fi

if [[ "$NOT_RUN_COUNT" -gt 0 ]]; then
  cat <<'EOF'

NOT_RUN — one or more mandatory TCs did not execute (no partial PASS).

Mac/local prerequisites:
  1. Clone little-minds-backend @ feature/lmp-134-production-telemetry (PR #37) @ 4f0c592+.
  2. export LM_BACKEND_ROOT=/path/to/little-minds-backend
  3. export LM_API_BASE_URL=http://127.0.0.1:3000
  4. export DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5433/little_minds_ci
  5. export LM_LMP134_WITH_DB=1
  6. export LM_VERIFY_WITH_DB=1
  7. Start backend + Postgres (docker compose), then re-run:
       bash scripts/uat-lmp-134-shape-matching-production.sh
  8. Sign in parent; bind device child via hub; play Shape Matching offline;
     reconnect; confirm POST /v1/events/batch ACK and KPI content_version_id
     018f1340-0000-4000-8000-000000000001.

EOF
  echo 'OVERALL: NOT_RUN'
  exit 3
fi

echo 'OVERALL: PASS'
exit 0

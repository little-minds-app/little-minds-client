#!/usr/bin/env bash
# LMP-134 Mac/local UAT — Shape Matching production telemetry + backend ingest.
# Safe: refuses non-disposable DATABASE_URL (never wipes little_minds UAT).
#
# Exit codes:
#   0 — PASS (all executed TCs passed)
#   1 — FAIL (at least one executed TC failed)
#   3 — NOT_RUN (required stack unavailable; see summary + manual steps)
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

declare -a TC_RESULT=()
PASS_COUNT=0
FAIL_COUNT=0
NOT_RUN_COUNT=0

record() {
  local status="$1"
  local name="$2"
  TC_RESULT+=("$status  $name")
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
    record PASS "$id"
    return 0
  fi
  record FAIL "$id"
  return 1
}

tc_01_health_liveness() {
  curl --fail --silent --show-error --max-time 8 "$BACKEND_URL/health" >/dev/null
}

tc_02_health_ready() {
  curl --fail --silent --show-error --max-time 12 "$BACKEND_URL/health/ready" >/dev/null
}

tc_03_flutter_gates() {
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
    echo "DATABASE_URL unset — PG ingest TCs will NOT_RUN (expected without --with-db)."
    return 0
  fi
  if [[ "$DATABASE_URL" =~ /little_minds(\?|$|/) ]] &&
     [[ ! "$DATABASE_URL" =~ /little_minds_(test|ci|local|dev)(/|\?|$) ]]; then
    echo "REFUSED: DATABASE_URL must target little_minds_test|ci|local|dev — not little_minds UAT." >&2
    return 1
  fi
  return 0
}

tc_05_backend_publication_unit() {
  [[ -n "$BACKEND_ROOT" && -d "$BACKEND_ROOT" ]] || return 1
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
  (
    cd "$BACKEND_ROOT"
    export LM_VERIFY_WITH_DB=1
    npx ts-node --compiler-options '{"module":"CommonJS"}' scripts/verify-db-guard.ts
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
  record NOT_RUN "TC-01 GET /health (backend unavailable)"
  record NOT_RUN "TC-02 GET /health/ready (backend unavailable)"
else
  run_tc "TC-01 GET /health" tc_01_health_liveness || true
  run_tc "TC-02 GET /health/ready" tc_02_health_ready || true
fi

run_tc "TC-03 Flutter analyze + LMP-134 tests" tc_03_flutter_gates || true

if [[ "$STACK_AVAILABLE" -eq 0 ]]; then
  record NOT_RUN "TC-04 disposable DATABASE_URL guard (backend unavailable)"
else
  run_tc "TC-04 disposable DATABASE_URL guard" tc_04_disposable_db_guard || true
fi

if [[ "$STACK_AVAILABLE" -eq 0 ]]; then
  record NOT_RUN "TC-05 backend publication unit (backend unavailable)"
  record NOT_RUN "TC-06 backend PG ingest (backend unavailable)"
elif [[ -z "$BACKEND_ROOT" || ! -d "$BACKEND_ROOT" ]]; then
  record NOT_RUN "TC-05 backend publication unit (set LM_BACKEND_ROOT)"
  record NOT_RUN "TC-06 backend PG ingest (set LM_BACKEND_ROOT + DATABASE_URL)"
elif [[ "$WITH_DB" != "1" && -z "$DATABASE_URL" ]]; then
  if run_tc "TC-05 backend publication unit" tc_05_backend_publication_unit; then
    :
  else
    :
  fi
  record NOT_RUN "TC-06 backend PG ingest (set LM_LMP134_WITH_DB=1 and disposable DATABASE_URL)"
else
  run_tc "TC-05 backend publication unit" tc_05_backend_publication_unit || true
  run_tc "TC-06 backend PG ingest" tc_06_backend_pg_ingest || true
fi

echo ''
echo '========== LMP-134 UAT summary =========='
for line in "${TC_RESULT[@]}"; do
  echo "$line"
done
echo '-----------------------------------------'
printf 'Counts: PASS=%s FAIL=%s NOT_RUN=%s\n' "$PASS_COUNT" "$FAIL_COUNT" "$NOT_RUN_COUNT"
echo '========================================='

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo 'OVERALL: FAIL'
  exit 1
fi

if [[ "$STACK_AVAILABLE" -eq 0 ]]; then
  cat <<'EOF'

NOT_RUN — live stack unavailable on this host.

Mac/local manual steps:
  1. Clone little-minds-backend @ feature/lmp-134-production-telemetry (PR #37).
  2. export LM_BACKEND_ROOT=/path/to/little-minds-backend
  3. export LM_API_BASE_URL=http://127.0.0.1:3000
  4. export DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5433/little_minds_ci
  5. export LM_LMP134_WITH_DB=1
  6. Start backend + Postgres (docker compose), then re-run:
       bash scripts/uat-lmp-134-shape-matching-production.sh
  7. Sign in parent; bind device child via hub; play Shape Matching offline;
     reconnect; confirm POST /v1/events/batch ACK and KPI content_version_id
     018f1340-0000-4000-8000-000000000001.

EOF
  echo 'OVERALL: NOT_RUN'
  exit 3
fi

if [[ "$NOT_RUN_COUNT" -gt 0 ]]; then
  echo 'OVERALL: PASS (partial — some TCs NOT_RUN; see Mac steps above for full E2E)'
  exit 0
fi

echo 'OVERALL: PASS'
exit 0

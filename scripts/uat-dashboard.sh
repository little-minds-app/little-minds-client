#!/usr/bin/env bash
# LMP-53 + LMP-54 automated functional UAT regression runner.
# Safe: does not reset, seed, migrate, or write to the developer's database.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE_SMOKE="${1:-}"

echo "== LMP-53 / LMP-54: automated regression =="
echo "Client branch: $(git -C "$ROOT" branch --show-current)"
echo "Client commit: $(git -C "$ROOT" rev-parse --short HEAD)"

if [[ "$LIVE_SMOKE" == "--live-smoke" ]]; then
  API_URL="${LM_UAT_API_URL:-http://127.0.0.1:3000}"
  WEB_URL="${LM_UAT_WEB_URL:-http://127.0.0.1:3001}"
  echo "Checking live API health and web routing (no credentials or database writes)..."
  curl --fail --silent --show-error --max-time 8 "$API_URL/health" >/dev/null
  curl --fail --silent --show-error --max-time 8 "$API_URL/health/ready" >/dev/null
  curl --fail --silent --show-error --max-time 8 "$WEB_URL/" >/dev/null
  echo "Live HTTP smoke: PASS"
elif [[ -n "$LIVE_SMOKE" ]]; then
  echo "Usage: bash scripts/uat-dashboard.sh [--live-smoke]" >&2
  exit 2
fi

echo "== Web: lint/typecheck/build + HTTP/component tests =="
(
  cd "$ROOT/apps/web"
  if [[ ! -d node_modules ]]; then
    npm ci --no-audit --no-fund
  fi
  npm run lint
  npm run typecheck
  npm run build
  npm test
)

echo "== Flutter: gate/lifecycle, session KPI, mission, child races, widget UAT =="
(
  cd "$ROOT/apps/mobile"
  flutter pub get
  flutter test \
    test/parent_dashboard_gate_test.dart \
    test/parent_dashboard_controller_test.dart \
    test/parent_dashboard_widget_test.dart \
    test/session_kpi_repository_test.dart \
    test/session_kpi_window_test.dart \
    test/mission_status_repository_test.dart \
    test/mission_status_view_data_test.dart \
    test/parent_gate_boundaries_test.dart
)
echo "LMP-53/54 automated regression: PASS"

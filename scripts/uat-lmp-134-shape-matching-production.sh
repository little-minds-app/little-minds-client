#!/usr/bin/env bash
# LMP-134 Mac/local UAT — Shape Matching production telemetry + backend ingest.
# Requires: little-minds-backend on feature/lmp-134-production-telemetry, PostgreSQL,
# seeded synthetic fixtures, device row with child_id bound to scoped installation id.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/apps/mobile"
BACKEND_URL="${LM_API_BASE_URL:-http://localhost:3000}"
DATABASE_URL="${DATABASE_URL:-}"

echo "LMP-134 UAT — backend URL: $BACKEND_URL"

if ! curl -sf "$BACKEND_URL/health/live" >/dev/null; then
  echo "NOT_RUN: backend health/live unavailable at $BACKEND_URL"
  exit 0
fi

if [[ -z "$DATABASE_URL" ]]; then
  echo "NOT_RUN: set DATABASE_URL to run PostgreSQL ingest verification"
  exit 0
fi

echo "NOT_RUN: automated PG reconnect E2E is not executed in this script."
echo "Manual steps:"
echo "  1. Sign in parent; note installation UUID and parent-scoped device id (client logs / debugger)."
echo "  2. Ensure devices.child_id matches selected hub child in PostgreSQL."
echo "  3. Play Shape Matching offline; reconnect; confirm POST /v1/events/batch ACK."
echo "  4. Verify session KPI includes content_version_id 018f1340-0000-4000-8000-000000000001."

cd "$MOBILE"
flutter analyze
flutter test

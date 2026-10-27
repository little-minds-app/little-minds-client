# little-minds-client

Little Minds mobile app, parent dashboard and content admin.

## Repository layout

| Path | Status |
|---|---|
| `apps/mobile` | Flutter + Flame Kids App bootstrap (LMP-24) |
| `apps/web` | Next.js Parent Web / Content Admin — not bootstrapped yet (LMP-25 / LMP-26) |
| `contracts/` | Vendored OpenAPI pin from backend (LMP-23); never floating `main` |
| `generated/typescript` | Generated TypeScript API types (Parent Dashboard / web) |
| `generated/dart` | Generated Dart API client (Flutter) |
| `docs/` | Product Blueprint, ADR index, device support matrix |

## API contract pin (LMP-23 / ADR-014)

Backend owns OpenAPI. This repo pins a **backend commit SHA** and regenerates clients from the vendored artifact.

| Field | Value |
|---|---|
| Backend | `little-minds-app/little-minds-backend` |
| Pin file | [`contracts/pin.json`](contracts/pin.json) |
| Artifact | `contracts/openapi.yaml` (vendored from pin) |
| Surface | `GET /health` only |

```bash
npm ci
npm run contracts:check   # validate + compat + generate + drift
npm test                  # contract unit tests
```

See [`contracts/README.md`](contracts/README.md). Java 11+ required for Dart generation.

## Mobile (Flutter + Flame)

See [`apps/mobile/README.md`](apps/mobile/README.md) for run instructions, scaffolding assumptions, and Cloud Agent / Linux simulator limits.

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

## CI

`.github/workflows/ci.yml` runs:

- LMP-19 docs smoke checks
- **OpenAPI generated clients** (validate, compatibility, regenerate + drift, Node contract tests)
- Flutter analyze + test when `apps/mobile/pubspec.yaml` exists
- Next.js build when `apps/web` exists

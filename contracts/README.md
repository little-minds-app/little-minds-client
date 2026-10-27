# contracts/ (client pin + vendored OpenAPI)

Backend owns the authoritative OpenAPI document (Blueprint §12.2, ADR-014).  
This client repository **pins** a backend commit and vendors that revision of the artifact for reproducible generation.

## Pin (LMP-23)

| Field | Value |
|---|---|
| File | `contracts/pin.json` |
| Backend repo | `little-minds-app/little-minds-backend` |
| Commit SHA | see `backendCommitSha` in `pin.json` (currently `50862b8d6c3d4126effeaebaf22d34eb675c7f75`) |
| Artifact path | `contracts/openapi.yaml` |
| Contract version | `contracts/VERSION` (must match OpenAPI `info.version`) |

**Never** point generators at floating `main`. Bump the pin deliberately when adopting a new backend contract revision.

## Layout

| Path | Role |
|---|---|
| `pin.json` | Immutable pin metadata (repo + SHA + path + version) |
| `openapi.yaml` | Vendored OpenAPI 3.0.3 from the pinned backend commit |
| `VERSION` | Contract semver |
| `compatibility/required-contract.json` | Allowlist + required fields (breaking removals fail CI) |
| `../generated/typescript/` | TypeScript types (`openapi-typescript`) |
| `../generated/dart/` | Dart client (`openapi-generator` / `dart`) |

**Current surface:** `GET /health` only. Blueprint §15 `/v1/...` routes are **not** invented here.

## Commands

```bash
npm ci
npm run contracts:validate   # OpenAPI parse + VERSION + pin sync
npm run contracts:compat     # Allowlist + required fields / breaking gate
npm run contracts:generate   # Regen TS + Dart under generated/
npm run contracts:check      # validate + compat + generate + git drift
npm test                     # Node contract tests
```

Java 11+ is required for the OpenAPI Generator CLI (Dart).

## Syncing a new pin

1. Choose a backend commit SHA that contains the desired `contracts/openapi.yaml`.
2. Update `contracts/pin.json` (`backendCommitSha`, `contractVersion`).
3. Replace `contracts/openapi.yaml` and `contracts/VERSION` with the files from that SHA (GitHub Contents API / raw at the SHA — never `main`).
4. Run `npm run contracts:check` and commit regenerated `generated/` trees.

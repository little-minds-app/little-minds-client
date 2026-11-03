# contracts/ (client pin + vendored OpenAPI)

Backend owns the authoritative OpenAPI document (Blueprint §12.2, ADR-014).  
This client repository **pins** a backend commit and vendors that revision of the artifact for reproducible generation.

## Pin (LMP-23 / LMP-27)

| Field | Value |
|---|---|
| File | `contracts/pin.json` |
| Backend repo | `little-minds-app/little-minds-backend` |
| Commit SHA | see `backendCommitSha` in `pin.json` (currently `a638e00eeed56e9aacb583d434d05a24e677576f`) |
| Artifact path | `contracts/openapi.yaml` |
| Artifact blob SHA | `artifactBlobSha` — `git hash-object` of the vendored YAML (offline integrity) |
| Contract version | `contracts/VERSION` (must match OpenAPI `info.version`; currently `0.13.0`) |
| Backend PR | see `backendPullRequest` in `pin.json` (LMP-52 → `#32`) |

**Never** point generators at floating `main`. Bump the pin deliberately when adopting a new backend contract revision.

### Cross-repo drift (private backend)

Client GitHub Actions often **cannot** `gh`/clone the private backend. CI therefore verifies:

1. `pin.json` ↔ `contracts/VERSION` ↔ OpenAPI `info.version`
2. Vendored `openapi.yaml` bytes ↔ `pin.artifactBlobSha` (`git hash-object`)
3. Regenerate TypeScript + Dart → `git diff` drift on `generated/`
4. Compatibility allowlist (no invented `/v1/...` routes)
5. Node unit tests including **negative** cases (stale pin, mutated spec, missing generated)

Optional future live check (not required, **do not commit tokens**): a repository secret such as `LM_BACKEND_CONTENTS_TOKEN` held by a GitHub App or fine-scoped PAT with **`contents: read` only** on `little-minds-app/little-minds-backend`, used solely to fetch `artifactPath` at `backendCommitSha` and compare blob SHA. Prefer leaving this opt-in until org policy grants the App.

## Layout

| Path | Role |
|---|---|
| `pin.json` | Immutable pin metadata (repo + SHA + path + version) |
| `openapi.yaml` | Vendored OpenAPI 3.0.3 from the pinned backend commit |
| `VERSION` | Contract semver |
| `compatibility/required-contract.json` | Allowlist + required fields (breaking removals fail CI) |
| `../generated/typescript/` | TypeScript types (`openapi-typescript`) |
| `../generated/dart/` | Dart client (`openapi-generator` / `dart`) |

**Current surface:** Auth, parent/child, activity ingestion and session KPI endpoints (LMP-52).
**LMP-52:** `GET /v1/insights/session-kpis` is included (parent bearer).

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
2. Replace `contracts/openapi.yaml` and `contracts/VERSION` with the files from that SHA (GitHub Contents API / raw at the SHA — never `main`).
3. Update `contracts/pin.json`: `backendCommitSha`, `contractVersion`, and `artifactBlobSha` (`git hash-object contracts/openapi.yaml`).
4. Run `npm run contracts:check` and commit regenerated `generated/` trees.

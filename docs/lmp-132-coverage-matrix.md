# LMP-132 — Delivered-feature regression coverage matrix

**Purpose:** Trace merged Little Minds deliverables to automated tests or documented exceptions (Blueprint §28.9 QA-UI-001).  
**Repo:** `little-minds-client` (client rows are authoritative here; backend cells coordinate with `little-minds-backend` LMP-132 work).  
**Updated:** 2026-11-03 — PR [#35](https://github.com/little-minds-app/little-minds-client/pull/35).

## Legend

| Column | Meaning |
| --- | --- |
| **Backend** | `little-minds-backend` unit / DB / HTTP e2e |
| **Client mobile** | Flutter unit / widget / optional opt-in HTTP integration |
| **Client web** | Next.js BFF route tests, component tests, HTTP session harness (mock backend) |
| **Contract** | Root OpenAPI pin + generated client drift |
| **Live E2E** | Real Postgres + full stack; **LMP-113** owns release vertical E2E |
| **Persistence** | Whether automated tests hit real Postgres (not mocks/BFF doubles) |

**Client test layers:** Most **client web** and **client mobile** dashboard/profile tests use **synthetic fixtures, mocked `fetch`, or fake repositories**. They prove UI/BFF wiring and fail-closed behavior, **not** backend persistence or live authorization across Postgres.

## Boundaries (do not duplicate)

| Item | Handling |
| --- | --- |
| LMP-53/54 UAT automation | Merged client **PR #34** — `scripts/uat-dashboard.sh`, `parent-dashboard-uat.component.test.tsx` |
| Backend LMP-53/54 automation | Merged backend **PR #34** — backend worker; not rewritten in client PR #35 |
| LMP-113 | Full vertical-slice release E2E — coordinate; not backfilled here |
| LMP-114 | Resilience / chaos — coordinate; not duplicated |
| LMP-131 | Dashboard charts / UX — out of scope |
| Backend `verify:local` | Unsafe migrate/seed and Postgres-backed checks live in **backend repo only**; client documents dependency below |

## Runner ↔ CI mapping

| Stage | `run-client-regression.sh` | `.github/workflows/ci.yml` | `.github/workflows/lmp25-web-bootstrap.yml` |
| --- | --- | --- | --- |
| LMP-19 docs smoke | SKIP | `ci-smoke-test` | — |
| contracts (`contracts:check` + root `npm test`) | default | `contract-checks` | — |
| flutter (`analyze` + `test`) | default | `flutter-check` | — |
| web `build` | default (web stage) | `nextjs-check` | yes |
| web `lint` / `typecheck` / `test` | default (web stage) | **not run** | yes |
| `dashboard-uat` / `uat-dashboard.sh` | `--dashboard-uat` only | **not run** | **not run** |
| LMP-51 live HTTP outbox test | **not run** (opt-in env) | **not run** | **not run** |

Full local superset: `bash scripts/run-client-regression.sh` (prints PASS / FAIL / SKIP per stage).

---

## Infrastructure & contracts

| Jira | Deliverable | Backend | Client mobile | Client web | Contract | Live E2E | Persistence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LMP-5 | Client CI smoke | — | — | — | — | — | — | **Covered** — `ci.yml` |
| LMP-19 | Device matrix / ADR docs | Docs scripts | — | — | — | — | — | **Covered** — `check-lmp19-docs.sh` |
| LMP-20–22 | Backend bootstrap, DB, seeds | Jest + `test:db` + e2e | — | — | — | Compose | **Postgres** | **Backend only** |
| LMP-23 | OpenAPI clients | `contracts:check` | Generated dart smoke | — | root `tests/contract/*.test.mjs` | — | — | **Covered (client)** |
| LMP-24 | Flutter shell | — | `shell_widget_test.dart`, `window_size_class_test.dart` | — | — | — | Mock | **Covered (client)** |
| LMP-25 | Next.js shell | — | — | `bootstrap.test.mjs` | — | — | Mock | **Covered (client)** |
| LMP-27 | CI + negative contract | Same | — | — | `openapi.negative.test.mjs` | — | — | **Covered (client)** |
| LMP-28 | Public env config | `config:check` | `app_config_test.dart`, `env_config_widget_test.dart` | — | — | — | Mock | **Covered (client)** |
| LMP-32 | Logging / health | Health e2e | — | — | Pin health paths | — | **Backend** | **Backend** |

---

## Identity, sessions, profiles

| Jira | Deliverable | Backend | Client mobile | Client web | Contract | Live E2E | Persistence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LMP-33 | Parent session lifecycle | `*.spec.ts`, session e2e | — | — | Auth OpenAPI | PG integrity | **Postgres** | **Backend**; BFF mocked on web |
| LMP-34 | GSM OTP | `phone-otp` e2e | — | `http-session.test.mjs` (mock Nest) | OTP schemas | Fake provider | **Mock BFF** | **Client web** behavior only |
| LMP-35 | Apple/Google/email OTP | `multi-provider-oidc.e2e` | — | BFF route units | — | — | **Backend** | **Backend** + partial BFF |
| LMP-36 | Account linking / step-up | `step-up.*`, DB specs | — | — | — | account-linking e2e | **Postgres** | **Backend only** |
| LMP-37 | Mobile parent auth UI | — | `parent_auth_*_test.dart` | — | — | — | Mock | **Covered (client)** |
| LMP-38 | Web auth + opaque session | Web session e2e | — | `http-session.test.mjs` | Web session paths | — | **Mock BFF** | **Client** wiring; persistence **backend** |
| LMP-39 | Child schema / age months | DB + API specs | Types only | — | Schemas | — | **Postgres** | **Backend only** |
| LMP-40 | Child profiles CRUD | API + e2e | `child_profiles_widget_test.dart` | `child-profiles.component.test.tsx` | — | — | **Mock** | **Covered (client UI)** |
| LMP-40 | Stale profile on account switch | — | stale parent widget test | stale child component test | — | — | **Mock** | **Covered (client races)** |
| LMP-41 | Optional parent profile | Profile API | `optional_parent_profile_widget_test.dart` | `http-session.test.mjs` profile | — | — | **Mock BFF** | **Covered (client)** |
| LMP-42 | Parent gate / PIN | Gate API tests | `parent_pin_*`, `parent_gate_*`, `parent_dashboard_gate_test.dart` | — | — | Device UX | Mock + API contract | **Covered** + manual PIN |
| Client PR #25 | Installation id across logout | — | `installation_id_store_test.dart` | — | — | — | In-memory | **Covered (client)** |

---

## Kids Mode, gameplay, mentor, screen time

| Jira | Deliverable | Backend | Client mobile | Client web | Contract | Live E2E | Persistence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LMP-43 | Child Hub | — | `child_hub_widget_test.dart`, `hub_audio_guidance_test.dart` | — | — | Device | Mock | **Covered (client)** |
| LMP-44 | Flame lifecycle | — | `game_lifecycle_*_test.dart` | — | — | — | Mock | **Covered (client)** |
| LMP-45 | Near/Far demo | — | `near_far_*_test.dart` | — | — | TTS device | Mock | **Covered (client)** |
| LMP-46 | Mission handoff / skip | Mission APIs | near_far handoff widgets | — | — | — | Mock | **Covered (mobile)** |
| LMP-47 | Mentor card schema | Schema tests | `mentor_card_*_test.dart` | — | OpenAPI | — | — | **Covered (client)** |
| LMP-48 | Mentor card UI | — | `near_far_mentor_widget_test.dart` | — | — | — | Mock | **Covered (client)** |
| LMP-49 | Screen time cap | — | `screen_time_*_test.dart` | — | — | Device tamper | Local store mock | **Covered (client)** |

---

## Activity pipeline & insights

| Jira | Deliverable | Backend | Client mobile | Client web | Contract | Live E2E | Persistence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LMP-50 | Activity event schemas | `activity-ingestion` unit | outbox wire tests | — | OpenAPI components | — | — | **Covered** |
| LMP-51 | Offline outbox + ingest | Ingest e2e / idempotency DB | `activity_outbox*.dart` | — | Batch path in contract tests | Opt-in HTTP test + **LMP-113** | **Postgres backend**; client mostly mock | **Gap: live ingest** → backend + LMP-113 |
| LMP-52 | Session KPI aggregation | `session-kpi.db.spec.ts` | `session_kpi_repository_test.dart` (fake API) | Dashboard mocks | KPI OpenAPI | UAT-03 manual | **Postgres backend**; client **mock** | **Gap: KPI parity** manual / backend |
| LMP-130 | Mission status read API | Mission DB/API tests | `mission_status_*_test.dart` (fake API) | Dashboard mocks | 0.14.x pin | — | **Postgres backend**; client **mock** | **Gap: live mission rows** → backend e2e |

---

## Parent dashboards (LMP-53 / LMP-54)

| Jira | Deliverable | Backend | Client mobile | Client web | Contract | Live E2E | Persistence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LMP-53 | Mobile dashboard KPI + mission | Dashboard read e2e | `parent_dashboard_*_test.dart` | — | 0.14.x pin | UAT-03 | **Backend PG**; mobile **fake repos** | Automated UI; live parity manual |
| LMP-54 | Web dashboard BFF + UI | `web-dashboard-read` e2e | — | `parent-dashboard*.tsx`, `contract.test.mjs`, PR #34 UAT | BFF routes | — | **Backend PG**; web **mock fetch** | **Covered**; do not rewrite PR #34 |
| LMP-53/54 | UAT runner | Backend PR #34 area | `uat-dashboard.sh` | same | — | `--live-smoke` | No DB writes | **PR #34 owned** |

---

## Remaining live Postgres / backend persistence gaps (client view)

These are **not** closed by client PR #35 alone. Backend LMP-132 / LMP-113 / manual UAT own proof.

| Area | What client tests prove | What still needs backend / live stack |
| --- | --- | --- |
| Activity ingest idempotency | Outbox queue logic, wire format, encrypted store | Postgres dedupe, consent enforcement, batch HTTP **→ backend `test:db` / e2e** |
| Session KPI values | Mobile/web render server JSON; window math | Aggregation correctness, freshness over real sessions **→ `session-kpi.db.spec.ts` + UAT-03** |
| Mission status + caregiver reports | UI labels, truncation, fail-closed errors | Authoritative rows in DB **→ backend mission e2e + UAT-04** |
| Web BFF auth | Cookie, CSRF, mock backend in `http-session.test.mjs` | Real Nest session store, revocation **→ backend web-session e2e** |
| Multi-parent A/B ownership | Stale-response and 403/404 component tests | Cross-account authorization on live API **→ backend e2e + UAT-06 manual** |
| Full vertical journeys | — | **→ LMP-113** (explicitly not duplicated here) |
| Resilience / partial outage at stack | Independent panel retry in component tests | **→ LMP-114** |

**Backend dependency:** local Postgres verification (`verify:local`, migrate/seed) is implemented and documented in **`little-minds-backend`** only; the client runner does not invoke it.

---

## Coordinated / out of scope

| Jira | Topic |
| --- | --- |
| LMP-113 | Release vertical E2E |
| LMP-114 | Resilience testing |
| LMP-131 | Dashboard charts UX |

---

## Client PR #35 deliverables

| Gap | Action | Evidence |
| --- | --- | --- |
| Matrix in repo | This file | Committed under `docs/` |
| Unified runner | `scripts/run-client-regression.sh` | PASS/FAIL/SKIP summary + CI mapping in `--help` |
| Mobile truncated mission (UAT-05) | `parent_dashboard_widget_test.dart` | Flutter widget test |

**Verification command:** `bash scripts/run-client-regression.sh --skip-install` (requires Flutter on PATH for flutter stage).

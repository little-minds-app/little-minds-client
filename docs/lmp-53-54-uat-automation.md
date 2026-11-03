# LMP-53 + LMP-54: automated functional UAT

## Run locally, without repeating manual tests

From `little-minds-client` repository root:

```bash
bash scripts/uat-dashboard.sh
```

With the existing Docker, NestJS and Next.js processes running, add non-authenticated read-only health probes:

```bash
bash scripts/uat-dashboard.sh --live-smoke
```

The runner tests synthetic fixtures only. It does **not** reset/seed/migrate a database, create accounts or submit real activity events, and it never reads browser cookies or secrets. The live smoke tests only public health and landing endpoints.

## UAT evidence matrix

| UAT | Automated coverage | Remaining human/real-backend evidence |
| --- | --- | --- |
| 01 Parent Gate/PIN | `parent_dashboard_gate_test.dart`, `parent_gate_boundaries_test.dart` | One device PIN entry and visual confirmation |
| 02 Profile selection | Existing `child-profiles.component.test.tsx` + BFF `http-session.test.mjs` | Existing A/B profile session screenshots |
| 03 KPI parity | Server KPI / web component and mobile KPI view/controller/repository tests | At least one accepted actual session in backend; compare mobile/web on same child/window |
| 04 Mission provenance | New web UAT authoritative caregiver report test; existing mobile mission tests | At least one accepted genuine caregiver report with source/timestamp on both devices |
| 05 Empty/stale/partial/truncated | Existing dashboard and new truncation regression | Visual device check if needed |
| 06 A/B ownership | New web 403/404 fail-closed tests, mobile stale-response tests, BFF auth tests | Real backend manual A/B ownership cross-check already performed |
| 07 Web session | Existing BFF cookie/idle-touch, dashboard focus/logout/parent-switch tests | Optional real-tab logout smoke |
| 08 Service outage/retry | New independent mission 503 and existing independent KPI outage/retry | Optional local service interruption |
| 09 Mobile lifecycle | `parent_dashboard_gate_test.dart` background/grant tests | On-device orientation and screen-time check |

**Important distinction:** fixtures establish app behavior and CI regressions, not real backend ingest/persistence or live multi-account authorization. Those should be tested with isolated synthetic accounts/datasets through a separate controlled live E2E harness. Do not claim that `npm test` alone proves UAT-03/UAT-04 live integration.

UI redesign/charts and colored feedback messages are tracked separately in LMP-131, not blocking these functional checks.

## Safety and CI budget

- The existing Next web test command automatically discovers `parent-dashboard-uat.component.test.tsx`; no new workflow or separate GitHub Action job is added.
- Avoid rerunning the full matrix for each UI observation; run the runner once per final commit and rely on existing PR CI.
- A passing runner does not change Jira status automatically.

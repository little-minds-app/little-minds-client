# Mentor card contract compatibility (client)

**Source of truth:** backend `content/schemas/mentor-card/v1.schema.json` (`1.0.0`)  
**Pinned commit:** see [PIN.md](./PIN.md) (`8678e61a673e82a5823875d8af4fc1bf6d700ac9` — backend PR #11 merge)

## What CI verifies offline (no Kids Mode → backend runtime)

Flutter tests under `apps/mobile/test/mentor_card_*`:

| Check | How |
|---|---|
| Schema version gate | `schema_version` must be `1.0.0`; unknown major fails |
| Fixture parity en-US / tr-TR | Same `mentor_card_id`, required sections present, paired locales |
| Required fields + age | Structural validator + age applicability |
| Valid / invalid agreement | Happy-path fixtures pass; coercive/proof/missing sections fail |
| Safe-copy rules | Adult supervision, no proof/photo, non-diagnostic |
| Draft ≠ approved | `review_status: draft` fails parent-surface gate |
| Near/Far mission resolve | Card resolves to `NearFarConstants.missionId` |
| Pin constant | `MentorCardContentPin.backendCommitSha` matches PIN.md |

Mirrored schema file is checked into `content/mentor-card/schemas/v1.schema.json` for human/diff review. Dart does **not** run Ajv; it mirrors backend validation rules.

## CI limitations (dual-repo)

| Limitation | Mitigation |
|---|---|
| Client CI cannot clone/fetch private backend on every PR without extra secrets | Pin SHA + vendored mirror; update after backend merge |
| Live byte-identical fixture sync with open backend PR is manual | `PIN.md` + review checklist; reconcile when mission-id decision / backend fixture update lands |
| No shared OpenAPI mentor routes yet | Content JSON only; do not invent `/v1/mentor/*` on client pin |

## Pin strategy

1. Pin the **verified merge commit** on backend `main`: `8678e61a673e82a5823875d8af4fc1bf6d700ac9`. Do **not** invent SHAs.
2. On future backend content-contract changes: bump PIN + remirror schema/fixtures, then re-run Flutter contract tests.
3. Near/Far id alignment: [MISSION_ID_MAPPING.md](./MISSION_ID_MAPPING.md).

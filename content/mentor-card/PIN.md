# Mentor card content pin (client mirror)

**Owner:** `little-minds-app/little-minds-backend` (Blueprint §33 / LMP-47)  
**Do not fork field names or safe-copy rules.** Client Dart validators are a thin consumption mirror.

| Field | Value |
|---|---|
| Backend PR | https://github.com/little-minds-app/little-minds-backend/pull/11 |
| Backend branch | `cursor/lmp-47-mentor-schema-4029` |
| Pinned commit SHA | `dac60c575342b7cb8c86f2603bfc219e51d45ed5` |
| Schema version | `1.0.0` (`VERSION`) |
| Schema path (backend) | `content/schemas/mentor-card/v1.schema.json` |
| Fixtures (backend) | `content/fixtures/mentor-cards/near-far.{en-US,tr-TR}.v1.json` |

## Pending merge

This pin points at the **open** backend PR head. After backend #11 merges to `main`, update:

1. `Pinned commit SHA` → merge commit on `main`
2. Re-copy schema + fixtures if the merge commit differs
3. Keep `apps/mobile/assets/content/mentor_cards/*.json` in sync with `content/mentor-card/fixtures/`

## Client layout

| Path | Role |
|---|---|
| `content/mentor-card/` | Documented pin + schema/fixture mirror |
| `apps/mobile/assets/content/mentor_cards/` | Flutter asset load of the same Near/Far fixtures |
| `apps/mobile/lib/mentor/` | Thin Dart models + validators (no OpenAPI invent) |

## Non-goals

- No LMP-48 parent mentor UI
- No LMP-120 audio
- No second OpenAPI `/v1/mentor/*` surface on the client pin

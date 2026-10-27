# Mentor card content pin (client mirror)

**Owner:** `little-minds-app/little-minds-backend` (Blueprint §33 / LMP-47)  
**Do not fork field names or safe-copy rules.** Client Dart validators are a thin consumption mirror.

| Field | Value |
|---|---|
| Backend PR | https://github.com/little-minds-app/little-minds-backend/pull/11 |
| Backend branch | `cursor/lmp-47-mentor-schema-4029` |
| Pinned commit SHA | `a6dc8116994595be1788450c525e48138b9580eb` |
| Previous pin | `dac60c575342b7cb8c86f2603bfc219e51d45ed5` (pre ID-alignment) |
| Schema version | `1.0.0` (`VERSION`) |
| Schema path (backend) | `content/schemas/mentor-card/v1.schema.json` |
| Fixtures (backend) | `content/fixtures/mentor-cards/near-far.{en-US,tr-TR}.v1.json` |

## Canonical Near/Far ids (decision)

See [MISSION_ID_MAPPING.md](./MISSION_ID_MAPPING.md) / store `internal/lmp-47-mission-id-decision.md`:

| Field | Value |
|---|---|
| `mentor_card_id` | `mentor_near_far_32m_adjacency_v1` |
| `linked_mission_ids` | `near_far_sock_soft_toy_v1` |
| `linked_activity_ids` | `near_far_32m_v1` |
| Age band | 30–35 |
| `review_status` | `draft` (≠ approved) |

## Pending merge

This pin points at the **open** backend PR head (`a6dc811…`). **Do not invent a merge commit SHA.** After backend #11 merges to `main`, update:

1. `Pinned commit SHA` → actual merge commit on `main`
2. Re-copy schema + fixtures if the merge commit differs
3. Keep `apps/mobile/assets/content/mentor_cards/*.json` in sync with `content/mentor-card/fixtures/`

## Client layout

| Path | Role |
|---|---|
| `content/mentor-card/` | Documented pin + schema/fixture mirror |
| `content/mentor-card/MISSION_ID_MAPPING.md` | Near/Far id alignment |
| `content/mentor-card/CONTRACT_COMPAT.md` | Offline CI compatibility notes |
| `apps/mobile/assets/content/mentor_cards/` | Flutter asset load of Near/Far fixtures |
| `apps/mobile/lib/mentor/` | Thin Dart models + validators (no OpenAPI invent) |

## Non-goals

- No LMP-48 parent mentor UI
- No LMP-120 audio
- No second OpenAPI `/v1/mentor/*` surface on the client pin

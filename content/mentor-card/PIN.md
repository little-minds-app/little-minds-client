# Mentor card content pin (client mirror)

**Owner:** `little-minds-app/little-minds-backend` (Blueprint §33 / LMP-47)  
**Do not fork field names or safe-copy rules.** Client Dart validators are a thin consumption mirror.

| Field | Value |
|---|---|
| Backend PR | https://github.com/little-minds-app/little-minds-backend/pull/11 (**merged**) |
| Pinned commit SHA | `8678e61a673e82a5823875d8af4fc1bf6d700ac9` |
| Previous open-PR pins | `a6dc811…` (ID alignment) → `dac60c57…` (initial) |
| Schema version | `1.0.0` (`VERSION`) |
| Schema path (backend) | `content/schemas/mentor-card/v1.schema.json` |
| Fixtures (backend) | `content/fixtures/mentor-cards/near-far.{en-US,tr-TR}.v1.json` |

## Canonical Near/Far ids

See [MISSION_ID_MAPPING.md](./MISSION_ID_MAPPING.md):

| Field | Value |
|---|---|
| `mentor_card_id` | `mentor_near_far_32m_adjacency_v1` |
| `linked_mission_ids` | `near_far_sock_soft_toy_v1` |
| `linked_activity_ids` | `near_far_32m_v1` |
| Age band | 30–35 |
| `review_status` | `draft` (≠ approved) |

## Pin strategy

- Pin is the **verified merge commit** on backend `main` from PR #11: `8678e61a673e82a5823875d8af4fc1bf6d700ac9`.
- Do **not** invent SHAs. Fixtures at merge match the prior ID-aligned content; schema descriptions updated on merge — remirrored here.

## Client layout

| Path | Role |
|---|---|
| `content/mentor-card/` | Pin + schema/fixture mirror |
| `apps/mobile/assets/content/mentor_cards/` | Flutter asset fixtures |
| `apps/mobile/lib/mentor/` | Thin Dart consumption |

## Non-goals

- No LMP-48 parent mentor UI / no LMP-120 audio / no second OpenAPI surface

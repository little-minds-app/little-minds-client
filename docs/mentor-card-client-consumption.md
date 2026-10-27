# Mentor card client consumption (LMP-47)

**Canonical owner:** `little-minds-backend` (Blueprint §33)  
**Backend PR:** https://github.com/little-minds-app/little-minds-backend/pull/11 (**merged**)  
**Pin:** [`content/mentor-card/PIN.md`](../content/mentor-card/PIN.md) → `8678e61a673e82a5823875d8af4fc1bf6d700ac9`

## What the client does

| Layer | Location |
|---|---|
| Pin + schema/fixture mirror | `content/mentor-card/` |
| Mission/activity id mapping | [`content/mentor-card/MISSION_ID_MAPPING.md`](../content/mentor-card/MISSION_ID_MAPPING.md) |
| Contract compatibility notes | [`content/mentor-card/CONTRACT_COMPAT.md`](../content/mentor-card/CONTRACT_COMPAT.md) |
| Flutter assets (Near/Far JSON) | `apps/mobile/assets/content/mentor_cards/` |
| Dart models / safe-copy / validator | `apps/mobile/lib/mentor/` |
| Near/Far adjacency link | `NearFarMentorAdjacency` → `near_far_play_mentor` |

## What the client does not do

- Invent a second OpenAPI or divergent JSON Schema
- Parent mentor card UI (LMP-48)
- Audio / TTS (LMP-120)
- Treat `review_status: draft` as approved caregiver content

## Validation

```bash
cd apps/mobile
flutter analyze
flutter test test/mentor_card_unit_test.dart test/mentor_card_contract_compat_test.dart test/near_far_unit_test.dart
```

Pinned to verified merge commit `8678e61a673e82a5823875d8af4fc1bf6d700ac9`. Update only when backend content contract changes (never invent SHAs).

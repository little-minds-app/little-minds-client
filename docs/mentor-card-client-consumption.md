# Mentor card client consumption (LMP-47)

**Canonical owner:** `little-minds-backend` (Blueprint §33)  
**Backend PR:** https://github.com/little-minds-app/little-minds-backend/pull/11  
**Pin:** [`content/mentor-card/PIN.md`](../content/mentor-card/PIN.md)

## What the client does

| Layer | Location |
|---|---|
| Pin + schema/fixture mirror | `content/mentor-card/` |
| Flutter assets (Near/Far JSON) | `apps/mobile/assets/content/mentor_cards/` |
| Dart models / safe-copy / validator | `apps/mobile/lib/mentor/` |
| Near/Far adjacency link | `NearFarMentorAdjacency` → `near_far_play_mentor` |

## What the client does not do

- Invent a second OpenAPI or divergent JSON Schema
- Parent mentor card UI (LMP-48)
- Audio / TTS (LMP-120)

## Validation

```bash
cd apps/mobile
flutter analyze
flutter test test/mentor_card_unit_test.dart test/near_far_unit_test.dart
```

After backend #11 merges, update the SHA in `PIN.md` and `MentorCardContentPin.backendCommitSha`.

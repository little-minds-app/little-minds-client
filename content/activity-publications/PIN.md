# Activity publication pin (client mirror) — LMP-134

**Owner:** `little-minds-app/little-minds-backend` (Shape Matching seed publication)

| Field | Value |
| --- | --- |
| Backend PR | https://github.com/little-minds-app/little-minds-backend/pull/37 |
| Pinned commit SHA | `4ce1dc1355c55c2b488ef405fda909c47b8258cd` |
| Fixture (backend) | `content/fixtures/activity-publications/shape-matching.v1.json` |
| Flutter assets | `apps/mobile/assets/content/activity_publications/` (mirrors fixture) |

## Shape Matching published version

| Field | Value |
| --- | --- |
| `hub_activity_id` | `shape_matching` |
| `content_version_id` | `018f1340-0000-4000-8000-000000000001` |
| `consent_policy_version` (telemetry) | `synthetic-policy-v1` |
| `review_status` | `published` |

**Blocker:** LMP-69 runtime release/manifest API remains To Do. Until then, hub production telemetry resolves the pinned fixture (not Dart string literals in the composition root).

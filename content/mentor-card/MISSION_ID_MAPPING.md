# Near/Far mission & activity id mapping (LMP-47)

**Decision:** Project store `internal/lmp-47-mission-id-decision.md`  
**Backend pin:** `8678e61a673e82a5823875d8af4fc1bf6d700ac9` (PR #11 **merged** on `main`)

## Canonical IDs (client demo truth = content fixture truth)

| Concept | Canonical string | Client source |
|---|---|---|
| Digital activity / brief | `near_far_32m_v1` | `NearFarConstants.activityId` |
| Real-world mission | `near_far_sock_soft_toy_v1` | `NearFarConstants.missionId` |
| Mentor card | `mentor_near_far_32m_adjacency_v1` | `NearFarConstants.mentorCardId` |

Event payloads keep `mission_id` = `near_far_sock_soft_toy_v1` (LMP-45/46). Age band **30–35**. `review_status: draft`.

## Deprecated draft strings (pre-a6dc811)

| Legacy | Status |
|---|---|
| `near_far_sock_soft_toy` | Deprecated — map → `near_far_sock_soft_toy_v1` if seen |
| `near_far` | Deprecated — map → `near_far_32m_v1` if seen |
| `near_far_play_mentor` | Deprecated — use `mentor_near_far_32m_adjacency_v1` |

`MentorCardNearFarLinks` keeps legacy → canonical resolution for transition.

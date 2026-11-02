# LMP-51 Phase C — Flutter Offline Outbox

Status: **Implementation candidate (unmerged)**, pending Phase C security/data-policy review.
Backend contract: `POST /v1/events/batch` from backend PR #31 (`contracts/openapi.yaml` v0.12.0).

## Implemented and covered by Flutter tests

- `ActivityFileOutbox`: account-partitioned durable event records in app-support storage, atomic single-file rename, stable UUID, bounded records and bytes, persisted retry delay; dependent session metadata written in the SAME record as its event.
- `ActivityEventEmitter`: versioned envelopes, UUIDv4, child vs parent actor separation, forbidden identity/raw-touch fields.
- `ActivityOutboxSync`: bearer-authenticated HTTP batch sender; preserved immutable event IDs; per-event accepted/duplicate ACK; transient retry with jitter, auth pause, permanent rejection quarantine; no cross-account ACK when session changes.
- Optional scope purge and foreground lifecycle sync/retry wiring via the parent auth controller.
- Automated tests: restart persistence, account switch, idempotent local enqueue, crash/timeout simulation, partial ACK, parent consent purge, rejected quarantine and associated session delivery.

## Explicit review gates / differences from initial architecture

1. **Persistence implementation differs from original SQLite recommendation.** This PR uses an atomic file-per-event outbox in private application support storage, not SQLite. It supports per-event atomic writes but NOT a multi-record SQL transaction. Review must accept this tradeoff or replace it with SQLite before release.
2. **Near/Far remains a local-only demo.** Its `device_id` and `content_version_id` are fixture text, not legitimate server UUIDs; automatically uploading those fabricated IDs would generate unauthorized/invalid telemetry. The new emitter requires genuine authenticated parent, registered device and published content version values supplied by the product's real activity integration.
3. **Generated client API pin:** The HTTP sender follows backend PR #31 wire contract but uses explicit `dart:io` HTTP, rather than a generated ActivityApi client. The client repository's separate generated contract must be version-synced/pinned before final deployment.
4. **Privacy/retention:** App-private storage avoids shared-access directories, but encrypted-at-rest storage and approved retention/cleanup periods remain release security decisions. No silent expiry/deletion of essential queued events is implemented.
5. **Connectivity/operating-system:** Retry is foreground/resume-driven; no guarantee of background execution while iOS suspends the app.
6. **429 Retry-After and network-size budgets:** Exponential backoff is implemented; explicit Retry-After handling and a full request byte cap are still acceptance gates for production use.

**Never merge or mark LMP-51 Done before Phases C/D review and explicit human merge authorization.** No production deployment has occurred.

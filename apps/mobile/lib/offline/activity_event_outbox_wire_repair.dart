import '../shape_matching/shape_matching_wire_payload.dart';

/// Normalizes queued activity envelopes before OpenAPI parse / batch POST.
///
/// Legacy outbox rows may contain pre-canonicalization payload keys (for example
/// Shape Matching `shape_id`). Repair is best-effort strip/rename only — no
/// automatic delete or quarantine (see LMP-134 store report §S).
Map<String, dynamic> repairActivityEventOutboxWire(
  Map<String, dynamic> envelope,
) {
  return ShapeMatchingWirePayload.repairQueuedEvent(envelope);
}

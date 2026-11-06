/// Aligns persisted session consent metadata with the queued event envelope.
///
/// Legacy rows may carry a mismatched session `consent.policy_version` while
/// events already reference the publication-bound policy. The server re-checks
/// consent on **session** admission; events alone cannot compensate.
Map<String, dynamic> repairActivitySessionOutboxWire(
  Map<String, dynamic> session,
  Map<String, dynamic> event,
) {
  final scope = event['consent_scope'];
  final policy = event['consent_policy_version'];
  if (scope is! String || policy is! String) {
    return session;
  }
  final consent = session['consent'];
  if (consent is! Map) {
    return session;
  }
  final consentCopy = Map<String, dynamic>.from(consent);
  consentCopy['consent_scope'] = scope;
  consentCopy['policy_version'] = policy;
  consentCopy['purpose'] = switch (scope) {
    'essential_play_events' => 'essential_play_events',
    'essential_service_telemetry' => 'essential_service_telemetry',
    'optional_product_analytics' => 'optional_product_analytics',
    _ => consentCopy['purpose'],
  };
  return {...session, 'consent': consentCopy};
}

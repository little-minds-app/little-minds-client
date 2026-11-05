import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/offline/activity_session_outbox_wire_repair.dart';

void main() {
  test('aligns session consent policy and purpose from event envelope', () {
    final session = {
      'play_session_id': '55555555-5555-4555-8555-555555555555',
      'consent': {
        'purpose': 'essential_service_telemetry',
        'consent_scope': 'essential_play_events',
        'policy_version': 'v1-tr-2026-10',
        'decision': 'granted',
      },
    };
    final event = {
      'consent_scope': 'essential_play_events',
      'consent_policy_version': 'synthetic-policy-v1',
    };
    final repaired = repairActivitySessionOutboxWire(session, event);
    final consent = repaired['consent'] as Map;
    expect(consent['policy_version'], 'synthetic-policy-v1');
    expect(consent['consent_scope'], 'essential_play_events');
    expect(consent['purpose'], 'essential_play_events');
    expect(consent['decision'], 'granted');
  });
}

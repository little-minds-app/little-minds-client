import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/near_far/near_far_events.dart';
import 'package:little_minds_mobile/near_far/near_far_production_event_buffer.dart';
import 'package:little_minds_mobile/offline/activity_event_emitter.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';

void main() {
  test('Near/Far production adapter writes canonical activity and parent envelopes', () async {
    final root = await Directory.systemTemp.createTemp('lmp51-nearfar-');
    try {
      const parentId = '11111111-1111-4111-8111-111111111111';
      const deviceId = '22222222-2222-4222-8222-222222222222';
      const contentId = '33333333-3333-4333-8333-333333333333';
      const sessionId = '44444444-4444-4444-8444-444444444444';
      final outbox = ActivityFileOutbox.forTesting(root);
      final emitter = ActivityEventEmitter(
        outbox: outbox,
        session: const AuthSession(
          parentId: parentId, sessionId: 'auth-session',
          accessToken: 'test', refreshToken: 'test',
          expiresInSeconds: 300,
        ),
        deviceId: deviceId,
        contentVersionId: contentId,
        consentPolicyVersion: 'privacy-notice-draft-0',
        clock: () => DateTime.utc(2026, 11, 2, 12),
      );
      final bridge = NearFarProductionEventBuffer(
        emitter: emitter,
        sessionPayload: {
          'schema_version': '1.0.0',
          'play_session_id': sessionId,
          'device_id': deviceId,
          'content_version_id': contentId,
          'started_at': '2026-11-02T12:00:00Z',
          'completion_status': 'started',
          'consent': {
            'purpose': 'essential_service_telemetry',
            'consent_scope': 'essential_play_events',
            'policy_version': 'privacy-notice-draft-0',
            'decision': 'granted'
          },
          'provenance': {
            'emitter': 'kids_mode_client',
            'capture_channel': 'offline_queue',
            'clock_trust': 'wall_clock_only',
          },
        },
        deviceId: deviceId,
        contentVersionId: contentId,
      );
      bridge.emit(playSessionId: sessionId,
          type: NearFarEventType.activityStarted,
          payload: {'age_months': 32, 'activity_variant_id': 'local-demo'});
      bridge.emit(playSessionId: sessionId,
          type: NearFarEventType.activityAttempted,
          payload: {'relation': 'near', 'prompt': 'makeNear'});
      bridge.emit(playSessionId: sessionId,
          type: NearFarEventType.activityCompleted,
          payload: {'completion_status': 'completed'});
      bridge.emit(playSessionId: sessionId,
          type: NearFarEventType.missionFeedbackSubmitted,
          payload: {'status': 'skipped', 'proof_required': false});
      await bridge.drain();
      final events = await outbox.pending(parentId);
      expect(events, hasLength(4));
      expect(events.map((e) => e.eventId).toSet(), hasLength(4));
      final attempted = events.singleWhere(
          (e) => e.payload['event_type'] == 'activity_attempted');
      expect(attempted.payload['payload'],
          containsPair('prompt', 'place_near'));
      final completed = events.singleWhere(
          (e) => e.payload['event_type'] == 'activity_completed');
      expect(completed.payload['monotonic_duration_seconds'], isA<int>());
      expect(completed.sessionPayload?['completion_status'], 'completed');
      final feedback = events.singleWhere(
          (e) => e.payload['event_type'] == 'mission_feedback_submitted');
      expect(feedback.payload.containsKey('play_session_id'), isFalse);
      expect(feedback.sessionPayload, isNull);
      expect(events.every((e) => e.payload['device_id'] == deviceId), isTrue);
    } finally {
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}

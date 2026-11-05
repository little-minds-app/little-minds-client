import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/parent_scoped_device_id.dart';
import 'package:little_minds_mobile/offline/activity_event_emitter.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_events.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_production_consent.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_production_event_buffer.dart';

/// LMP-134 Shape Matching production batch (sessions + events) as queued by the hub.
class ShapeMatchingProductionBatchFixture {
  static const parentId = '11111111-1111-4111-8111-111111111111';
  static const childInstallationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  static const contentVersionId = '018f1340-0000-4000-8000-000000000001';
  static const consentPolicyVersion = 'synthetic-policy-v1';

  static String scopedDeviceId() =>
      parentScopedDeviceId(childInstallationId, parentId);

  static AuthSession session() => const AuthSession(
        parentId: parentId,
        sessionId: '44444444-4444-4444-8444-444444444444',
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        expiresInSeconds: 900,
      );

  static Future<({
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> sessions,
  })> build({
    required ActivityFileOutbox outbox,
    DateTime Function()? clock,
  }) async {
    final deviceId = scopedDeviceId();
    final playSessionId = '55555555-5555-4555-8555-555555555555';
    final now = clock?.call() ?? DateTime.utc(2026, 11, 4, 12);
    final emitter = ActivityEventEmitter(
      outbox: outbox,
      session: session(),
      deviceId: deviceId,
      contentVersionId: contentVersionId,
      consentPolicyVersion: consentPolicyVersion,
      clock: () => now,
    );
    final bridge = ShapeMatchingProductionEventBuffer(
      emitter: emitter,
      sessionPayload: {
        'schema_version': '1.0.0',
        'play_session_id': playSessionId,
        'device_id': deviceId,
        'content_version_id': contentVersionId,
        'started_at': now.toIso8601String().replaceFirst('+00:00', 'Z'),
        'completion_status': 'started',
        'consent': {
          'purpose': ShapeMatchingProductionConsent.purpose,
          'consent_scope': ShapeMatchingProductionConsent.scope,
          'policy_version': consentPolicyVersion,
          'decision': 'granted',
        },
        'provenance': {
          'emitter': 'kids_mode_client',
          'capture_channel': 'offline_queue',
          'clock_trust': 'wall_clock_only',
        },
      },
      deviceId: deviceId,
      contentVersionId: contentVersionId,
    );
    bridge.emit(
      playSessionId: playSessionId,
      type: ShapeMatchingEventType.activityStarted,
      payload: {
        'age_months': 36,
        'activity_variant_id': ShapeMatchingConstants.activityId,
      },
    );
    bridge.emit(
      playSessionId: playSessionId,
      type: ShapeMatchingEventType.activityAttempted,
      payload: {'shape_id': 'circle', 'correct': true, 'round_index': 0},
    );
    bridge.emit(
      playSessionId: playSessionId,
      type: ShapeMatchingEventType.activityCompleted,
      payload: {'completion_status': 'completed'},
    );
    await bridge.drain();
    final pending = await outbox.pending(parentId);
    final sessions = <String, Map<String, dynamic>>{};
    for (final item in pending) {
      final sessionPayload = item.sessionPayload;
      if (sessionPayload == null) continue;
      final sid = sessionPayload['play_session_id'];
      if (sid is! String) continue;
      if (!sessions.containsKey(sid) || sessionPayload['ended_at'] != null) {
        sessions[sid] = sessionPayload;
      }
    }
    return (
      events: pending.map((e) => e.payload).toList(),
      sessions: sessions.values.toList(),
    );
  }
}

/// OpenAPI `UuidV4OrV7` pattern (includes parent-scoped v5 device ids).
final RegExp activityBatchUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[457][0-9a-fA-F]{3}-'
  r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

final RegExp activityBatchUtcInstantZ = RegExp(
  r'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?Z$',
);

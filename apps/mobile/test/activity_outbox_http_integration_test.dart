import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/offline/activity_outbox_sync.dart';
import 'package:uuid/uuid.dart';

/// Opt-in local integration: real Nest HTTP + isolated LMP-51 PostgreSQL DB.
/// Run with LMP51_UAT_TOKEN and a running localhost:3000 backend.
/// Never print or persist the bearer token.
void main() {
  const parentId = '11111111-1111-4111-8111-111111111111';
  const deviceId = '51100000-0000-4000-8000-000000000002';
  const variantId = '51100000-0000-4000-8000-000000000007';
  const policy = 'privacy-notice-draft-0';
  final token = Platform.environment['LMP51_UAT_TOKEN'];
  final enabled = token != null && token.isNotEmpty;

  test('offline persisted event reconnects to real backend and ACK deletes it',
      () async {
    final root = await Directory.systemTemp.createTemp('lmp51-http-uat-');
    try {
      final outbox = ActivityFileOutbox.forTesting(root);
      final id = const Uuid().v4();
      final sid = const Uuid().v4();
      final sessionPayload = <String, dynamic>{
        'schema_version': '1.0.0',
        'play_session_id': sid,
        'device_id': deviceId,
        'content_version_id': variantId,
        'started_at': '2026-10-28T06:00:00.000Z',
        'ended_at': '2026-10-28T06:01:24.000Z',
        'monotonic_duration_seconds': 84,
        'completion_status': 'completed',
        'app_build': '0.1.0+local',
        'locale': 'en-US',
        'consent': {
          'purpose': 'essential_service_telemetry',
          'policy_version': policy,
          'consent_scope': 'essential_play_events',
          'decision': 'granted',
        },
        'provenance': {
          'emitter': 'kids_mode_client',
          'capture_channel': 'offline_queue',
          'clock_trust': 'monotonic_within_boot',
        },
      };
      final payload = <String, dynamic>{
        'schema_version': '1.0.0',
        'event_id': id,
        'event_type': 'activity_completed',
        'play_session_id': sid,
        'device_id': deviceId,
        'content_version_id': variantId,
        'occurred_at': '2026-10-28T06:01:24.000Z',
        'monotonic_duration_seconds': 84,
        'consent_scope': 'essential_play_events',
        'consent_policy_version': policy,
        'provenance': {
          'emitter': 'kids_mode_client',
          'actor_scope': 'child_play',
          'source': 'instrumented',
          'clock_trust': 'monotonic_within_boot',
        },
        'payload': {
          'completion_status': 'completed',
          'scoring': 'neutral',
          'hints_used': 1,
          'eligible_first_attempts': 6,
          'correct_first_attempts': 5,
        },
      };
      final now = DateTime.utc(2026, 11, 3, 10);
      await outbox.enqueue(PendingActivityEvent(
        parentId: parentId,
        eventId: id,
        payload: payload,
        sessionPayload: sessionPayload,
        createdAt: now,
      ));
      final active = AuthSession(
        accessToken: token!,
        refreshToken: 'local-uat-unused',
        sessionId: 'lmp51-uat-session',
        parentId: parentId,
        expiresInSeconds: 300,
      );

      // Simulated network loss through the same production sync coordinator.
      final offline = ActivityOutboxSync(
        outbox: outbox,
        currentSession: () => active,
        clock: () => now,
        send: (_, _, _) async => throw const SocketException('offline'),
      );
      await offline.flush();
      final restored = ActivityFileOutbox.forTesting(root);
      expect(await restored.pending(parentId, now: now.add(const Duration(days: 1))),
          hasLength(1), reason: 'offline event must survive a restart');

      // Real generated-model HTTP sender, not a mocked ACK.
      final sender = ActivityHttpBatchSender(
          apiBaseUrl: Uri.parse('http://127.0.0.1:3000'));
      final online = ActivityOutboxSync(
        outbox: restored,
        currentSession: () => active,
        clock: () => now.add(const Duration(days: 1)),
        send: sender.send,
      );
      await online.flush();
      expect(await restored.pending(parentId, now: now.add(const Duration(days: 2))),
          isEmpty, reason: 'server accepted ACK must delete event');

      // Replay the identical immutable event to verify server deduplication.
      final ack = await sender.send(active, [payload], [sessionPayload]);
      expect(ack['results'], isA<List>());
      final results = ack['results'] as List;
      expect(results, hasLength(1));
      expect(results.single['event_id'], id);
      expect(results.single['status'], 'duplicate_noop');
      stdout.writeln('LMP-51 FLUTTER REAL HTTP OUTBOX UAT: PASS event_id=$id');
    } finally {
      if (await root.exists()) await root.delete(recursive: true);
    }
  }, skip: !enabled);
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/offline/activity_outbox_sync.dart';

void main() {
  test('HTTP wire omits null optional event fields', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? captured;
    final serverTask = server.first.then((request) async {
      captured = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"message":"batch.invalid_event"}');
      await request.response.close();
    });
    try {
      const session = AuthSession(
        accessToken: 'test-only',
        refreshToken: 'test-only',
        sessionId: 'test-session',
        parentId: '11111111-1111-4111-8111-111111111111',
        expiresInSeconds: 300,
      );
      final sender = ActivityHttpBatchSender(
        apiBaseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      final event = <String, dynamic>{
        'schema_version': '1.0.0',
        'event_id': '33333333-3333-4333-8333-333333333333',
        'event_type': 'activity_completed',
        'device_id': '51100000-0000-4000-8000-000000000002',
        'content_version_id': '51100000-0000-4000-8000-000000000007',
        'occurred_at': '2026-10-28T06:01:24.000Z',
        'consent_scope': 'essential_play_events',
        'consent_policy_version': 'privacy-notice-draft-0',
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
      await expectLater(
        sender.send(session, [event], []),
        throwsA(isA<ActivityPermanentHttp>()),
      );
      await serverTask;
      final wireEvent = (captured!['events'] as List).single
          as Map<String, dynamic>;
      expect(wireEvent.containsKey('play_session_id'), isFalse);
      expect(wireEvent.containsKey('monotonic_duration_seconds'), isFalse);
      expect(wireEvent['event_id'], event['event_id']);
      expect(wireEvent['payload'], event['payload']);
    } finally {
      await server.close(force: true);
    }
  });
}

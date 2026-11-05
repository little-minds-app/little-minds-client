import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/offline/activity_batch_wire_codec.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/offline/activity_outbox_sync.dart';
import 'package:little_minds_api/api.dart';

void main() {
  DebugPrintCallback? restoreDebugPrint;

  setUp(() {
    restoreDebugPrint = debugPrint;
  });

  tearDown(() {
    debugPrint = restoreDebugPrint!;
  });

  test('encodeActivityBatchWire is jsonEncode-safe with sessions', () {
    const sid = '55555555-5555-4555-8555-555555555555';
    final session = ActivitySessionV1.fromJson(<String, dynamic>{
      'schema_version': '1.0.0',
      'play_session_id': sid,
      'device_id': '51100000-0000-4000-8000-000000000002',
      'content_version_id': '51100000-0000-4000-8000-000000000007',
      'started_at': '2026-10-28T06:00:00.000Z',
      'ended_at': '2026-10-28T06:01:24.000Z',
      'monotonic_duration_seconds': 84,
      'completion_status': 'completed',
      'app_build': '0.1.0+local',
      'locale': 'en-US',
      'consent': {
        'purpose': 'essential_service_telemetry',
        'policy_version': 'privacy-notice-draft-0',
        'consent_scope': 'essential_play_events',
        'decision': 'granted',
      },
      'provenance': {
        'emitter': 'kids_mode_client',
        'capture_channel': 'offline_queue',
        'clock_trust': 'monotonic_within_boot',
      },
    })!;
    final event = ActivityEventV1.fromJson(<String, dynamic>{
      'schema_version': '1.0.0',
      'event_id': '33333333-3333-4333-8333-333333333333',
      'event_type': 'activity_completed',
      'play_session_id': sid,
      'device_id': '51100000-0000-4000-8000-000000000002',
      'content_version_id': '51100000-0000-4000-8000-000000000007',
      'occurred_at': '2026-10-28T06:01:24.000Z',
      'monotonic_duration_seconds': 84,
      'consent_scope': 'essential_play_events',
      'consent_policy_version': 'privacy-notice-draft-0',
      'provenance': {
        'emitter': 'kids_mode_client',
        'actor_scope': 'child_play',
        'source': 'instrumented',
        'clock_trust': 'monotonic_within_boot',
      },
      'payload': {'completion_status': 'completed'},
    })!;
    final wire = encodeActivityBatchWire(
      IngestActivityEventBatchRequest(sessions: [session], events: [event]),
    );
    expect(() => jsonEncode(wire), returnsNormally);
    final sessions = wire['sessions'] as List;
    expect(sessions, hasLength(1));
    expect(sessions.single['play_session_id'], sid);
    expect((sessions.single['consent'] as Map)['purpose'],
        'essential_service_telemetry');
  });

  test('HTTP 401 emits batch_http_failed and auth skip diagnostics', () async {
    final logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
    });
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
    await expectLater(
      sender.send(session, [_minimalEvent()], []),
      throwsA(isA<ActivityAuthExpired>()),
    );
    expect(
      logs.any((line) => line.contains('batch_http_failed status=401')),
      isTrue,
    );
    expect(
      logs.any((line) => line.contains('batch_endpoint host=127.0.0.1')),
      isTrue,
    );
  });

  test('HTTP 400 emits validation field paths without raw body', () async {
    final logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"message":["sessions.0.device_id must match pattern","batch.invalid_event"]}',
      );
      await request.response.close();
    });
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
    await expectLater(
      sender.send(session, [_minimalEvent()], [_minimalSession()]),
      throwsA(isA<ActivityPermanentHttp>()),
    );
    expect(
      logs.any(
        (line) =>
            line.contains('batch_http_failed status=400') &&
            line.contains('error_code=batch.invalid_event') &&
            line.contains('field_paths=sessions.0.device_id'),
      ),
      isTrue,
    );
  });

  test('HTTP 503 emits retry diagnostics through outbox sync', () async {
    final logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    final root = await Directory.systemTemp.createTemp('lmp134-batch-diag-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final outbox = ActivityFileOutbox.forTesting(root);
    await outbox.enqueue(
      PendingActivityEvent(
        parentId: '11111111-1111-4111-8111-111111111111',
        eventId: '33333333-3333-4333-8333-333333333333',
        createdAt: DateTime.utc(2026, 11, 4),
        payload: _minimalEvent(),
      ),
    );
    final sync = ActivityOutboxSync(
      outbox: outbox,
      currentSession: () => const AuthSession(
        accessToken: 'test-only',
        refreshToken: 'test-only',
        sessionId: 'test-session',
        parentId: '11111111-1111-4111-8111-111111111111',
        expiresInSeconds: 300,
      ),
      clock: () => DateTime.utc(2026, 11, 4),
      send: (_, __, ___) async => throw const ActivityRetryableHttp(503),
    );
    await sync.flush();
    expect(
      logs.any((line) => line.contains('sync_retry_scheduled reason=http_retryable_503')),
      isTrue,
    );
  });
}

Map<String, dynamic> _minimalSession() => <String, dynamic>{
      'schema_version': '1.0.0',
      'play_session_id': '55555555-5555-4555-8555-555555555555',
      'device_id': '51100000-0000-4000-8000-000000000002',
      'content_version_id': '51100000-0000-4000-8000-000000000007',
      'started_at': '2026-10-28T06:00:00.000Z',
      'completion_status': 'started',
      'consent': {
        'purpose': 'essential_play_events',
        'policy_version': 'privacy-notice-draft-0',
        'consent_scope': 'essential_play_events',
        'decision': 'granted',
      },
      'provenance': {
        'emitter': 'kids_mode_client',
        'capture_channel': 'offline_queue',
        'clock_trust': 'monotonic_within_boot',
      },
    };

Map<String, dynamic> _minimalEvent() => <String, dynamic>{
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
      'payload': {'completion_status': 'completed'},
    };

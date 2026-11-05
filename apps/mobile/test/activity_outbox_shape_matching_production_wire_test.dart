import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/offline/activity_outbox_sync.dart';

import 'support/shape_matching_production_batch_fixture.dart';

void main() {
  test('Shape Matching production envelope encodes and POSTs json-safe batch',
      () async {
    final root = await Directory.systemTemp.createTemp('lmp134-prod-wire-');
    try {
      final outbox = ActivityFileOutbox.forTesting(root);
      final batch = await ShapeMatchingProductionBatchFixture.build(
        outbox: outbox,
      );
      expect(batch.events.length, 3);
      expect(batch.sessions, hasLength(1));

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Map<String, dynamic>? captured;
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        captured = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'results': [
            for (final event in batch.events)
              {
                'event_id': event['event_id'],
                'status': 'accepted',
              },
          ],
        }));
        await request.response.close();
      });

      final sender = ActivityHttpBatchSender(
        apiBaseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      final ack = await sender.send(
        ShapeMatchingProductionBatchFixture.session(),
        batch.events,
        batch.sessions,
      );
      expect(ack['results'], hasLength(3));
      expect(captured, isNotNull);
      expect(() => jsonEncode(captured), returnsNormally);

      final wireSessions = captured!['sessions'] as List;
      final wireEvents = captured!['events'] as List;
      expect(wireSessions, hasLength(1));
      expect(wireEvents, hasLength(3));

      final session = wireSessions.single as Map<String, dynamic>;
      expect(
        session['content_version_id'],
        ShapeMatchingProductionBatchFixture.contentVersionId,
      );
      expect(
        (session['consent'] as Map)['purpose'],
        'essential_play_events',
      );
      expect(
        (session['consent'] as Map)['policy_version'],
        ShapeMatchingProductionBatchFixture.consentPolicyVersion,
      );
      final deviceId = session['device_id'] as String;
      expect(
        activityBatchUuidPattern.hasMatch(deviceId),
        isTrue,
        reason: 'parent-scoped device_id must satisfy admission UuidV4OrV7 [457]',
      );
      expect(
        deviceId,
        ShapeMatchingProductionBatchFixture.scopedDeviceId(),
        reason: 'matches backend activity-batch-admission Shape Matching v5 wire',
      );
      expect(deviceId[14], '5', reason: 'RFC4122 v5 parent-scoped digest');
      expect(
        activityBatchUtcInstantZ.hasMatch(session['started_at'] as String),
        isTrue,
      );

      for (final raw in wireEvents) {
        final event = raw as Map<String, dynamic>;
        expect(
          activityBatchUuidPattern.hasMatch(event['device_id'] as String),
          isTrue,
        );
        expect(
          event['content_version_id'],
          ShapeMatchingProductionBatchFixture.contentVersionId,
        );
        expect(
          event['consent_policy_version'],
          ShapeMatchingProductionBatchFixture.consentPolicyVersion,
        );
        expect(event.containsKey('play_session_id'), isTrue);
      }
    } finally {
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}

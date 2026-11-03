import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/offline/activity_payload_codec.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';

void main() {
  test('AES-GCM encrypted outbox round-trips without exposing event text', () async {
    final dir = await Directory.systemTemp.createTemp('encrypted-lmp51-');
    try {
      final key = SecretKey(List<int>.filled(32, 7));
      final codec = SecureActivityPayloadCodec(
        testKeyProvider: (_) async => key,
      );
      final storage = ActivityFileOutbox.forTesting(dir, codec: codec);
      const parent = '11111111-1111-4111-8111-111111111111';
      const eventId = '33333333-3333-4333-8333-333333333333';
      final rawEvent = <String, dynamic>{
        'schema_version': '1.0.0',
        'event_id': eventId,
        'event_type': 'mentor_card_opened',
        'payload': {'card_id': 'private-but-allowlisted'},
      };
      await storage.enqueue(PendingActivityEvent(
        parentId: parent, eventId: eventId, payload: rawEvent,
        createdAt: DateTime.utc(2026, 11, 2),
      ));
      final file = File('${dir.path}/$parent/$eventId.json');
      final cipherText = await file.readAsString();
      expect(cipherText, isNot(contains('private-but-allowlisted')));
      final loaded = await ActivityFileOutbox.forTesting(
          dir, codec: codec).pending(parent);
      expect(loaded.single.payload, rawEvent);
      // Tamper-detection: a changed authenticated ciphertext must not be read
      // or silently treated as delivered.
      final altered = cipherText.replaceFirst('"v":1', '"v":2');
      await file.writeAsString(altered, flush: true);
      await expectLater(storage.pending(parent), throwsA(isA<FormatException>()));
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });
}

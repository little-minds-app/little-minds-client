import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const parentId = '11111111-1111-4111-8111-111111111111';
  const deviceId = '22222222-2222-4222-8222-222222222222';
  const contentId = '018f1340-0000-4000-8000-000000000001';
  final uuid = const Uuid();

  PendingActivityEvent makeEvent(
      String sessionId, String type, int order, {String padding = ''}) {
    final eventId = uuid.v4();
    final started = DateTime.utc(2026, 11, 6).add(Duration(seconds: order));
    return PendingActivityEvent(
      parentId: parentId,
      eventId: eventId,
      createdAt: started,
      payload: {
        'schema_version': '1.0.0',
        'event_id': eventId,
        'event_type': type,
        'play_session_id': sessionId,
        'device_id': deviceId,
        'content_version_id': contentId,
        'occurred_at': started.toIso8601String(),
        'payload': {'padding': padding},
      },
      sessionPayload: {
        'schema_version': '1.0.0',
        'play_session_id': sessionId,
        'device_id': deviceId,
        'content_version_id': contentId,
        'started_at': started.toIso8601String(),
      },
    );
  }

  test('production quota is 500 events and 5 MiB per parent', () {
    expect(ActivityFileOutbox.maxRecordsPerParent, 500);
    expect(ActivityFileOutbox.maxPartitionBytes, 5 * 1024 * 1024);
  });

  test('oldest completed session is evicted as a complete FIFO group',
      () async {
    final root = await Directory.systemTemp.createTemp('lmp134-fifo-');
    try {
      final outbox = ActivityFileOutbox.forTesting(root, recordLimit: 4);
      final a = uuid.v4(), b = uuid.v4(), c = uuid.v4();
      await outbox.enqueue(makeEvent(a, 'activity_started', 1));
      await outbox.enqueue(makeEvent(a, 'activity_completed', 2));
      await outbox.enqueue(makeEvent(b, 'activity_started', 3));
      await outbox.enqueue(makeEvent(b, 'activity_completed', 4));
      await outbox.enqueue(makeEvent(c, 'activity_started', 5));
      final pending = await outbox.pending(parentId);
      expect(pending.length, 3);
      expect(pending.where((e) => e.payload['play_session_id'] == a), isEmpty);
      expect(pending.where((e) => e.payload['play_session_id'] == b).length, 2);
      expect(pending.where((e) => e.payload['play_session_id'] == c).length, 1);
      expect(outbox.droppedEventsAtCapacity, 2);
      expect(outbox.droppedSessionsAtCapacity, 1);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('an unfinished session is never half-evicted', () async {
    final root = await Directory.systemTemp.createTemp('lmp134-unfinished-');
    try {
      final outbox = ActivityFileOutbox.forTesting(root, recordLimit: 2);
      final a = uuid.v4(), b = uuid.v4(), c = uuid.v4();
      await outbox.enqueue(makeEvent(a, 'activity_started', 1));
      await outbox.enqueue(makeEvent(b, 'activity_started', 2));
      await expectLater(
        outbox.enqueue(makeEvent(c, 'activity_started', 3)),
        throwsA(isA<StateError>()),
      );
      final pending = await outbox.pending(parentId);
      expect(pending.length, 2);
      expect(pending.map((e) => e.payload['play_session_id']).toSet(), {a, b});
      expect(outbox.droppedEventsAtCapacity, 0);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('in-flight session is reserved against FIFO eviction', () async {
    final root = await Directory.systemTemp.createTemp('lmp134-inflight-');
    try {
      final outbox = ActivityFileOutbox.forTesting(root, recordLimit: 2);
      final a = uuid.v4(), b = uuid.v4();
      await outbox.enqueue(makeEvent(a, 'activity_started', 1));
      await outbox.enqueue(makeEvent(a, 'activity_completed', 2));
      final leased = await outbox.pending(parentId, reserve: true);
      expect(leased.length, 2);
      await expectLater(
        outbox.enqueue(makeEvent(b, 'activity_started', 3)),
        throwsA(isA<StateError>()),
      );
      expect((await outbox.pending(parentId)).length, 2);
      await outbox.releaseReserved(leased);
      await outbox.enqueue(makeEvent(b, 'activity_started', 4));
      expect((await outbox.pending(parentId)).single.payload['play_session_id'], b);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('encrypted-storage budget uses actual file bytes, not event count',
      () async {
    final root = await Directory.systemTemp.createTemp('lmp134-bytes-');
    try {
      final outbox = ActivityFileOutbox.forTesting(
        root, recordLimit: 50, byteLimit: 2200);
      for (var i = 0; i < 8; i++) {
        final id = uuid.v4();
        await outbox.enqueue(makeEvent(
          id, 'activity_completed', i, padding: 'p' * 450));
      }
      final dir = Directory('${root.path}/$parentId');
      final files = (await dir.list().toList()).whereType<File>().toList();
      var total = 0;
      for (final file in files) {
        total += await file.length();
      }
      expect(files.length, lessThan(8));
      expect(total, lessThanOrEqualTo(2200));
      expect(outbox.droppedEventsAtCapacity, greaterThan(0));
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('pending events remain partitioned by parent', () async {
    final root = await Directory.systemTemp.createTemp('lmp134-isolation-');
    try {
      final outbox = ActivityFileOutbox.forTesting(root, recordLimit: 2);
      final a = uuid.v4();
      await outbox.enqueue(makeEvent(a, 'activity_started', 1));
      const otherParent = '99999999-9999-4999-8999-999999999999';
      expect(await outbox.pending(otherParent), isEmpty);
      expect((await outbox.pending(parentId)).length, 1);
    } finally {
      await root.delete(recursive: true);
    }
  });
}

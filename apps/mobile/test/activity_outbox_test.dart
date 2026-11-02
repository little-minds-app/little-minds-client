import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/offline/activity_outbox_sync.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';

const parentA = '11111111-1111-4111-8111-111111111111';
const parentB = '22222222-2222-4222-8222-222222222222';
const eventA = '33333333-3333-4333-8333-333333333333';
const eventB = '44444444-4444-4444-8444-444444444444';
const sessionA = AuthSession(
  accessToken: 'access-a', refreshToken: 'refresh-a', sessionId: 'session-a',
  parentId: parentA, expiresInSeconds: 300,
);
const sessionB = AuthSession(
  accessToken: 'access-b', refreshToken: 'refresh-b', sessionId: 'session-b',
  parentId: parentB, expiresInSeconds: 300,
);

PendingActivityEvent event(String parentId, String id) => PendingActivityEvent(
  parentId: parentId, eventId: id, createdAt: DateTime.utc(2026, 11, 2),
  payload: {
    'schema_version': '1.0.0', 'event_id': id,
    'event_type': 'activity_completed', 'payload': {'completion_status': 'completed'}
  },
);

void main() {
  late Directory directory;
  late ActivityFileOutbox outbox;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lmp51-outbox-test-');
    outbox = ActivityFileOutbox.forTesting(directory);
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists across outbox instances and partitions accounts', () async {
    await outbox.enqueue(event(parentA, eventA));
    await outbox.enqueue(event(parentB, eventB));
    final restored = ActivityFileOutbox.forTesting(directory);
    expect((await restored.pending(parentA)).map((e) => e.eventId), [eventA]);
    expect((await restored.pending(parentB)).map((e) => e.eventId), [eventB]);
    await restored.acknowledge(parentA, eventA);
    expect(await restored.pending(parentA), isEmpty);
    expect(await restored.pending(parentB), hasLength(1));
  });

  test('repeated enqueue preserves stable ID and rejects divergent payload', () async {
    final original = event(parentA, eventA);
    await outbox.enqueue(original);
    await outbox.enqueue(original);
    expect(await outbox.pending(parentA), hasLength(1));
    await expectLater(
      outbox.enqueue(PendingActivityEvent(
        parentId: parentA, eventId: eventA,
        createdAt: original.createdAt,
        payload: {...original.payload, 'event_type': 'activity_abandoned'},
      )), throwsStateError);
  });

  test('offline connection loss retains event and reschedules it', () async {
    await outbox.enqueue(event(parentA, eventA));
    final sync = ActivityOutboxSync(
      outbox: outbox, currentSession: () => sessionA,
      clock: () => DateTime.utc(2026, 11, 2),
      send: (_, _, _) async => throw const SocketException('offline'),
    );
    await sync.flush();
    expect(await outbox.pending(parentA, now: DateTime.utc(2026, 11, 2)),
        isEmpty);
    final restored = ActivityFileOutbox.forTesting(directory);
    expect(await restored.pending(parentA, now: DateTime.utc(2026, 11, 3)),
        hasLength(1));
  });

  test('ACK removes only confirmed events', () async {
    await outbox.enqueue(event(parentA, eventA));
    await outbox.enqueue(event(parentA, eventB));
    final sync = ActivityOutboxSync(
      outbox: outbox, currentSession: () => sessionA,
      clock: () => DateTime.utc(2026, 11, 2),
      send: (_, _, _) async => {
        'results': [
          {'event_id': eventA, 'status': 'accepted'},
          {'event_id': eventB, 'status': 'retryable'}
        ]
      },
    );
    await sync.flush();
    expect((await outbox.pending(parentA, now: DateTime.utc(2026, 11, 3)))
        .map((e) => e.eventId), [eventB]);
  });

  test('malformed or partial ACK must not delete any record', () async {
    await outbox.enqueue(event(parentA, eventA));
    await outbox.enqueue(event(parentA, eventB));
    final sync = ActivityOutboxSync(
      outbox: outbox, currentSession: () => sessionA,
      send: (_, _, _) async => {'results': [{'event_id': eventA, 'status': 'accepted'}]},
    );
    await sync.flush();
    expect(await outbox.pending(parentA), hasLength(2));
  });

  test('account switch during HTTP request does not ACK previous account', () async {
    await outbox.enqueue(event(parentA, eventA));
    AuthSession? active = sessionA;
    final sync = ActivityOutboxSync(
      outbox: outbox, currentSession: () => active,
      send: (_, _, _) async {
        active = sessionB;
        return {'results': [{'event_id': eventA, 'status': 'accepted'}]};
      },
    );
    await sync.flush();
    expect(await outbox.pending(parentA), hasLength(1));
    expect(await outbox.pending(parentB), isEmpty);
  });

  test('permanent rejection quarantines instead of infinite retry', () async {
    await outbox.enqueue(event(parentA, eventA));
    final sync = ActivityOutboxSync(
      outbox: outbox, currentSession: () => sessionA,
      send: (_, _, _) async => {
        'results': [
          {'event_id': eventA, 'status': 'rejected',
           'reason_code': 'schema.invalid_event'}
        ]
      },
    );
    await sync.flush();
    expect(await outbox.pending(parentA), isEmpty);
    expect(File('${directory.path}/$parentA/$eventA.json.rejected').existsSync(),
        isTrue);
  });

  test('consent withdrawal purges optional pending records only', () async {
    final optional = event(parentA, eventA);
    await outbox.enqueue(PendingActivityEvent(
      parentId: parentA, eventId: eventA,
      createdAt: optional.createdAt,
      payload: {...optional.payload,
        'consent_scope': 'optional_product_analytics'},
    ));
    await outbox.enqueue(event(parentA, eventB));
    expect(await outbox.purgeConsentScope(
        parentA, 'optional_product_analytics'), 1);
    expect((await outbox.pending(parentA)).map((e) => e.eventId), [eventB]);
  });

  test('invalid UUID and forbidden identity fields fail before disk write', () async {
    await expectLater(outbox.enqueue(event('parent A', eventA)), throwsArgumentError);
    final original = event(parentA, eventA);
    await expectLater(outbox.enqueue(PendingActivityEvent(
      parentId: parentA, eventId: eventA, createdAt: original.createdAt,
      payload: {...original.payload, 'child_id': 'secret'},
    )), throwsArgumentError);
    expect(await outbox.pending(parentA), isEmpty);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/consent/essential_play_events_consent.dart';
import 'package:little_minds_mobile/consent/essential_play_events_consent_service.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_production_consent.dart';

import 'support/fake_essential_play_events_consent_client.dart';

void main() {
  const session = AuthSession(
    parentId: '11111111-1111-4111-8111-111111111111',
    sessionId: '00000000-0000-4000-8000-000000000001',
    accessToken: 'test',
    refreshToken: 'test',
    expiresInSeconds: 300,
  );

  test('grant requeues quarantined essential play without deleting archive',
      () async {
    final root = await Directory.systemTemp.createTemp('consent-requeue-');
    try {
      final outbox = ActivityFileOutbox.forTesting(root);
      final client = FakeEssentialPlayEventsConsentClient();
      final service = EssentialPlayEventsConsentService(
        client: client,
        outbox: outbox,
      );
      final partition = Directory('${root.path}/${session.parentId.toLowerCase()}');
      await partition.create(recursive: true);
      const eventId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final rejected = File('${partition.path}/$eventId.json.rejected');
      await rejected.writeAsString('''
{
  "parent_id": "${session.parentId}",
  "event_id": "$eventId",
  "payload": {"consent_scope": "${ShapeMatchingProductionConsent.scope}", "event_type": "activity_started"},
  "created_at": "2026-11-04T12:00:00Z",
  "attempts": 0
}
''');
      client.initialStatus = const EssentialPlayEventsConsentStatus(
        authorized: false,
        effectiveStatus: 'denied',
      );
      final result = await service.grant(
        session: session,
        policyVersion: 'synthetic-policy-v1',
      );
      expect(result, isA<EssentialPlayEventsConsentMutationOk>());
      expect(await rejected.exists(), isTrue);
      final pending = await outbox.pending(session.parentId);
      expect(pending, hasLength(1));
      expect(pending.single.eventId, eventId);
    } finally {
      if (await root.exists()) await root.delete(recursive: true);
    }
  });

  test('withdraw purges pending essential play events', () async {
    final root = await Directory.systemTemp.createTemp('consent-withdraw-');
    try {
      final outbox = ActivityFileOutbox.forTesting(root);
      final client = FakeEssentialPlayEventsConsentClient(
        initialStatus: const EssentialPlayEventsConsentStatus(
          authorized: true,
          effectiveStatus: 'granted',
          policyVersion: 'synthetic-policy-v1',
        ),
      );
      final service = EssentialPlayEventsConsentService(
        client: client,
        outbox: outbox,
      );
      await outbox.enqueue(
        PendingActivityEvent(
          parentId: session.parentId,
          eventId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          payload: {
            'consent_scope': ShapeMatchingProductionConsent.scope,
            'event_type': 'activity_started',
          },
          createdAt: DateTime.utc(2026, 11, 4),
        ),
      );
      expect(await outbox.pending(session.parentId), hasLength(1));
      await service.withdraw(session);
      expect(await outbox.pending(session.parentId), isEmpty);
      expect(service.hasEffectiveGrant, isFalse);
    } finally {
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}

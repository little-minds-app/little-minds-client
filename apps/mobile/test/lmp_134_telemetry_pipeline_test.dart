import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/offline/activity_event_emitter.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/offline/activity_outbox_sync.dart';
import 'package:little_minds_mobile/shape_matching/hub_authorized_device_child.dart';
import 'package:little_minds_mobile/shape_matching/hub_production_telemetry.dart';
import 'package:little_minds_mobile/shape_matching/published_content_registry.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_activity.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_events.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_local_event_buffer.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_production_event_buffer.dart';

void main() {
  const parentId = '11111111-1111-4111-8111-111111111111';
  const childId = '22222222-2222-4222-8222-222222222222';
  const deviceId = '33333333-3333-4333-8333-333333333333';
  const contentId = '018f1340-0000-4000-8000-000000000001';

  AuthSession session() => const AuthSession(
        parentId: parentId,
        sessionId: '44444444-4444-4444-8444-444444444444',
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        expiresInSeconds: 900,
      );

  group('LMP-134 play → enqueue → batch ACK', () {
    test('persist hook schedules flush and mock HTTP clears outbox', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-pipe-');
      try {
        ActivityOutboxSync? sync;
        final outbox = ActivityFileOutbox.forTesting(
          root,
          onEventPersisted: (_) => sync!.scheduleFlush(),
        );
        var batchCalls = 0;
        sync = ActivityOutboxSync(
          outbox: outbox,
          currentSession: session,
          clock: () => DateTime.utc(2026, 11, 4, 12),
          send: (_, events, __) async {
            batchCalls++;
            return {
              'results': [
                for (final event in events)
                  {
                    'event_id': event['event_id'],
                    'status': 'accepted',
                  },
              ],
            };
          },
        );

        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        await catalog.applyServerAuthorizedChild(
          parentId: parentId,
          scopedDeviceId: deviceId,
          childId: childId,
        );
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: MapPublishedContentRegistry({
            ShapeMatchingConstants.activityId: PublishedActivityPublication(
              contentVersionId: contentId,
              consentPolicyVersion: 'privacy-notice-draft-0',
            ),
          }),
          deviceChildCatalog: catalog,
        );
        final registry = ActivityRegistry([]);
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 36,
          session: session(),
          selectedChildId: childId,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingProductionEventBuffer>());

        final playSessionId = activity.playSessionId;
        activity.eventBuffer.emit(
          playSessionId: playSessionId,
          type: ShapeMatchingEventType.activityStarted,
          payload: {'age_months': 36},
        );
        activity.eventBuffer.emit(
          playSessionId: playSessionId,
          type: ShapeMatchingEventType.activityCompleted,
          payload: const {},
        );
        await (activity.eventBuffer as ShapeMatchingProductionEventBuffer)
            .drain();
        await sync.flush();

        expect(batchCalls, greaterThanOrEqualTo(1));
        expect(
          await outbox.pending(parentId, now: DateTime.utc(2026, 11, 5)),
          isEmpty,
        );
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });
  });

  group('LMP-134 telemetry negatives', () {
    test('child mismatch keeps local buffer — no batch send', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-neg-child-');
      try {
        var batchCalls = 0;
        final outbox = ActivityFileOutbox.forTesting(root);
        final sync = ActivityOutboxSync(
          outbox: outbox,
          currentSession: session,
          send: (_, __, ___) async {
            batchCalls++;
            return {'results': []};
          },
        );
        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        await catalog.applyServerAuthorizedChild(
          parentId: parentId,
          scopedDeviceId: deviceId,
          childId: childId,
        );
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: MapPublishedContentRegistry({
            ShapeMatchingConstants.activityId: PublishedActivityPublication(
              contentVersionId: contentId,
              consentPolicyVersion: 'privacy-notice-draft-0',
            ),
          }),
          deviceChildCatalog: catalog,
        );
        final registry = ActivityRegistry([]);
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 36,
          session: session(),
          selectedChildId: '55555555-5555-4555-8555-555555555555',
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingLocalEventBuffer>());
        activity.eventBuffer.emit(
          playSessionId: activity.playSessionId,
          type: ShapeMatchingEventType.activityStarted,
          payload: {'age_months': 36},
        );
        await sync.flush();
        expect(batchCalls, 0);
        expect(await outbox.pending(parentId), isEmpty);
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('consent rejection quarantines persisted event', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-neg-consent-');
      try {
        ActivityOutboxSync? sync;
        final outbox = ActivityFileOutbox.forTesting(
          root,
          onEventPersisted: (_) => sync!.scheduleFlush(),
        );
        sync = ActivityOutboxSync(
          outbox: outbox,
          currentSession: session,
          clock: () => DateTime.utc(2026, 11, 4, 12),
          send: (_, events, __) async => {
            'results': [
              for (final event in events)
                {
                  'event_id': event['event_id'],
                  'status': 'rejected',
                  'reason_code': 'consent.not_authorized',
                },
            ],
          },
        );
        final emitter = ActivityEventEmitter(
          outbox: outbox,
          session: session(),
          deviceId: deviceId,
          contentVersionId: contentId,
          consentPolicyVersion: 'privacy-notice-draft-0',
          clock: () => DateTime.utc(2026, 11, 4, 12),
        );
        const playSessionId = '66666666-6666-4666-8666-666666666666';
        await emitter.emit(
          eventType: 'activity_started',
          consentScope: 'essential_play_events',
          payload: {'age_months': 36},
          source: 'instrumented',
          emitter: 'kids_mode_client',
          playSessionId: playSessionId,
          sessionPayload: {
            'schema_version': '1.0.0',
            'play_session_id': playSessionId,
            'device_id': deviceId,
            'content_version_id': contentId,
            'started_at': '2026-11-04T12:00:00Z',
            'completion_status': 'started',
            'consent': {
              'purpose': 'essential_play_events',
              'consent_scope': 'essential_play_events',
              'policy_version': 'privacy-notice-draft-0',
              'decision': 'granted',
            },
            'provenance': {
              'emitter': 'kids_mode_client',
              'capture_channel': 'offline_queue',
              'clock_trust': 'wall_clock_only',
            },
          },
        );
        await sync.flush();
        expect(await outbox.pending(parentId), isEmpty);
        final rejected = Directory('${root.path}/${parentId.toLowerCase()}')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json.rejected'));
        expect(rejected, hasLength(1));
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('offline send postpones then ACK on retry', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-neg-offline-');
      try {
        ActivityOutboxSync? sync;
        final outbox = ActivityFileOutbox.forTesting(
          root,
          onEventPersisted: (_) => sync!.scheduleFlush(),
        );
        var attempts = 0;
        sync = ActivityOutboxSync(
          outbox: outbox,
          currentSession: session,
          clock: () => DateTime.utc(2026, 11, 4, 12),
          send: (_, events, __) async {
            attempts++;
            if (attempts == 1) {
              throw const SocketException('offline');
            }
            return {
              'results': [
                for (final event in events)
                  {
                    'event_id': event['event_id'],
                    'status': 'accepted',
                  },
              ],
            };
          },
        );
        final emitter = ActivityEventEmitter(
          outbox: outbox,
          session: session(),
          deviceId: deviceId,
          contentVersionId: contentId,
          consentPolicyVersion: 'privacy-notice-draft-0',
        );
        const playSessionId = '77777777-7777-4777-8777-777777777777';
        await emitter.emit(
          eventType: 'activity_started',
          consentScope: 'essential_play_events',
          payload: {'age_months': 36},
          source: 'instrumented',
          emitter: 'kids_mode_client',
          playSessionId: playSessionId,
          sessionPayload: {
            'schema_version': '1.0.0',
            'play_session_id': playSessionId,
            'device_id': deviceId,
            'content_version_id': contentId,
            'started_at': '2026-11-04T12:00:00Z',
            'completion_status': 'started',
            'consent': {
              'purpose': 'essential_play_events',
              'consent_scope': 'essential_play_events',
              'policy_version': 'privacy-notice-draft-0',
              'decision': 'granted',
            },
            'provenance': {
              'emitter': 'kids_mode_client',
              'capture_channel': 'offline_queue',
              'clock_trust': 'wall_clock_only',
            },
          },
        );
        await sync.flush();
        expect(
          await outbox.pending(
            parentId,
            now: DateTime.utc(2026, 11, 4, 13),
          ),
          hasLength(1),
        );
        await sync.flush();
        expect(
          await outbox.pending(
            parentId,
            now: DateTime.utc(2026, 11, 5),
          ),
          isEmpty,
        );
        expect(attempts, 2);
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('stale reconcile generation drops late production wiring', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-stale-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        await catalog.applyServerAuthorizedChild(
          parentId: parentId,
          scopedDeviceId: deviceId,
          childId: childId,
        );
        final slowRegistry = _SlowPublicationRegistry(
          delay: const Duration(milliseconds: 40),
          publication: PublishedActivityPublication(
            contentVersionId: contentId,
            consentPolicyVersion: 'privacy-notice-draft-0',
          ),
        );
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: slowRegistry,
          deviceChildCatalog: catalog,
        );
        final registry = ActivityRegistry([]);
        final first = coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 36,
          session: session(),
          selectedChildId: childId,
          deviceId: deviceId,
        );
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 36,
          session: null,
          selectedChildId: null,
          deviceId: null,
        );
        await first;
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingLocalEventBuffer>());
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });
  });
}

final class _SlowPublicationRegistry implements PublishedContentRegistry {
  _SlowPublicationRegistry({required this.delay, required this.publication});

  final Duration delay;
  final PublishedActivityPublication publication;

  @override
  void invalidate() {}

  @override
  Future<PublishedActivityPublication?> publicationForActivity(
    String activityId,
  ) async {
    await Future<void>.delayed(delay);
    if (activityId != ShapeMatchingConstants.activityId) return null;
    return publication;
  }
}

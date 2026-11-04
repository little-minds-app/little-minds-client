import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/shape_matching/hub_production_telemetry.dart';
import 'package:little_minds_mobile/shape_matching/published_content_registry.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_activity.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_events.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_production_event_buffer.dart';

void main() {
  const session = AuthSession(
    parentId: '11111111-1111-4111-8111-111111111111',
    sessionId: '00000000-0000-4000-8000-000000000001',
    accessToken: 'test',
    refreshToken: 'test',
    expiresInSeconds: 300,
  );
  const deviceId = '22222222-2222-4222-8222-222222222222';
  const contentId = '33333333-3333-4333-8333-333333333333';
  const childId = '44444444-4444-4444-8444-444444444444';

  group('HubProductionTelemetryGate', () {
    test('blocks when published content version is missing', () {
      final result = HubProductionTelemetryGate.evaluate(
        session: session,
        selectedChildId: childId,
        deviceId: deviceId,
        publishedContentVersionId: null,
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        HubProductionTelemetryBlockReason.noPublishedContentVersion,
      );
    });

    test('blocks fixture content version ids', () {
      final result = HubProductionTelemetryGate.evaluate(
        session: session,
        selectedChildId: childId,
        deviceId: deviceId,
        publishedContentVersionId: ShapeMatchingConstants.contentVersionId,
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        HubProductionTelemetryBlockReason.contentVersionNotUuid,
      );
    });

    test('allows when all gates satisfied', () {
      final result = HubProductionTelemetryGate.evaluate(
        session: session,
        selectedChildId: childId,
        deviceId: deviceId,
        publishedContentVersionId: contentId,
      );
      expect(result.allowed, isTrue);
      expect(result.playSessionId, isNotNull);
      expect(
        HubProductionTelemetryGate.isUuid(result.playSessionId!),
        isTrue,
      );
    });
  });

  group('HubProductionTelemetryCoordinator', () {
    test('reconcile uses local buffer without published registry entry', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-hub-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: FailClosedPublishedContentRegistry(),
          clock: () => DateTime.utc(2026, 11, 4, 12),
        );
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childId,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)
            as ShapeMatchingActivity?;
        expect(activity, isNotNull);
        expect(activity!.eventBuffer, isA<ShapeMatchingLocalEventBuffer>());
        expect(
          activity.eventBuffer,
          isNot(isA<ShapeMatchingProductionEventBuffer>()),
        );
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('reconcile wires production buffer when registry publishes UUID', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-hub-prod-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final content = MapPublishedContentRegistry({
          ShapeMatchingConstants.activityId: PublishedActivityPublication(
            contentVersionId: contentId,
            consentPolicyVersion: 'synthetic-policy-v1',
          ),
        });
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: content,
          clock: () => DateTime.utc(2026, 11, 4, 12),
        );
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childId,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingProductionEventBuffer>());
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('reconcile wires production buffer from pinned publication fixture',
        () async {
      final root = await Directory.systemTemp.createTemp('lmp134-hub-pin-');
      try {
        TestWidgetsFlutterBinding.ensureInitialized();
        final outbox = ActivityFileOutbox.forTesting(root);
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: PinnedActivityPublicationRegistry(),
          clock: () => DateTime.utc(2026, 11, 4, 12),
        );
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childId,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingProductionEventBuffer>());
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('logout gate falls back to local buffer on reconcile', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-hub-logout-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final content = MapPublishedContentRegistry({
          ShapeMatchingConstants.activityId: PublishedActivityPublication(
            contentVersionId: contentId,
            consentPolicyVersion: 'synthetic-policy-v1',
          ),
        });
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: content,
        );
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: null,
          selectedChildId: childId,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingLocalEventBuffer>());
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });
  });
}

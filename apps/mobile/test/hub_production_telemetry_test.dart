import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/shape_matching/hub_authorized_device_child.dart';
import 'package:little_minds_mobile/shape_matching/hub_production_telemetry.dart';
import 'package:little_minds_mobile/shape_matching/published_content_registry.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_activity.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_events.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_production_consent.dart';
import 'package:little_minds_mobile/consent/essential_play_events_consent.dart';
import 'package:little_minds_mobile/consent/essential_play_events_consent_service.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_production_event_buffer.dart';

import 'support/fake_essential_play_events_consent_client.dart';

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
  const childA = '44444444-4444-4444-8444-444444444444';
  const childB = '55555555-5555-4555-8555-555555555555';
  const parentB = '66666666-6666-4666-8666-666666666666';
  const sessionB = AuthSession(
    parentId: parentB,
    sessionId: '77777777-7777-4777-8777-777777777777',
    accessToken: 'test-b',
    refreshToken: 'test-b',
    expiresInSeconds: 300,
  );

  Future<HubProductionTelemetryCoordinator> productionCoordinator(
    ActivityFileOutbox outbox, {
    HubAuthorizedDeviceChildCatalog? catalog,
    PublishedContentRegistry? registry,
  }) async {
    final content = registry ??
        MapPublishedContentRegistry({
          ShapeMatchingConstants.activityId: PublishedActivityPublication(
            contentVersionId: contentId,
            consentPolicyVersion: 'synthetic-policy-v1',
          ),
        });
    final cat = catalog ?? MemoryHubAuthorizedDeviceChildCatalog();
    await cat.applyServerAuthorizedChild(
      parentId: session.parentId,
      scopedDeviceId: deviceId,
      childId: childA,
    );
    return HubProductionTelemetryCoordinator(
      outbox: outbox,
      contentRegistry: content,
      deviceChildCatalog: cat,
      clock: () => DateTime.utc(2026, 11, 4, 12),
    );
  }

  group('HubProductionTelemetryGate', () {
    test('blocks when published content version is missing', () {
      final result = HubProductionTelemetryGate.evaluate(
        session: session,
        selectedChildId: childA,
        deviceId: deviceId,
        authorizedDeviceChildId: childA,
        publishedContentVersionId: null,
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        HubProductionTelemetryBlockReason.noPublishedContentVersion,
      );
    });

    test('blocks when device child is not server-authorized', () {
      final result = HubProductionTelemetryGate.evaluate(
        session: session,
        selectedChildId: childA,
        deviceId: deviceId,
        authorizedDeviceChildId: null,
        publishedContentVersionId: contentId,
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        HubProductionTelemetryBlockReason.deviceChildNotAuthorized,
      );
    });

    test('blocks selected child mismatch with server device child', () {
      final result = HubProductionTelemetryGate.evaluate(
        session: session,
        selectedChildId: childB,
        deviceId: deviceId,
        authorizedDeviceChildId: childA,
        publishedContentVersionId: contentId,
      );
      expect(result.allowed, isFalse);
      expect(
        result.reason,
        HubProductionTelemetryBlockReason.selectedChildMismatch,
      );
    });

    test('blocks fixture content version ids', () {
      final result = HubProductionTelemetryGate.evaluate(
        session: session,
        selectedChildId: childA,
        deviceId: deviceId,
        authorizedDeviceChildId: childA,
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
        selectedChildId: childA,
        deviceId: deviceId,
        authorizedDeviceChildId: childA,
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
        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        await catalog.applyServerAuthorizedChild(
          parentId: session.parentId,
          scopedDeviceId: deviceId,
          childId: childA,
        );
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: FailClosedPublishedContentRegistry(),
          deviceChildCatalog: catalog,
          clock: () => DateTime.utc(2026, 11, 4, 12),
        );
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childA,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)
            as ShapeMatchingActivity?;
        expect(activity, isNotNull);
        expect(activity!.eventBuffer, isA<ShapeMatchingLocalEventBuffer>());
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('blocks production buffer without server essential_play grant', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-hub-consent-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final client = FakeEssentialPlayEventsConsentClient(
          initialStatus: const EssentialPlayEventsConsentStatus(
            authorized: false,
            effectiveStatus: 'denied',
          ),
        );
        final consent = EssentialPlayEventsConsentService(
          client: client,
          outbox: outbox,
        );
        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        await catalog.applyServerAuthorizedChild(
          parentId: session.parentId,
          scopedDeviceId: deviceId,
          childId: childA,
        );
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: MapPublishedContentRegistry({
            ShapeMatchingConstants.activityId: PublishedActivityPublication(
              contentVersionId: contentId,
              consentPolicyVersion: 'synthetic-policy-v1',
            ),
          }),
          deviceChildCatalog: catalog,
          consentService: consent,
          clock: () => DateTime.utc(2026, 11, 4, 12),
        );
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childA,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingLocalEventBuffer>());
        expect(
          coordinator.lastSnapshot?.reason,
          HubProductionTelemetryBlockReason.essentialPlayConsentNotGranted,
        );
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('reconcile wires production buffer when registry publishes UUID', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-hub-prod-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final coordinator = await productionCoordinator(outbox);
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childA,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingProductionEventBuffer>());
        final buffer = activity.eventBuffer as ShapeMatchingProductionEventBuffer;
        final consent = buffer.sessionPayload['consent'] as Map;
        expect(consent['purpose'], ShapeMatchingProductionConsent.purpose);
        expect(consent['consent_scope'], ShapeMatchingProductionConsent.scope);
        expect(consent['policy_version'], 'synthetic-policy-v1');
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
        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        await catalog.applyServerAuthorizedChild(
          parentId: session.parentId,
          scopedDeviceId: deviceId,
          childId: childA,
        );
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: PinnedActivityPublicationRegistry(),
          deviceChildCatalog: catalog,
          clock: () => DateTime.utc(2026, 11, 4, 12),
        );
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childA,
          deviceId: deviceId,
        );
        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingProductionEventBuffer>());
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('child A→B→A keeps production only when device child matches', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-child-switch-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        await catalog.applyServerAuthorizedChild(
          parentId: session.parentId,
          scopedDeviceId: deviceId,
          childId: childA,
        );
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: MapPublishedContentRegistry({
            ShapeMatchingConstants.activityId: PublishedActivityPublication(
              contentVersionId: contentId,
              consentPolicyVersion: 'synthetic-policy-v1',
            ),
          }),
          deviceChildCatalog: catalog,
        );
        final registry = ActivityRegistry();
        Future<void> reconcile(String? selected) async {
          await coordinator.reconcileHubRegistry(
            registry: registry,
            ageMonthsProvider: () => 30,
            session: session,
            selectedChildId: selected,
            deviceId: deviceId,
          );
        }

        ShapeMatchingActivity activity() =>
            registry.findById(ShapeMatchingConstants.activityId)!
                as ShapeMatchingActivity;

        await reconcile(childA);
        expect(activity().eventBuffer, isA<ShapeMatchingProductionEventBuffer>());

        await reconcile(childB);
        expect(activity().eventBuffer, isA<ShapeMatchingLocalEventBuffer>());

        await reconcile(childA);
        expect(activity().eventBuffer, isA<ShapeMatchingProductionEventBuffer>());
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('parent A→B→A preserves catalog partitions and production gates',
        () async {
      final root = await Directory.systemTemp.createTemp('lmp134-parent-switch-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: MapPublishedContentRegistry({
            ShapeMatchingConstants.activityId: PublishedActivityPublication(
              contentVersionId: contentId,
              consentPolicyVersion: 'synthetic-policy-v1',
            ),
          }),
          deviceChildCatalog: catalog,
        );
        await catalog.applyServerAuthorizedChild(
          parentId: session.parentId,
          scopedDeviceId: deviceId,
          childId: childA,
        );
        await catalog.applyServerAuthorizedChild(
          parentId: parentB,
          scopedDeviceId: deviceId,
          childId: childB,
        );
        final registry = ActivityRegistry();

        ShapeMatchingActivity activity() =>
            registry.findById(ShapeMatchingConstants.activityId)!
                as ShapeMatchingActivity;

        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childA,
          deviceId: deviceId,
        );
        expect(activity().eventBuffer, isA<ShapeMatchingProductionEventBuffer>());

        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: sessionB,
          selectedChildId: childB,
          deviceId: deviceId,
        );
        expect(activity().eventBuffer, isA<ShapeMatchingProductionEventBuffer>());

        await catalog.clearParent(parentB);
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childA,
          deviceId: deviceId,
        );
        expect(activity().eventBuffer, isA<ShapeMatchingProductionEventBuffer>());
        expect(
          await catalog.authorizedChildId(
            parentId: parentB,
            scopedDeviceId: deviceId,
          ),
          isNull,
        );
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('stale async reconcile does not register after rapid switches', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-stale-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final slowRegistry = _SlowPublishedContentRegistry(
          delay: const Duration(milliseconds: 40),
          inner: MapPublishedContentRegistry({
            ShapeMatchingConstants.activityId: PublishedActivityPublication(
              contentVersionId: contentId,
              consentPolicyVersion: 'synthetic-policy-v1',
            ),
          }),
        );
        final catalog = MemoryHubAuthorizedDeviceChildCatalog();
        await catalog.applyServerAuthorizedChild(
          parentId: session.parentId,
          scopedDeviceId: deviceId,
          childId: childA,
        );
        final coordinator = HubProductionTelemetryCoordinator(
          outbox: outbox,
          contentRegistry: slowRegistry,
          deviceChildCatalog: catalog,
        );
        final registry = ActivityRegistry();

        final first = coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: session,
          selectedChildId: childA,
          deviceId: deviceId,
        );
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: null,
          selectedChildId: childA,
          deviceId: deviceId,
        );
        await first;

        final activity = registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
        expect(activity.eventBuffer, isA<ShapeMatchingLocalEventBuffer>());
      } finally {
        if (await root.exists()) await root.delete(recursive: true);
      }
    });

    test('logout gate falls back to local buffer on reconcile', () async {
      final root = await Directory.systemTemp.createTemp('lmp134-hub-logout-');
      try {
        final outbox = ActivityFileOutbox.forTesting(root);
        final coordinator = await productionCoordinator(outbox);
        final registry = ActivityRegistry();
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 30,
          session: null,
          selectedChildId: childA,
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

final class _SlowPublishedContentRegistry implements PublishedContentRegistry {
  _SlowPublishedContentRegistry({
    required this.delay,
    required this.inner,
  });

  final Duration delay;
  final PublishedContentRegistry inner;

  @override
  Future<PublishedActivityPublication?> publicationForActivity(
    String activityId,
  ) async {
    await Future<void>.delayed(delay);
    return inner.publicationForActivity(activityId);
  }

  @override
  void invalidate() => inner.invalidate();
}

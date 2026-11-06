import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/shape_matching/hub_authorized_device_child.dart';
import 'package:little_minds_mobile/shape_matching/hub_production_telemetry.dart';
import 'package:little_minds_mobile/shape_matching/published_content_registry.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_activity.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_production_event_buffer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parent = AuthSession(
    parentId: '11111111-1111-4111-8111-111111111111',
    sessionId: '22222222-2222-4222-8222-222222222222',
    accessToken: 'test',
    refreshToken: 'test',
    expiresInSeconds: 300,
  );
  const childId = '33333333-3333-4333-8333-333333333333';
  const deviceId = '44444444-4444-4444-8444-444444444444';

  test('successive hub plays and restart receive separate session IDs and buffers',
      () async {
    final root = await Directory.systemTemp.createTemp('lmp134-reentry-');
    try {
      final catalog = MemoryHubAuthorizedDeviceChildCatalog();
      await catalog.applyServerAuthorizedChild(
        parentId: parent.parentId,
        scopedDeviceId: deviceId,
        childId: childId,
      );
      final coordinator = HubProductionTelemetryCoordinator(
        outbox: ActivityFileOutbox.forTesting(root),
        contentRegistry: MapPublishedContentRegistry({
          ShapeMatchingConstants.activityId: const PublishedActivityPublication(
            contentVersionId: '018f1340-0000-4000-8000-000000000001',
            consentPolicyVersion: 'synthetic-policy-v1',
          ),
        }),
        deviceChildCatalog: catalog,
      );
      final registry = ActivityRegistry();
      Future<ShapeMatchingActivity> nextPlay() async {
        await coordinator.reconcileHubRegistry(
          registry: registry,
          ageMonthsProvider: () => 36,
          session: parent,
          selectedChildId: childId,
          deviceId: deviceId,
        );
        return registry.findById(ShapeMatchingConstants.activityId)!
            as ShapeMatchingActivity;
      }

      final first = await nextPlay();
      expect(first.eventBuffer, isA<ShapeMatchingProductionEventBuffer>());
      expect(first.interactionsEnabled, isTrue);
      first.onOutcome(const ActivityCompletedOutcome());
      expect(first.interactionsEnabled, isFalse);
      await (first.eventBuffer as ShapeMatchingProductionEventBuffer).drain();

      final second = await nextPlay();
      expect(identical(first, second), isFalse);
      expect(first.playSessionId, isNot(second.playSessionId));
      expect(identical(first.eventBuffer, second.eventBuffer), isFalse);
      expect(second.interactionsEnabled, isTrue);
      expect(second.lastOutcome, isNull);
      second.onOutcome(const ActivityCompletedOutcome());
      await (second.eventBuffer as ShapeMatchingProductionEventBuffer).drain();

      final restarted = await nextPlay();
      expect(second.playSessionId, isNot(restarted.playSessionId));
      expect(restarted.interactionsEnabled, isTrue);
      expect(restarted.lastOutcome, isNull);
    } finally {
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_constants.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_events.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_production_consent.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_production_event_buffer.dart';
import 'package:little_minds_mobile/offline/activity_event_emitter.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/shape_matching/hub_production_telemetry.dart';
import 'package:little_minds_mobile/shape_matching/published_content_registry.dart';

void main() {
  test('Color Sorting production adapter writes canonical envelopes', () async {
    final root = await Directory.systemTemp.createTemp('lmp56-color-');
    try {
      const parentId = '11111111-1111-4111-8111-111111111111';
      const deviceId = '22222222-2222-4222-8222-222222222222';
      const contentId = '55555555-5555-4555-8555-555555555555';
      const sessionId = '66666666-6666-4666-8666-666666666666';
      final outbox = ActivityFileOutbox.forTesting(root);
      final emitter = ActivityEventEmitter(
        outbox: outbox,
        session: const AuthSession(
          parentId: parentId,
          sessionId: 'auth-session',
          accessToken: 'test',
          refreshToken: 'test',
          expiresInSeconds: 300,
        ),
        deviceId: deviceId,
        contentVersionId: contentId,
        consentPolicyVersion: 'privacy-notice-draft-0',
        clock: () => DateTime.utc(2026, 11, 6, 12),
      );
      final bridge = ColorSortingProductionEventBuffer(
        emitter: emitter,
        sessionPayload: {
          'schema_version': '1.0.0',
          'play_session_id': sessionId,
          'device_id': deviceId,
          'content_version_id': contentId,
          'started_at': '2026-11-06T12:00:00Z',
          'completion_status': 'started',
          'consent': {
            'purpose': ColorSortingProductionConsent.purpose,
            'consent_scope': ColorSortingProductionConsent.scope,
            'policy_version': 'privacy-notice-draft-0',
            'decision': 'granted',
          },
          'provenance': {
            'emitter': 'kids_mode_client',
            'capture_channel': 'offline_queue',
            'clock_trust': 'wall_clock_only',
          },
        },
        deviceId: deviceId,
        contentVersionId: contentId,
      );
      bridge.emit(
        playSessionId: sessionId,
        type: ColorSortingEventType.activityStarted,
        payload: {'age_months': 30, 'activity_variant_id': 'color_sorting'},
      );
      bridge.emit(
        playSessionId: sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'red',
          'bin_id': 'red',
          'correct': true,
          'round_index': 0,
        },
      );
      bridge.emit(
        playSessionId: sessionId,
        type: ColorSortingEventType.activityCompleted,
        payload: {'completion_status': 'completed'},
      );
      await bridge.drain();
      final events = await outbox.pending(parentId);
      expect(events, hasLength(3));
      final attempted = events.singleWhere(
        (e) => e.payload['event_type'] == 'activity_attempted',
      );
      expect(attempted.payload['payload'], containsPair('attempt_index', 0));
      expect(
        (attempted.payload['payload'] as Map).containsKey('color_id'),
        isFalse,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('pinned registry fails closed for Color Sorting content version',
      () async {
    final registry = PinnedActivityPublicationRegistry();
    final publication = await registry.publicationForActivity(
      ColorSortingConstants.activityId,
    );
    expect(publication, isNull);

    final closed = HubProductionTelemetryGate.evaluate(
      session: const AuthSession(
        parentId: '11111111-1111-4111-8111-111111111111',
        sessionId: 'auth',
        accessToken: 't',
        refreshToken: 't',
        expiresInSeconds: 60,
      ),
      selectedChildId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      deviceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      authorizedDeviceChildId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      publishedContentVersionId: null,
    );
    expect(closed.allowed, isFalse);
    expect(
      closed.reason,
      HubProductionTelemetryBlockReason.noPublishedContentVersion,
    );
  });

  test('local fixture content version is never treated as production UUID', () {
    expect(
      HubProductionTelemetryGate.isUuid(ColorSortingConstants.contentVersionId),
      isFalse,
    );
  });

  test('first-attempt tallies count only first try per round', () async {
    final root = await Directory.systemTemp.createTemp('lmp56-first-');
    try {
      final harness = await _ProductionHarness.create(root);
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityStarted,
        payload: {'age_months': 36},
      );
      // Round 0: wrong → wrong → correct — one eligible, zero correct-first.
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'red',
          'bin_id': 'blue',
          'correct': false,
          'round_index': 0,
        },
      );
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'red',
          'bin_id': 'yellow',
          'correct': false,
          'round_index': 0,
        },
      );
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'red',
          'bin_id': 'red',
          'correct': true,
          'round_index': 0,
        },
      );
      // Round 1: first-try success.
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'blue',
          'bin_id': 'blue',
          'correct': true,
          'round_index': 1,
        },
      );
      // Round 2: first-try success.
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'yellow',
          'bin_id': 'yellow',
          'correct': true,
          'round_index': 2,
        },
      );
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityCompleted,
        payload: {'completion_status': 'completed'},
      );
      await harness.bridge.drain();

      final completed = (await harness.outbox.pending(harness.parentId))
          .singleWhere((e) => e.payload['event_type'] == 'activity_completed');
      final payload = completed.payload['payload'] as Map;
      expect(payload['eligible_first_attempts'], 3);
      expect(payload['correct_first_attempts'], 2);
      expect(payload['scoring'], 'neutral');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('replay restart clears first-attempt tallies for new session', () async {
    final root = await Directory.systemTemp.createTemp('lmp56-replay-');
    try {
      final harness = await _ProductionHarness.create(root);
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityStarted,
        payload: {'age_months': 40},
      );
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'red',
          'bin_id': 'red',
          'correct': true,
          'round_index': 0,
        },
      );
      // Replay boundary.
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityStarted,
        payload: {'age_months': 40, 'restart': true},
      );
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'blue',
          'bin_id': 'yellow',
          'correct': false,
          'round_index': 0,
        },
      );
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityAttempted,
        payload: {
          'color_id': 'blue',
          'bin_id': 'blue',
          'correct': true,
          'round_index': 0,
        },
      );
      harness.bridge.emit(
        playSessionId: harness.sessionId,
        type: ColorSortingEventType.activityCompleted,
        payload: {'completion_status': 'completed'},
      );
      await harness.bridge.drain();

      final completed = (await harness.outbox.pending(harness.parentId))
          .where((e) => e.payload['event_type'] == 'activity_completed')
          .last;
      final payload = completed.payload['payload'] as Map;
      // Only post-replay first attempts (round 0 wrong-first) count.
      expect(payload['eligible_first_attempts'], 1);
      expect(payload['correct_first_attempts'], 0);
    } finally {
      await root.delete(recursive: true);
    }
  });
}

class _ProductionHarness {
  _ProductionHarness({
    required this.parentId,
    required this.sessionId,
    required this.outbox,
    required this.bridge,
  });

  final String parentId;
  final String sessionId;
  final ActivityFileOutbox outbox;
  final ColorSortingProductionEventBuffer bridge;

  static Future<_ProductionHarness> create(Directory root) async {
    const parentId = '11111111-1111-4111-8111-111111111111';
    const deviceId = '22222222-2222-4222-8222-222222222222';
    const contentId = '55555555-5555-4555-8555-555555555555';
    const sessionId = '66666666-6666-4666-8666-666666666666';
    final outbox = ActivityFileOutbox.forTesting(root);
    final emitter = ActivityEventEmitter(
      outbox: outbox,
      session: const AuthSession(
        parentId: parentId,
        sessionId: 'auth-session',
        accessToken: 'test',
        refreshToken: 'test',
        expiresInSeconds: 300,
      ),
      deviceId: deviceId,
      contentVersionId: contentId,
      consentPolicyVersion: 'privacy-notice-draft-0',
      clock: () => DateTime.utc(2026, 11, 6, 12),
    );
    final bridge = ColorSortingProductionEventBuffer(
      emitter: emitter,
      sessionPayload: {
        'schema_version': '1.0.0',
        'play_session_id': sessionId,
        'device_id': deviceId,
        'content_version_id': contentId,
        'started_at': '2026-11-06T12:00:00Z',
        'completion_status': 'started',
        'consent': {
          'purpose': ColorSortingProductionConsent.purpose,
          'consent_scope': ColorSortingProductionConsent.scope,
          'policy_version': 'privacy-notice-draft-0',
          'decision': 'granted',
        },
        'provenance': {
          'emitter': 'kids_mode_client',
          'capture_channel': 'offline_queue',
          'clock_trust': 'wall_clock_only',
        },
      },
      deviceId: deviceId,
      contentVersionId: contentId,
    );
    return _ProductionHarness(
      parentId: parentId,
      sessionId: sessionId,
      outbox: outbox,
      bridge: bridge,
    );
  }
}

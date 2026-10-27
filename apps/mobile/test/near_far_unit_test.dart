import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/game/hitbox_scaler.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';
import 'package:little_minds_mobile/near_far/near_far_activity.dart';
import 'package:little_minds_mobile/near_far/near_far_constants.dart';
import 'package:little_minds_mobile/near_far/near_far_events.dart';
import 'package:little_minds_mobile/near_far/near_far_mentor_metadata.dart';
import 'package:little_minds_mobile/near_far/near_far_mission_handoff.dart';
import 'package:little_minds_mobile/near_far/near_far_relation.dart';
import 'package:little_minds_mobile/near_far/near_far_spoken_labels.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle({this.presentPaths = const {}});

  final Set<String> presentPaths;

  @override
  Future<ByteData> load(String key) async {
    if (!presentPaths.contains(key)) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode('wav')));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NearFarRelationLogic', () {
    test('TC-NF-001 classifies near / far / neither on design canvas', () {
      final near = NearFarRelationLogic.nearPositions();
      expect(
        NearFarRelationLogic.classify(a: near.sock, b: near.softToy),
        NearFarRelation.near,
      );

      final far = NearFarRelationLogic.initialFarPositions();
      expect(
        NearFarRelationLogic.classify(a: far.sock, b: far.softToy),
        NearFarRelation.far,
      );

      // Mid-canvas spacing between nearMax (0.22) and farMin (0.48) of diagonal.
      expect(
        NearFarRelationLogic.classify(
          a: const Offset(280, 225),
          b: const Offset(520, 225),
        ),
        NearFarRelation.neither,
      );
    });

    test('TC-NF-002 age band accepts 32-month focus and rejects out of band', () {
      expect(NearFarRelationLogic.isAgeEligible(32), isTrue);
      expect(NearFarRelationLogic.isAgeEligible(30), isTrue);
      expect(NearFarRelationLogic.isAgeEligible(35), isTrue);
      expect(NearFarRelationLogic.isAgeEligible(29), isFalse);
      expect(NearFarRelationLogic.isAgeEligible(36), isFalse);
    });
  });

  group('NearFarLocalEventBuffer', () {
    test('TC-NF-003 emits versioned allowlisted envelopes without PII', () {
      var n = 0;
      final buffer = NearFarLocalEventBuffer(
        idFactory: () => 'evt-${n++}',
        clock: () => DateTime.utc(2026, 10, 27, 12),
      );

      final event = buffer.emit(
        playSessionId: 'session-1',
        type: NearFarEventType.activityCompleted,
        payload: const {
          'completion_status': 'completed',
          'scoring': 'neutral',
        },
        monotonicDurationSeconds: 84,
      );

      expect(event.schemaVersion, NearFarConstants.eventSchemaVersion);
      expect(event.eventType, 'activity_completed');
      expect(event.toJson()['play_session_id'], 'session-1');
      expect(event.toJson()['content_version_id'], NearFarConstants.contentVersionId);
      expect(NearFarEventPrivacy.payloadLooksSafe(event.payload), isTrue);
    });

    test('TC-NF-004 rejects unknown types and forbidden payload keys', () {
      final buffer = NearFarLocalEventBuffer(idFactory: () => 'x');

      expect(
        () => buffer.emit(
          playSessionId: 's',
          type: NearFarEventType.activityAttempted,
          payload: const {'raw_touch': '[0,1]'},
        ),
        throwsArgumentError,
      );

      expect(
        NearFarEventType.isAllowlisted('not_a_real_event'),
        isFalse,
      );
      expect(
        NearFarEventPrivacy.payloadLooksSafe({'pointer_x': 12}),
        isFalse,
      );
    });
  });

  group('NearFarMissionHandoff + mentor adjacency', () {
    test('TC-NF-005 safe handoff offer/start/skip/complete/dismiss lifecycle',
        () {
      final controller = NearFarMissionHandoffController();
      expect(controller.handoff.state, NearFarMissionHandoffState.unavailable);

      final offered = controller.offer();
      expect(offered.isAvailable, isTrue);
      expect(offered.materials, contains('one sock'));
      expect(offered.safetyNotes, isNotEmpty);
      expect(offered.showsPanel, isTrue);

      final opened = controller.start();
      expect(opened.state, NearFarMissionHandoffState.opened);
      // Idempotent start while already opened.
      expect(controller.start().state, NearFarMissionHandoffState.opened);

      final completed = controller.completeOptionally();
      expect(completed.state, NearFarMissionHandoffState.completed);
      expect(completed.isTerminalCalm, isTrue);
      // Cannot complete twice / from completed.
      expect(
        controller.completeOptionally().state,
        NearFarMissionHandoffState.completed,
      );

      controller.reset();
      controller.offer();
      expect(controller.skip().state, NearFarMissionHandoffState.skipped);
      // Skip is idempotent and never moves completed→skipped wrongly.
      expect(controller.skip().state, NearFarMissionHandoffState.skipped);
      expect(controller.dismiss().state, NearFarMissionHandoffState.dismissed);
      expect(controller.handoff.showsPanel, isFalse);
    });

    test('TC-NF-006 mentor adjacency metadata only (no parent UI)', () {
      const mentor = NearFarMentorAdjacency();
      final json = mentor.toMetadataJson();
      expect(json['parent_ui'], isFalse);
      expect(json['mentor_card_id'], NearFarConstants.mentorCardId);
      expect(json['mentor_card_id'], 'near_far_play_mentor');
      expect(json['schema_version'], '1.0.0');
      expect(json['backend_content_pin_sha'], isA<String>());
      expect(json['during_copy_keys'], isA<List>());
    });

    test('TC-NF-017 skip from offered never requires proof fields', () {
      final controller = NearFarMissionHandoffController();
      controller.offer();
      final skipped = controller.skip();
      expect(skipped.state, NearFarMissionHandoffState.skipped);
      expect(skipped.materials, isNotEmpty);
      // Payload shape for feedback is validated via activity emission tests.
    });
  });

  group('NearFarSpokenLabels', () {
    test('TC-NF-007 missing licensed assets report not ready (no fake play)',
        () async {
      final labels = NearFarSpokenLabels(
        bundle: _Bundle(),
        player: RecordingNearFarLabelPlayer(),
      );
      expect(await labels.areAssetsPresent('en-US'), isFalse);
      expect(await labels.areSpokenLabelsReady('en-US'), isFalse);
      final played = await labels.speak(
        NearFarSpokenStem.near,
        localeTag: 'en-US',
      );
      expect(played, isFalse);
    });

    test('TC-NF-008 present assets + capable player speak; soundOff skips',
        () async {
      final near = NearFarSpokenLabels.assetPath(NearFarSpokenStem.near, 'tr-TR');
      final far = NearFarSpokenLabels.assetPath(NearFarSpokenStem.far, 'tr-TR');
      final player = RecordingNearFarLabelPlayer();
      final labels = NearFarSpokenLabels(
        bundle: _Bundle(presentPaths: {near, far}),
        player: player,
      );
      expect(await labels.areAssetsPresent('tr-TR'), isTrue);
      expect(await labels.areSpokenLabelsReady('tr-TR'), isTrue);
      expect(
        await labels.speak(NearFarSpokenStem.far, localeTag: 'tr-TR'),
        isTrue,
      );
      expect(player.plays, [far]);
      expect(
        await labels.speak(
          NearFarSpokenStem.near,
          localeTag: 'tr-TR',
          soundOff: true,
        ),
        isFalse,
      );
    });

    test(
        'TC-NF-013 UnavailableNearFarLabelPlayer never reports spoken readiness',
        () async {
      final near = NearFarSpokenLabels.assetPath(NearFarSpokenStem.near, 'en-US');
      final far = NearFarSpokenLabels.assetPath(NearFarSpokenStem.far, 'en-US');
      final labels = NearFarSpokenLabels(
        bundle: _Bundle(presentPaths: {near, far}),
        player: const UnavailableNearFarLabelPlayer(),
      );
      expect(await labels.areAssetsPresent('en-US'), isTrue);
      expect(labels.player.canPlay, isFalse);
      expect(await labels.areSpokenLabelsReady('en-US'), isFalse);
      expect(
        await labels.speak(NearFarSpokenStem.near, localeTag: 'en-US'),
        isFalse,
      );
    });
  });

  group('NearFarActivity offline session', () {
    test('TC-NF-009 prepare offline, near then far, mission offered + events',
        () async {
      var i = 0;
      final events = NearFarLocalEventBuffer(idFactory: () => 'e-${i++}');
      final activity = NearFarActivity(
        eventBuffer: events,
        playSessionId: 'sess-nf',
        ageMonths: 32,
        localeTag: 'en-US',
        spokenLabels: NearFarSpokenLabels(bundle: _Bundle()),
      );

      await activity.prepare();
      expect(activity.spokenAssetsPresent, isFalse);
      expect(activity.spokenLabelsReady, isFalse);
      await activity.onEnter();

      final near = NearFarRelationLogic.nearPositions();
      activity.moveSock(near.sock);
      activity.moveSoftToy(near.softToy);
      expect(activity.achievedNear, isTrue);
      expect(activity.prompt, NearFarPromptStep.makeFar);

      final far = NearFarRelationLogic.initialFarPositions();
      activity.moveSock(far.sock);
      activity.moveSoftToy(far.softToy);
      expect(activity.achievedFar, isTrue);
      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      expect(
        activity.missionHandoff.handoff.state,
        NearFarMissionHandoffState.offered,
      );

      final types = events.events.map((e) => e.eventType).toList();
      expect(types, contains('activity_started'));
      expect(types, contains('activity_attempted'));
      expect(types, contains('activity_completed'));
      expect(types, contains('real_world_mission_offered'));

      for (final event in events.events) {
        expect(event.schemaVersion, 1);
        expect(NearFarEventType.isAllowlisted(event.eventType), isTrue);
        expect(NearFarEventPrivacy.payloadLooksSafe(event.payload), isTrue);
        expect(event.payload.containsKey('raw_touch'), isFalse);
      }
    });

    test('TC-NF-010 ineligible age fails prepare (offline gate)', () async {
      final activity = NearFarActivity(ageMonths: 24);
      expect(activity.prepare, throwsStateError);
    });

    test('TC-NF-011 capture/restore play state preserves coarse centers',
        () async {
      final activity = NearFarActivity(playSessionId: 's');
      await activity.prepare();
      activity.moveSock(const Offset(100, 200));
      final snap = activity.capturePlayState();
      expect(snap.containsKey('sock_x'), isTrue);
      expect(snap.containsKey('raw_touch'), isFalse);

      final other = NearFarActivity(playSessionId: 's2');
      await other.prepare();
      await other.restorePlayState(snap);
      expect(other.sockPosition, const Offset(100, 200));
    });

    test('TC-NF-012 hitbox targets stay ≥44 logical on phone landscape', () {
      const viewport = Size(844, 390);
      final rect = HitboxScaler.scaleRect(
        Rect.fromCenter(
          center: const Offset(400, 225),
          width: NearFarConstants.designObjectSize,
          height: NearFarConstants.designObjectSize,
        ),
        viewport: viewport,
      );
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
    });

    test('TC-NF-014 restart resets event-state and allows repeat completion',
        () async {
      var i = 0;
      final events = NearFarLocalEventBuffer(idFactory: () => 'r-${i++}');
      final activity = NearFarActivity(
        eventBuffer: events,
        playSessionId: 'restart-sess',
        spokenLabels: NearFarSpokenLabels(bundle: _Bundle()),
      );
      await activity.prepare();
      await activity.onEnter();

      void completeOnce() {
        final near = NearFarRelationLogic.nearPositions();
        activity.moveSock(near.sock);
        activity.moveSoftToy(near.softToy);
        final far = NearFarRelationLogic.initialFarPositions();
        activity.moveSock(far.sock);
        activity.moveSoftToy(far.softToy);
      }

      completeOnce();
      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      expect(
        events.events.where((e) => e.eventType == 'activity_completed').length,
        1,
      );

      await activity.onRestart();
      expect(activity.prompt, NearFarPromptStep.makeNear);
      expect(activity.lastOutcome, isNull);
      expect(
        activity.missionHandoff.handoff.state,
        NearFarMissionHandoffState.unavailable,
      );
      expect(activity.interactionsEnabled, isTrue);
      expect(
        events.events.where((e) => e.eventType == 'activity_started').length,
        2,
      );
      expect(
        events.events.lastWhere((e) => e.eventType == 'activity_started').payload,
        containsPair('restart', true),
      );

      completeOnce();
      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      expect(
        events.events.where((e) => e.eventType == 'activity_completed').length,
        2,
      );
      expect(
        events.events
            .where((e) => e.eventType == 'real_world_mission_offered')
            .length,
        2,
      );
    });

    test('TC-NF-015 pause/background ignore moves; close abandons once',
        () async {
      var i = 0;
      final events = NearFarLocalEventBuffer(idFactory: () => 'l-${i++}');
      final activity = NearFarActivity(
        eventBuffer: events,
        playSessionId: 'life-sess',
        spokenLabels: NearFarSpokenLabels(bundle: _Bundle()),
      );
      await activity.prepare();
      await activity.onEnter();

      await activity.onPause();
      expect(activity.interactionsEnabled, isFalse);
      final before = activity.sockPosition;
      activity.moveSock(NearFarRelationLogic.nearPositions().sock);
      expect(activity.sockPosition, before);

      await activity.onResume();
      expect(activity.interactionsEnabled, isTrue);

      await activity.onBackground();
      expect(activity.interactionsEnabled, isFalse);

      await activity.onExit();
      expect(
        events.events.where((e) => e.eventType == 'activity_abandoned').length,
        1,
      );
      // Duplicate abandon path (controller may also report abandoned).
      activity.onOutcome(const ActivityAbandonedOutcome());
      expect(
        events.events.where((e) => e.eventType == 'activity_abandoned').length,
        1,
      );
    });

    test('TC-NF-016 mission open is idempotent (no duplicate opened events)',
        () async {
      var i = 0;
      final events = NearFarLocalEventBuffer(idFactory: () => 'm-${i++}');
      final activity = NearFarActivity(
        eventBuffer: events,
        playSessionId: 'mission-sess',
        spokenLabels: NearFarSpokenLabels(bundle: _Bundle()),
      );
      await activity.prepare();
      await activity.onEnter();
      final near = NearFarRelationLogic.nearPositions();
      activity.moveSock(near.sock);
      activity.moveSoftToy(near.softToy);
      final far = NearFarRelationLogic.initialFarPositions();
      activity.moveSock(far.sock);
      activity.moveSoftToy(far.softToy);

      activity.openMissionHandoff();
      activity.openMissionHandoff();
      expect(
        events.events
            .where((e) => e.eventType == 'real_world_mission_opened')
            .length,
        1,
      );
    });

    test('TC-NF-018 skip emits mission_feedback_submitted once; no proof',
        () async {
      var i = 0;
      final events = NearFarLocalEventBuffer(idFactory: () => 'sk-${i++}');
      final activity = NearFarActivity(
        eventBuffer: events,
        playSessionId: 'skip-sess',
        spokenLabels: NearFarSpokenLabels(bundle: _Bundle()),
      );
      await activity.prepare();
      await activity.onEnter();
      final near = NearFarRelationLogic.nearPositions();
      activity.moveSock(near.sock);
      activity.moveSoftToy(near.softToy);
      final far = NearFarRelationLogic.initialFarPositions();
      activity.moveSock(far.sock);
      activity.moveSoftToy(far.softToy);

      activity.skipMissionHandoff();
      activity.skipMissionHandoff();
      final feedback = events.events
          .where((e) => e.eventType == 'mission_feedback_submitted')
          .toList();
      expect(feedback, hasLength(1));
      expect(feedback.single.payload['status'], 'skipped');
      expect(feedback.single.payload['source'], 'caregiver_report');
      expect(feedback.single.payload['proof_required'], isFalse);
      expect(feedback.single.payload.containsKey('photo'), isFalse);
      expect(
        activity.missionHandoff.handoff.state,
        NearFarMissionHandoffState.skipped,
      );
    });

    test('TC-NF-019 start then optional complete emits tried_together once',
        () async {
      var i = 0;
      final events = NearFarLocalEventBuffer(idFactory: () => 'done-${i++}');
      final activity = NearFarActivity(
        eventBuffer: events,
        playSessionId: 'done-sess',
        spokenLabels: NearFarSpokenLabels(bundle: _Bundle()),
      );
      await activity.prepare();
      await activity.onEnter();
      final near = NearFarRelationLogic.nearPositions();
      activity.moveSock(near.sock);
      activity.moveSoftToy(near.softToy);
      final far = NearFarRelationLogic.initialFarPositions();
      activity.moveSock(far.sock);
      activity.moveSoftToy(far.softToy);

      activity.startMissionHandoff();
      activity.completeMissionOptionally();
      activity.completeMissionOptionally();
      final feedback = events.events
          .where((e) => e.eventType == 'mission_feedback_submitted')
          .toList();
      expect(feedback, hasLength(1));
      expect(feedback.single.payload['status'], 'tried_together');
      expect(
        activity.missionHandoff.handoff.state,
        NearFarMissionHandoffState.completed,
      );
    });

    test('TC-NF-020 restart clears mission skip/complete flags for repeat',
        () async {
      var i = 0;
      final events = NearFarLocalEventBuffer(idFactory: () => 'rep-${i++}');
      final activity = NearFarActivity(
        eventBuffer: events,
        playSessionId: 'rep-sess',
        spokenLabels: NearFarSpokenLabels(bundle: _Bundle()),
      );
      await activity.prepare();
      await activity.onEnter();

      void completeDigital() {
        final near = NearFarRelationLogic.nearPositions();
        activity.moveSock(near.sock);
        activity.moveSoftToy(near.softToy);
        final far = NearFarRelationLogic.initialFarPositions();
        activity.moveSock(far.sock);
        activity.moveSoftToy(far.softToy);
      }

      completeDigital();
      activity.skipMissionHandoff();
      expect(
        activity.missionHandoff.handoff.state,
        NearFarMissionHandoffState.skipped,
      );

      await activity.onRestart();
      expect(
        activity.missionHandoff.handoff.state,
        NearFarMissionHandoffState.unavailable,
      );
      completeDigital();
      activity.startMissionHandoff();
      activity.completeMissionOptionally();
      expect(
        events.events
            .where((e) => e.eventType == 'mission_feedback_submitted')
            .length,
        2,
      );
      expect(
        events.events
            .where((e) => e.eventType == 'mission_feedback_submitted')
            .last
            .payload['status'],
        'tried_together',
      );
    });
  });
}

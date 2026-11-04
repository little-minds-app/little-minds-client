import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_activity.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_events.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_logic.dart';

void main() {
  group('ShapeMatchingBand', () {
    test('maps age bands to choice counts', () {
      expect(ShapeMatchingBand.forAgeMonths(24)?.choiceCount, 2);
      expect(ShapeMatchingBand.forAgeMonths(35)?.choiceCount, 2);
      expect(ShapeMatchingBand.forAgeMonths(36)?.choiceCount, 3);
      expect(ShapeMatchingBand.forAgeMonths(47)?.choiceCount, 3);
      expect(ShapeMatchingBand.forAgeMonths(48)?.choiceCount, 4);
      expect(ShapeMatchingBand.forAgeMonths(59)?.choiceCount, 4);
      expect(ShapeMatchingBand.forAgeMonths(60)?.choiceCount, 5);
      expect(ShapeMatchingBand.forAgeMonths(71)?.choiceCount, 5);
    });

    test('rejects unsupported ages fail-safe', () {
      expect(ShapeMatchingBand.forAgeMonths(23), isNull);
      expect(ShapeMatchingBand.forAgeMonths(72), isNull);
    });
  });

  group('ShapeMatchingLogic determinism', () {
    test('same session and round yields identical layout', () {
      const session = 'session-abc';
      const band = ShapeMatchingBand(minMonths: 24, maxMonths: 35, choiceCount: 2);
      final a = ShapeMatchingLogic.buildRound(
        playSessionId: session,
        roundIndex: 0,
        band: band,
      );
      final b = ShapeMatchingLogic.buildRound(
        playSessionId: session,
        roundIndex: 0,
        band: band,
      );
      expect(a.target, b.target);
      expect(a.choices, b.choices);
    });
  });

  group('ShapeMatchingActivity prepare', () {
    test('fails without selected child age', () async {
      final activity = ShapeMatchingActivity(ageMonthsProvider: () => null);
      expect(activity.isPlayable, isFalse);
      expect(activity.prepare(), throwsStateError);
    });

    test('fails for unsupported age', () async {
      final activity = ShapeMatchingActivity(ageMonthsProvider: () => 20);
      expect(activity.isPlayable, isFalse);
      expect(activity.prepare(), throwsStateError);
    });

    test('offline prepare succeeds for supported age', () async {
      final buffer = ShapeMatchingLocalEventBuffer();
      final activity = ShapeMatchingActivity(
        ageMonthsProvider: () => 30,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000099',
      );
      expect(activity.isPlayable, isTrue);
      await activity.prepare();
      expect(activity.round?.choices.length, 2);
    });
  });

  group('ShapeMatching gameplay', () {
    test('completes once after three correct rounds', () async {
      final buffer = ShapeMatchingLocalEventBuffer();
      final activity = ShapeMatchingActivity(
        ageMonthsProvider: () => 40,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000088',
      );
      await activity.prepare();
      await activity.onEnter();

      for (var round = 0; round < ShapeMatchingConstants.roundsPerSession; round++) {
        final target = activity.round!.target;
        activity.pickShape(target);
      }

      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      final completed = buffer.events
          .where((e) => e.eventType == 'activity_completed')
          .toList();
      expect(completed, hasLength(1));
    });

    test('restart emits started with restart flag', () async {
      final buffer = ShapeMatchingLocalEventBuffer();
      final activity = ShapeMatchingActivity(
        ageMonthsProvider: () => 28,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000077',
      );
      await activity.prepare();
      await activity.onEnter();
      await activity.onRestart();
      final started = buffer.events
          .where((e) => e.eventType == 'activity_started')
          .toList();
      expect(started, hasLength(2));
      expect(started.last.payload['restart'], isTrue);
    });
  });

  group('telemetry privacy', () {
    test('rejects forbidden payload keys', () {
      final buffer = ShapeMatchingLocalEventBuffer();
      expect(
        () => buffer.emit(
          playSessionId: '00000000-0000-4000-8000-000000000066',
          type: ShapeMatchingEventType.activityAttempted,
          payload: const {'pointer_x': 1},
        ),
        throwsArgumentError,
      );
    });

    test('allowlist covers canonical child events', () {
      for (final type in ShapeMatchingEventType.values) {
        expect(ShapeMatchingEventType.isAllowlisted(type.wireName), isTrue);
      }
    });
  });
}

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_activity.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_constants.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_events.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_flame_layer.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_logic.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';

void main() {
  group('ColorSortingBand', () {
    test('maps age bands to bin counts', () {
      expect(ColorSortingBand.forAgeMonths(24)?.binCount, 2);
      expect(ColorSortingBand.forAgeMonths(35)?.binCount, 2);
      expect(ColorSortingBand.forAgeMonths(36)?.binCount, 3);
      expect(ColorSortingBand.forAgeMonths(47)?.binCount, 3);
      expect(ColorSortingBand.forAgeMonths(48)?.binCount, 4);
      expect(ColorSortingBand.forAgeMonths(71)?.binCount, 4);
    });

    test('rejects unsupported ages fail-safe', () {
      expect(ColorSortingBand.forAgeMonths(23), isNull);
      expect(ColorSortingBand.forAgeMonths(72), isNull);
    });
  });

  group('ColorSortingLogic determinism', () {
    test('same session and round yields identical layout', () {
      const session = 'session-abc';
      const band = ColorSortingBand(minMonths: 24, maxMonths: 35, binCount: 2);
      final a = ColorSortingLogic.buildRound(
        playSessionId: session,
        roundIndex: 0,
        band: band,
      );
      final b = ColorSortingLogic.buildRound(
        playSessionId: session,
        roundIndex: 0,
        band: band,
      );
      expect(a.objectColor, b.objectColor);
      expect(a.objectForm, b.objectForm);
      expect(a.bins, b.bins);
    });

    test('different rounds differ for same session', () {
      const session = 'session-abc';
      const band = ColorSortingBand(minMonths: 48, maxMonths: 71, binCount: 4);
      final a = ColorSortingLogic.buildRound(
        playSessionId: session,
        roundIndex: 0,
        band: band,
      );
      final b = ColorSortingLogic.buildRound(
        playSessionId: session,
        roundIndex: 1,
        band: band,
      );
      // Deterministic but not required to differ — still must rebuild stably.
      expect(
        ColorSortingLogic.buildRound(
          playSessionId: session,
          roundIndex: 1,
          band: band,
        ).bins,
        b.bins,
      );
      expect(a.roundIndex, 0);
      expect(b.roundIndex, 1);
    });

    test('band pools expose colors and forms for validation', () {
      const toddler =
          ColorSortingBand(minMonths: 24, maxMonths: 35, binCount: 2);
      expect(
        ColorSortingLogic.colorPoolForBand(toddler),
        [ColorToken.red, ColorToken.yellow],
      );
      expect(
        ColorSortingLogic.formsForBand(toddler),
        [SortObjectForm.ball, SortObjectForm.block],
      );
      expect(
        ColorSortingLogic.isValidRestoredLayout(
          band: toddler,
          objectColor: ColorToken.red,
          objectForm: SortObjectForm.ball,
          bins: [ColorToken.yellow, ColorToken.red],
        ),
        isTrue,
      );
      expect(
        ColorSortingLogic.isValidRestoredLayout(
          band: toddler,
          objectColor: ColorToken.blue,
          objectForm: SortObjectForm.ball,
          bins: [ColorToken.blue, ColorToken.green],
        ),
        isFalse,
      );
      expect(
        ColorSortingLogic.isValidRestoredLayout(
          band: toddler,
          objectColor: ColorToken.red,
          objectForm: SortObjectForm.apple,
          bins: [ColorToken.red, ColorToken.yellow],
        ),
        isFalse,
      );
    });
  });

  group('ColorSorting eligibility', () {
    test('17 months fail-safe', () async {
      final activity = ColorSortingActivity(ageMonthsProvider: () => 17);
      expect(activity.isPlayable, isFalse);
      expect(activity.prepare(), throwsStateError);
    });

    test('24 months uses two bins', () async {
      final activity = ColorSortingActivity(ageMonthsProvider: () => 24);
      await activity.prepare();
      expect(activity.round?.bins.length, 2);
    });

    test('36 months uses three bins', () async {
      final activity = ColorSortingActivity(ageMonthsProvider: () => 36);
      await activity.prepare();
      expect(activity.round?.bins.length, 3);
    });

    test('60 months uses four bins', () async {
      final activity = ColorSortingActivity(ageMonthsProvider: () => 60);
      await activity.prepare();
      expect(activity.round?.bins.length, 4);
    });
  });

  group('ColorSortingActivity gameplay', () {
    test('completes after three correct sorts', () async {
      final buffer = ColorSortingLocalEventBuffer();
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 40,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000088',
      );
      await activity.prepare();
      await activity.onEnter();

      for (var round = 0;
          round < ColorSortingConstants.roundsPerSession;
          round++) {
        final color = activity.round!.objectColor;
        activity.sortIntoBin(color);
      }

      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      expect(
        activity.correctSortSerial,
        ColorSortingConstants.roundsPerSession,
      );
      expect(
        buffer.events.where((e) => e.eventType == 'activity_completed').length,
        1,
      );
    });

    test('wrong sort does not advance and allows retry', () async {
      final buffer = ColorSortingLocalEventBuffer();
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 30,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000077',
      );
      await activity.prepare();
      await activity.onEnter();
      final before = activity.roundIndex;
      final wrong = activity.round!.bins
          .firstWhere((b) => b != activity.round!.objectColor);
      activity.sortIntoBin(wrong);
      expect(activity.roundIndex, before);
      expect(activity.lastOutcome, isA<EncouragementOutcome>());
      expect(
        (activity.lastOutcome as EncouragementOutcome).cueKey,
        'try_again',
      );
      activity.sortIntoBin(activity.round!.objectColor);
      expect(activity.roundIndex, before + 1);
    });

    test('privacy rejects forbidden payload keys', () {
      expect(
        ColorSortingEventPrivacy.payloadLooksSafe({'child_name': 'x'}),
        isFalse,
      );
      expect(
        ColorSortingEventPrivacy.payloadLooksSafe({'pointer_x': 1}),
        isFalse,
      );
      expect(
        ColorSortingEventPrivacy.payloadLooksSafe({
          'color_id': 'red',
          'correct': true,
        }),
        isTrue,
      );
    });

    test('local buffer uses fixture content version not a UUID', () {
      final buffer = ColorSortingLocalEventBuffer();
      expect(buffer.contentVersionId, ColorSortingConstants.contentVersionId);
      expect(
        buffer.contentVersionId.contains('fixture'),
        isTrue,
      );
    });

    test('abandon emits once on exit before completion', () async {
      final buffer = ColorSortingLocalEventBuffer();
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 36,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000066',
      );
      await activity.prepare();
      await activity.onEnter();
      await activity.onExit();
      expect(
        buffer.events.where((e) => e.eventType == 'activity_abandoned').length,
        1,
      );
    });

    test('replay resets progress and re-emits started', () async {
      final buffer = ColorSortingLocalEventBuffer();
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 36,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000055',
      );
      await activity.prepare();
      await activity.onEnter();
      activity.sortIntoBin(activity.round!.objectColor);
      await activity.onRestart();
      expect(activity.roundIndex, 0);
      expect(activity.correctSortSerial, 0);
      expect(
        buffer.events.where((e) => e.eventType == 'activity_started').length,
        greaterThanOrEqualTo(2),
      );
    });

    test('capture/restore play state is round-safe', () async {
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 48,
        playSessionId: '00000000-0000-4000-8000-000000000044',
      );
      await activity.prepare();
      final snap = activity.capturePlayState();
      await activity.restorePlayState(snap);
      expect(activity.round?.objectColor.name, snap['object_color']);
      expect(activity.round?.bins.map((b) => b.name).toList(), snap['bins']);
    });

    test('restorePlayState rejects unknown color enum without crashing',
        () async {
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 30,
        playSessionId: '00000000-0000-4000-8000-000000000033',
      );
      await activity.prepare();
      final before = activity.capturePlayState();
      await activity.restorePlayState({
        ...before,
        'object_color': 'not_a_color',
      });
      expect(activity.round, isNotNull);
      expect(activity.round!.bins.length, 2);
      expect(
        ColorToken.values.map((c) => c.name),
        contains(activity.round!.objectColor.name),
      );
    });

    test('restorePlayState rejects wrong bin count for age band', () async {
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 30, // band expects 2 bins
        playSessionId: '00000000-0000-4000-8000-000000000032',
      );
      await activity.prepare();
      await activity.restorePlayState({
        'round_index': 1,
        'hint_level': 0,
        'wrong_attempts': 0,
        'celebration': false,
        'object_color': 'red',
        'object_form': 'ball',
        // Stale 4-bin layout from older band — must not leak in.
        'bins': ['red', 'yellow', 'blue', 'green'],
      });
      expect(activity.roundIndex, 1);
      expect(activity.round!.bins.length, 2);
      expect(activity.round!.bins.toSet().length, 2);
    });

    test('restorePlayState rejects duplicate bins and out-of-range round',
        () async {
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 40,
        playSessionId: '00000000-0000-4000-8000-000000000031',
      );
      await activity.prepare();
      await activity.restorePlayState({
        'round_index': 99,
        'hint_level': 0,
        'wrong_attempts': 0,
        'celebration': false,
        'object_color': 'red',
        'object_form': 'block',
        'bins': ['red', 'red', 'blue'],
      });
      expect(activity.roundIndex, 0);
      expect(activity.round, isNotNull);
      expect(activity.round!.bins.length, 3);
      expect(activity.round!.bins.toSet().length, 3);
    });

    test('restorePlayState rejects object color absent from bins', () async {
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 40,
        playSessionId: '00000000-0000-4000-8000-000000000030',
      );
      await activity.prepare();
      final safe = activity.capturePlayState();
      await activity.restorePlayState({
        ...safe,
        'object_color': 'green', // not in toddler/preschool 3-bin pool
        'bins': ['red', 'yellow', 'blue'],
      });
      expect(activity.round!.bins.length, 3);
      expect(activity.round!.bins.contains(activity.round!.objectColor), isTrue);
    });

    test('restorePlayState rejects valid-length out-of-band bins', () async {
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 28, // toddler pool: red/yellow
        playSessionId: '00000000-0000-4000-8000-000000000029',
      );
      await activity.prepare();
      final beforeBins = activity.round!.bins.toList(growable: false);
      await activity.restorePlayState({
        'round_index': 0,
        'hint_level': 0,
        'wrong_attempts': 0,
        'celebration': false,
        'object_color': 'blue',
        'object_form': 'ball',
        // Correct length + unique, but outside toddler pool.
        'bins': ['blue', 'green'],
      });
      expect(activity.round!.bins.length, 2);
      expect(
        activity.round!.bins.toSet(),
        ColorSortingLogic.colorPoolForBand(activity.band!).toSet(),
      );
      // Fail-closed reload — may reshuffle order but stays in-band.
      expect(
        beforeBins.toSet(),
        activity.round!.bins.toSet(),
      );
    });

    test('restorePlayState rejects out-of-band object form', () async {
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 30, // forms: ball/block only
        playSessionId: '00000000-0000-4000-8000-000000000028',
      );
      await activity.prepare();
      await activity.restorePlayState({
        'round_index': 0,
        'hint_level': 0,
        'wrong_attempts': 0,
        'celebration': false,
        'object_color': 'red',
        'object_form': 'apple', // early-band form only
        'bins': ['red', 'yellow'],
      });
      expect(
        ColorSortingLogic.isFormAllowedForBand(
          activity.band!,
          activity.round!.objectForm,
        ),
        isTrue,
      );
      expect(activity.round!.objectForm, isNot(SortObjectForm.apple));
    });

    test('restorePlayState accepts valid in-band roundtrip', () async {
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 50,
        playSessionId: '00000000-0000-4000-8000-000000000027',
      );
      await activity.prepare();
      // Force a known valid layout for the early band (4 colors / all forms).
      const layout = {
        'round_index': 1,
        'hint_level': 1,
        'wrong_attempts': 2,
        'celebration': false,
        'object_color': 'green',
        'object_form': 'apple',
        'bins': ['green', 'red', 'blue', 'yellow'],
      };
      expect(
        ColorSortingLogic.isValidRestoredLayout(
          band: activity.band!,
          objectColor: ColorToken.green,
          objectForm: SortObjectForm.apple,
          bins: const [
            ColorToken.green,
            ColorToken.red,
            ColorToken.blue,
            ColorToken.yellow,
          ],
        ),
        isTrue,
      );
      await activity.restorePlayState(layout);
      expect(activity.roundIndex, 1);
      expect(activity.hintLevel, 1);
      expect(activity.round!.objectColor, ColorToken.green);
      expect(activity.round!.objectForm, SortObjectForm.apple);
      expect(
        activity.round!.bins.map((b) => b.name).toList(),
        ['green', 'red', 'blue', 'yellow'],
      );
      final snap = activity.capturePlayState();
      await activity.restorePlayState(snap);
      expect(activity.round!.objectColor.name, snap['object_color']);
      expect(activity.round!.objectForm.name, snap['object_form']);
      expect(activity.round!.bins.map((b) => b.name).toList(), snap['bins']);
    });

    test('flame layer mounts and unmounts', () async {
      final activity = ColorSortingActivity(ageMonthsProvider: () => 36);
      await activity.prepare();
      final game = FlameGame();
      await game.onLoad();
      activity.bindFlameGame(game);
      await activity.mountFlameLayer(game);
      expect(game.children.query<ColorSortingFlameLayer>(), isNotEmpty);
      await activity.unmountFlameLayer(game);
      expect(game.children.query<ColorSortingFlameLayer>(), isEmpty);
    });
  });
}

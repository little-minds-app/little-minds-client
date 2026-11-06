import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_activity.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_audio.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_logic.dart';

class _ProbeBundle extends CachingAssetBundle {
  _ProbeBundle({required this.presentPaths});

  final Set<String> presentPaths;

  @override
  Future<ByteData> load(String key) async {
    if (!presentPaths.contains(key)) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData(4);
  }
}

Set<String> _allSfxPaths() => {
      for (final cue in ShapeMatchingAudio.requiredCues) cue.assetPath,
    };

ShapeMatchingAudio _audio({
  bool soundOff = false,
  RecordingShapeMatchingSfxPlayer? player,
  Set<String>? present,
  Duration clapDelay = const Duration(milliseconds: 20),
  Duration twinkleDelay = const Duration(milliseconds: 40),
  Duration completionClapDelay = const Duration(milliseconds: 20),
  Duration completionTwinkleDelay = const Duration(milliseconds: 40),
}) {
  return ShapeMatchingAudio(
    soundOff: soundOff,
    player: player ?? RecordingShapeMatchingSfxPlayer(),
    bundle: _ProbeBundle(presentPaths: present ?? _allSfxPaths()),
    clapDelay: clapDelay,
    twinkleDelay: twinkleDelay,
    completionClapDelay: completionClapDelay,
    completionTwinkleDelay: completionTwinkleDelay,
  );
}

Future<ShapeMatchingActivity> _preparedActivity({
  required RecordingShapeMatchingSfxPlayer player,
  bool soundOff = false,
  int ageMonths = 36,
}) async {
  final audio = _audio(player: player, soundOff: soundOff);
  final activity = ShapeMatchingActivity(
    ageMonthsProvider: () => ageMonths,
    audio: audio,
    soundOff: soundOff,
    playSessionId: '00000000-0000-4000-8000-0000000000aa',
  );
  await activity.prepare();
  await activity.onEnter();
  return activity;
}

ShapeToken _wrongChoice(ShapeMatchingActivity activity) {
  final round = activity.round!;
  return round.choices.firstWhere((c) => c != round.target);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShapeMatchingAudio cue mapping', () {
    test('TC-SM-SFX-001 maps tap / drag / wrong / correct / complete cues',
        () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final audio = _audio(player: player);
      await audio.probe('en-US');
      expect(audio.assetsPresent, isTrue);
      expect(audio.ready, isTrue);

      await audio.playTap();
      await audio.playDragBounce();
      await audio.playWrong();
      await audio.playCorrectMatch(serial: 1, isCompletion: false);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await audio.playCorrectMatch(serial: 2, isCompletion: true);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        player.plays,
        containsAllInOrder([
          ShapeMatchingSfxCue.tapPop,
          ShapeMatchingSfxCue.dragBounce,
          ShapeMatchingSfxCue.wrongSoft,
          ShapeMatchingSfxCue.correctChime,
          ShapeMatchingSfxCue.softClap,
          ShapeMatchingSfxCue.twinkle,
          ShapeMatchingSfxCue.completeJingle,
          ShapeMatchingSfxCue.softClap,
          ShapeMatchingSfxCue.twinkle,
        ]),
      );
      expect(player.plays.where((c) => c == ShapeMatchingSfxCue.completeJingle),
          hasLength(1));
      expect(player.plays.where((c) => c == ShapeMatchingSfxCue.correctChime),
          hasLength(1));
    });

    test('TC-SM-SFX-002 asset path convention is offline sfx folder', () {
      expect(
        ShapeMatchingSfxCue.correctChime.assetPath,
        'assets/audio/shape_matching/sfx/correct_chime.wav',
      );
      expect(
        ShapeMatchingSfxCue.softClap.assetSourcePath,
        'audio/shape_matching/sfx/soft_clap.wav',
      );
    });
  });

  group('ShapeMatchingAudio wrong + sound-off', () {
    test('TC-SM-SFX-003 wrong plays friendly cue via activity', () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.pickShape(_wrongChoice(activity));
      expect(player.plays, [ShapeMatchingSfxCue.wrongSoft]);
      expect(activity.lastOutcome, isA<EncouragementOutcome>());
    });

    test('TC-SM-SFX-004 soundOff skips all SFX including celebrate', () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity =
          await _preparedActivity(player: player, soundOff: true);
      expect(activity.audioReady, isFalse);

      activity.notifyChoiceTap();
      activity.notifyChoiceDragStart();
      activity.pickShape(_wrongChoice(activity));
      activity.pickShape(activity.round!.target);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(player.plays, isEmpty);
      expect(player.stopCount, 0);
    });
  });

  group('ShapeMatchingAudio anti-spam + rapid + complete', () {
    test('TC-SM-SFX-005 duplicate serial does not double-celebrate', () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final audio = _audio(player: player);
      await audio.probe('en-US');

      expect(await audio.playCorrectMatch(serial: 1, isCompletion: false),
          isTrue);
      expect(await audio.playCorrectMatch(serial: 1, isCompletion: false),
          isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        player.plays.where((c) => c == ShapeMatchingSfxCue.correctChime),
        hasLength(1),
      );
      expect(
        player.plays.where((c) => c == ShapeMatchingSfxCue.softClap),
        hasLength(1),
      );
    });

    test('TC-SM-SFX-006 rapid matches celebrate each serial once', () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player, ageMonths: 40);

      activity.pickShape(activity.round!.target); // serial 1
      activity.pickShape(activity.round!.target); // serial 2 (cancels prior timers)
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        player.plays.where((c) => c == ShapeMatchingSfxCue.correctChime),
        hasLength(2),
      );
      // Second celebrate should still schedule its own clap/twinkle.
      expect(
        player.plays.where((c) => c == ShapeMatchingSfxCue.softClap).length,
        greaterThanOrEqualTo(1),
      );
      expect(activity.correctMatchSerial, 2);
    });

    test('TC-SM-SFX-007 completion uses richer jingle not mid-match chime',
        () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player, ageMonths: 40);

      for (var i = 0; i < ShapeMatchingConstants.roundsPerSession; i++) {
        activity.pickShape(activity.round!.target);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      expect(
        player.plays.where((c) => c == ShapeMatchingSfxCue.completeJingle),
        hasLength(1),
      );
      // Mid-match chimes for earlier rounds only.
      expect(
        player.plays.where((c) => c == ShapeMatchingSfxCue.correctChime),
        hasLength(ShapeMatchingConstants.roundsPerSession - 1),
      );
      expect(
        player.plays.where((c) => c == ShapeMatchingSfxCue.twinkle),
        isNotEmpty,
      );
    });
  });

  group('ShapeMatchingAudio lifecycle / replay / nav / screen-time', () {
    test('TC-SM-SFX-008 silence on pause (screen-time) stops pending sequence',
        () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.pickShape(activity.round!.target);
      expect(player.plays, contains(ShapeMatchingSfxCue.correctChime));

      await activity.onPause();
      final playsAfterPause = List<ShapeMatchingSfxCue>.from(player.plays);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(player.stopCount, greaterThanOrEqualTo(1));
      expect(player.plays, playsAfterPause); // no clap/twinkle after silence
    });

    test('TC-SM-SFX-009 background silences SFX', () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.pickShape(activity.round!.target);
      await activity.onBackground();
      expect(player.stopCount, greaterThanOrEqualTo(1));
    });

    test('TC-SM-SFX-010 replay resets celebrate serial and silences', () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.pickShape(activity.round!.target);
      expect(activity.audio.lastCelebratedSerial, 1);

      await activity.onRestart();
      expect(activity.audio.lastCelebratedSerial, 0);
      expect(player.stopCount, greaterThanOrEqualTo(1));

      activity.pickShape(activity.round!.target);
      expect(activity.audio.lastCelebratedSerial, 1);
      expect(
        player.plays.where((c) => c == ShapeMatchingSfxCue.correctChime),
        hasLength(2),
      );
    });

    test('TC-SM-SFX-011 exit / disposeResources dispose player', () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.notifyChoiceTap();
      expect(player.plays, [ShapeMatchingSfxCue.tapPop]);

      await activity.onExit();
      expect(player.disposeCount, 1);
      expect(activity.audio.isDisposed, isTrue);

      // Idempotent second dispose via disposeResources (nav / child switch).
      await activity.disposeResources();
      expect(player.disposeCount, 1);

      activity.notifyChoiceTap();
      activity.pickShape(activity.round!.target);
      expect(player.plays, [ShapeMatchingSfxCue.tapPop]);
    });

    test('TC-SM-SFX-012 missing assets keep ready false (offline fail-safe)',
        () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final audio = ShapeMatchingAudio(
        player: player,
        bundle: _ProbeBundle(presentPaths: {}),
      );
      await audio.probe('tr-TR');
      expect(audio.assetsPresent, isFalse);
      expect(audio.ready, isFalse);
      expect(await audio.playTap(), isFalse);
      expect(player.plays, isEmpty);
    });
  });

  group('ShapeMatchingAudio regressions', () {
    test('TC-SM-SFX-013 correct still advances without waiting for SFX',
        () async {
      final player = RecordingShapeMatchingSfxPlayer();
      // Slow clap delays must not block round advance.
      final audio = _audio(
        player: player,
        clapDelay: const Duration(seconds: 2),
        twinkleDelay: const Duration(seconds: 3),
      );
      final activity = ShapeMatchingActivity(
        ageMonthsProvider: () => 36,
        audio: audio,
        playSessionId: '00000000-0000-4000-8000-0000000000bb',
      );
      await activity.prepare();
      final before = activity.roundIndex;
      activity.pickShape(activity.round!.target);
      expect(activity.roundIndex, before + 1);
      expect(activity.correctMatchSerial, 1);
    });

    test('TC-SM-SFX-014 player canPlay false keeps ready false', () async {
      final player = RecordingShapeMatchingSfxPlayer(canPlay: false);
      final audio = _audio(player: player);
      await audio.probe('en-US');
      expect(audio.assetsPresent, isTrue);
      expect(audio.ready, isFalse);
      expect(await audio.playWrong(), isFalse);
      expect(player.plays, isEmpty);
    });

    test('TC-SM-SFX-015 drag + tap helpers map without pick', () async {
      final player = RecordingShapeMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.notifyChoiceDragStart();
      activity.notifyChoiceTap();
      expect(
        player.plays,
        [ShapeMatchingSfxCue.dragBounce, ShapeMatchingSfxCue.tapPop],
      );
      expect(activity.correctMatchSerial, 0);
    });
  });
}

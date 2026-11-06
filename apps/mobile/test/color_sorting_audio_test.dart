import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_activity.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_audio.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_constants.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_logic.dart';

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
      for (final cue in ColorSortingAudio.requiredCues) cue.assetPath,
    };

Set<String> _allAudioPaths() => {
      ..._allSfxPaths(),
      ColorSortingBgmTrack.assetPath,
    };

ColorSortingAudio _audio({
  bool soundOff = false,
  RecordingColorSortingSfxPlayer? player,
  RecordingColorSortingBgmPlayer? bgmPlayer,
  Set<String>? present,
  Duration clapDelay = const Duration(milliseconds: 20),
  Duration twinkleDelay = const Duration(milliseconds: 40),
  Duration completionClapDelay = const Duration(milliseconds: 20),
  Duration completionTwinkleDelay = const Duration(milliseconds: 40),
  Duration matchDuckRestore = const Duration(milliseconds: 50),
  Duration completionDuckRestore = const Duration(milliseconds: 80),
  double bgmGain = 0.20,
  double sfxGain = 0.85,
  double bgmDuckFactor = 0.25,
}) {
  return ColorSortingAudio(
    soundOff: soundOff,
    player: player ?? RecordingColorSortingSfxPlayer(),
    bgmPlayer: bgmPlayer ?? RecordingColorSortingBgmPlayer(),
    bundle: _ProbeBundle(presentPaths: present ?? _allAudioPaths()),
    clapDelay: clapDelay,
    twinkleDelay: twinkleDelay,
    completionClapDelay: completionClapDelay,
    completionTwinkleDelay: completionTwinkleDelay,
    matchDuckRestore: matchDuckRestore,
    completionDuckRestore: completionDuckRestore,
    bgmGain: bgmGain,
    sfxGain: sfxGain,
    bgmDuckFactor: bgmDuckFactor,
  );
}

Future<ColorSortingActivity> _preparedActivity({
  required RecordingColorSortingSfxPlayer player,
  RecordingColorSortingBgmPlayer? bgmPlayer,
  bool soundOff = false,
  int ageMonths = 36,
}) async {
  final audio = _audio(
    player: player,
    bgmPlayer: bgmPlayer,
    soundOff: soundOff,
  );
  final activity = ColorSortingActivity(
    ageMonthsProvider: () => ageMonths,
    audio: audio,
    soundOff: soundOff,
    playSessionId: '00000000-0000-4000-8000-0000000000aa',
  );
  await activity.prepare();
  await activity.onEnter();
  return activity;
}

ColorToken _wrongBin(ColorSortingActivity activity) {
  final round = activity.round!;
  return round.bins.firstWhere((c) => c != round.objectColor);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColorSortingAudio cue mapping', () {
    test('TC-CS-SFX-001 maps tap / drag / wrong / correct / complete cues',
        () async {
      final player = RecordingColorSortingSfxPlayer();
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
          ColorSortingSfxCue.tapPop,
          ColorSortingSfxCue.dragBounce,
          ColorSortingSfxCue.wrongSoft,
          ColorSortingSfxCue.correctChime,
          ColorSortingSfxCue.softClap,
          ColorSortingSfxCue.twinkle,
          ColorSortingSfxCue.completeJingle,
          ColorSortingSfxCue.softClap,
          ColorSortingSfxCue.twinkle,
        ]),
      );
      expect(player.plays.where((c) => c == ColorSortingSfxCue.completeJingle),
          hasLength(1));
      expect(player.plays.where((c) => c == ColorSortingSfxCue.correctChime),
          hasLength(1));
    });

    test('TC-CS-SFX-002 asset path convention is offline sfx folder', () {
      expect(
        ColorSortingSfxCue.correctChime.assetPath,
        'assets/audio/color_sorting/sfx/correct_chime.wav',
      );
      expect(
        ColorSortingSfxCue.softClap.assetSourcePath,
        'audio/color_sorting/sfx/soft_clap.wav',
      );
    });
  });

  group('ColorSortingAudio wrong + sound-off', () {
    test('TC-CS-SFX-003 wrong plays friendly cue via activity', () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.sortIntoBin(_wrongBin(activity));
      expect(player.plays, [ColorSortingSfxCue.wrongSoft]);
      expect(activity.lastOutcome, isA<EncouragementOutcome>());
    });

    test('TC-CS-SFX-004 soundOff skips all SFX including celebrate', () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity =
          await _preparedActivity(player: player, soundOff: true);
      expect(activity.audioReady, isFalse);

      activity.notifyObjectTap();
      activity.notifyObjectDragStart();
      activity.sortIntoBin(_wrongBin(activity));
      activity.sortIntoBin(activity.round!.objectColor);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(player.plays, isEmpty);
      expect(player.stopCount, 0);
    });
  });

  group('ColorSortingAudio anti-spam + rapid + complete', () {
    test('TC-CS-SFX-005 duplicate serial does not double-celebrate', () async {
      final player = RecordingColorSortingSfxPlayer();
      final audio = _audio(player: player);
      await audio.probe('en-US');

      expect(await audio.playCorrectMatch(serial: 1, isCompletion: false),
          isTrue);
      expect(await audio.playCorrectMatch(serial: 1, isCompletion: false),
          isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.correctChime),
        hasLength(1),
      );
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.softClap),
        hasLength(1),
      );
    });

    test('TC-CS-SFX-006 rapid matches celebrate each serial once', () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity = await _preparedActivity(player: player, ageMonths: 40);

      activity.sortIntoBin(activity.round!.objectColor); // serial 1
      activity.sortIntoBin(activity.round!.objectColor); // serial 2 (cancels prior timers)
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.correctChime),
        hasLength(2),
      );
      // Second celebrate should still schedule its own clap/twinkle.
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.softClap).length,
        greaterThanOrEqualTo(1),
      );
      expect(activity.correctSortSerial, 2);
    });

    test('TC-CS-SFX-007 completion uses richer jingle not mid-match chime',
        () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity = await _preparedActivity(player: player, ageMonths: 40);

      for (var i = 0; i < ColorSortingConstants.roundsPerSession; i++) {
        activity.sortIntoBin(activity.round!.objectColor);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.completeJingle),
        hasLength(1),
      );
      // Mid-match chimes for earlier rounds only.
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.correctChime),
        hasLength(ColorSortingConstants.roundsPerSession - 1),
      );
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.twinkle),
        isNotEmpty,
      );
    });
  });

  group('ColorSortingAudio lifecycle / replay / nav / screen-time', () {
    test('TC-CS-SFX-008 silence on pause (screen-time) stops pending sequence',
        () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.sortIntoBin(activity.round!.objectColor);
      expect(player.plays, contains(ColorSortingSfxCue.correctChime));

      await activity.onPause();
      final playsAfterPause = List<ColorSortingSfxCue>.from(player.plays);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(player.stopCount, greaterThanOrEqualTo(1));
      expect(player.plays, playsAfterPause); // no clap/twinkle after silence
    });

    test('TC-CS-SFX-009 background silences SFX', () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.sortIntoBin(activity.round!.objectColor);
      await activity.onBackground();
      expect(player.stopCount, greaterThanOrEqualTo(1));
    });

    test('TC-CS-SFX-010 replay resets celebrate serial and silences', () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.sortIntoBin(activity.round!.objectColor);
      expect(activity.audio.lastCelebratedSerial, 1);

      await activity.onRestart();
      expect(activity.audio.lastCelebratedSerial, 0);
      expect(player.stopCount, greaterThanOrEqualTo(1));

      activity.sortIntoBin(activity.round!.objectColor);
      expect(activity.audio.lastCelebratedSerial, 1);
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.correctChime),
        hasLength(2),
      );
    });

    test('TC-CS-SFX-011 exit / disposeResources dispose player', () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.notifyObjectTap();
      expect(player.plays, [ColorSortingSfxCue.tapPop]);

      await activity.onExit();
      expect(player.disposeCount, 1);
      expect(activity.audio.isDisposed, isTrue);

      // Idempotent second dispose via disposeResources (nav / child switch).
      await activity.disposeResources();
      expect(player.disposeCount, 1);

      activity.notifyObjectTap();
      activity.sortIntoBin(activity.round!.objectColor);
      expect(player.plays, [ColorSortingSfxCue.tapPop]);
    });

    test('TC-CS-SFX-012 missing assets keep ready false (offline fail-safe)',
        () async {
      final player = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final audio = ColorSortingAudio(
        player: player,
        bgmPlayer: bgm,
        bundle: _ProbeBundle(presentPaths: {}),
      );
      await audio.probe('tr-TR');
      expect(audio.assetsPresent, isFalse);
      expect(audio.ready, isFalse);
      expect(audio.bgmAssetPresent, isFalse);
      expect(audio.bgmReady, isFalse);
      expect(await audio.playTap(), isFalse);
      expect(await audio.ensureBgmPlaying(), isFalse);
      expect(player.plays, isEmpty);
      expect(bgm.startLoopCount, 0);
    });
  });

  group('ColorSortingAudio regressions', () {
    test('TC-CS-SFX-013 correct still advances without waiting for SFX',
        () async {
      final player = RecordingColorSortingSfxPlayer();
      // Slow clap delays must not block round advance.
      final audio = _audio(
        player: player,
        clapDelay: const Duration(seconds: 2),
        twinkleDelay: const Duration(seconds: 3),
      );
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 36,
        audio: audio,
        playSessionId: '00000000-0000-4000-8000-0000000000bb',
      );
      await activity.prepare();
      final before = activity.roundIndex;
      activity.sortIntoBin(activity.round!.objectColor);
      expect(activity.roundIndex, before + 1);
      expect(activity.correctSortSerial, 1);
    });

    test('TC-CS-SFX-014 player canPlay false keeps ready false', () async {
      final player = RecordingColorSortingSfxPlayer(canPlay: false);
      final audio = _audio(player: player);
      await audio.probe('en-US');
      expect(audio.assetsPresent, isTrue);
      expect(audio.ready, isFalse);
      expect(await audio.playWrong(), isFalse);
      expect(player.plays, isEmpty);
    });

    test('TC-CS-SFX-015 drag + tap helpers map without pick', () async {
      final player = RecordingColorSortingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.notifyObjectDragStart();
      activity.notifyObjectTap();
      expect(
        player.plays,
        [ColorSortingSfxCue.dragBounce, ColorSortingSfxCue.tapPop],
      );
      expect(activity.correctSortSerial, 0);
    });
  });

  group('ColorSortingAudio celebrate in-flight serial race', () {
    Future<void> waitForHeld(RecordingColorSortingSfxPlayer player, int n) async {
      for (var i = 0; i < 40; i++) {
        if (player.pendingPlayCount >= n) return;
        await Future<void>.delayed(Duration.zero);
      }
      fail('expected $n held play(s), got ${player.pendingPlayCount}');
    }

    test(
        'TC-CS-SFX-016 newer serial invalidates older in-flight lead '
        'before clap/twinkle', () async {
      final player = RecordingColorSortingSfxPlayer(holdPlays: true);
      final audio = _audio(
        player: player,
        clapDelay: const Duration(milliseconds: 10),
        twinkleDelay: const Duration(milliseconds: 20),
      );
      await audio.probe('en-US');

      final older = audio.playCorrectMatch(serial: 1, isCompletion: false);
      await waitForHeld(player, 1);
      expect(player.nextHeldCue, ColorSortingSfxCue.correctChime);

      final newer = audio.playCorrectMatch(serial: 2, isCompletion: false);
      await waitForHeld(player, 2);

      // Older lead finishes after newer has claimed the celebrate serial.
      expect(player.releaseNextPlay(), isTrue);
      expect(await older, isFalse);

      // Newer lead may schedule delayed cues — release without holding them.
      player.holdPlays = false;
      expect(player.releaseNextPlay(), isTrue);
      expect(await newer, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.correctChime),
        hasLength(2),
      );
      // Only the newer celebrate may schedule clap + twinkle.
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.softClap),
        hasLength(1),
      );
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.twinkle),
        hasLength(1),
      );
      expect(audio.lastCelebratedSerial, 2);
    });

    test(
        'TC-CS-SFX-017 silence during in-flight lead blocks delayed sequence',
        () async {
      final player = RecordingColorSortingSfxPlayer(holdPlays: true);
      final audio = _audio(
        player: player,
        clapDelay: const Duration(milliseconds: 10),
        twinkleDelay: const Duration(milliseconds: 20),
      );
      await audio.probe('en-US');

      final celebrate = audio.playCorrectMatch(serial: 1, isCompletion: false);
      await waitForHeld(player, 1);

      await audio.silence();
      final epochAfterSilence = audio.lifecycleEpoch;
      player.holdPlays = false;
      expect(player.releaseNextPlay(), isTrue);
      expect(await celebrate, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(player.plays, [ColorSortingSfxCue.correctChime]);
      expect(player.stopCount, greaterThanOrEqualTo(1));
      expect(audio.lifecycleEpoch, epochAfterSilence);
    });

    test(
        'TC-CS-SFX-018 dispose during in-flight lead blocks delayed sequence',
        () async {
      final player = RecordingColorSortingSfxPlayer(holdPlays: true);
      final audio = _audio(
        player: player,
        clapDelay: const Duration(milliseconds: 10),
        twinkleDelay: const Duration(milliseconds: 20),
      );
      await audio.probe('en-US');

      final celebrate = audio.playCorrectMatch(serial: 1, isCompletion: false);
      await waitForHeld(player, 1);

      await audio.dispose();
      // dispose releases held plays with failure — celebrate must not hang.
      expect(await celebrate, isFalse);
      expect(audio.isDisposed, isTrue);
      expect(player.disposeCount, 1);
      expect(player.plays, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(player.plays, isEmpty);
    });

    test(
        'TC-CS-SFX-019 resetForReplay during in-flight lead blocks delayed '
        'cues and clears serial', () async {
      final player = RecordingColorSortingSfxPlayer(holdPlays: true);
      final audio = _audio(
        player: player,
        clapDelay: const Duration(milliseconds: 10),
        twinkleDelay: const Duration(milliseconds: 20),
      );
      await audio.probe('en-US');

      final celebrate = audio.playCorrectMatch(serial: 1, isCompletion: false);
      await waitForHeld(player, 1);

      await audio.resetForReplay();
      expect(audio.lastCelebratedSerial, 0);
      player.holdPlays = false;
      expect(player.releaseNextPlay(), isTrue);
      expect(await celebrate, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(player.plays, [ColorSortingSfxCue.correctChime]);
      expect(
        player.plays.where((c) => c == ColorSortingSfxCue.softClap),
        isEmpty,
      );
    });
  });

  group('ColorSortingAudio Colorful Orchard BGM', () {
    test('TC-CS-BGM-001 asset path is offline bgm mp3 loop', () {
      expect(
        ColorSortingBgmTrack.assetPath,
        'assets/audio/color_sorting/bgm/colorful_orchard_loop.mp3',
      );
      expect(
        ColorSortingBgmTrack.assetSourcePath,
        'audio/color_sorting/bgm/colorful_orchard_loop.mp3',
      );
    });

    test('TC-CS-BGM-002 starts one loop on enter at ~20% gain', () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(player: sfx, bgmPlayer: bgm);

      expect(activity.bgmReady, isTrue);
      expect(bgm.startLoopCount, 1);
      expect(bgm.isPlaying, isTrue);
      expect(bgm.volume, closeTo(0.20, 0.001));
      expect(activity.audio.bgmIsPlaying, isTrue);
    });

    test('TC-CS-BGM-003 does not restart between rounds', () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(player: sfx, bgmPlayer: bgm);
      expect(bgm.startLoopCount, 1);

      activity.sortIntoBin(activity.round!.objectColor);
      activity.sortIntoBin(activity.round!.objectColor);
      await activity.audio.ensureBgmPlaying();

      expect(bgm.startLoopCount, 1);
      expect(bgm.isPlaying, isTrue);
    });

    test('TC-CS-BGM-004 replay keeps same instance (no duplicate start)',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(player: sfx, bgmPlayer: bgm);
      expect(bgm.startLoopCount, 1);

      await activity.onRestart();
      // resetForReplay → ensureBgmPlaying while already playing → no new start.
      expect(bgm.startLoopCount, 1);
      expect(bgm.stopCount, 0);
      expect(bgm.isPlaying, isTrue);
      expect(bgm.pauseCount, 0);
    });

    test('TC-CS-BGM-005 pause pauses BGM; resume restores without new start',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(player: sfx, bgmPlayer: bgm);

      await activity.onPause();
      expect(bgm.pauseCount, greaterThanOrEqualTo(1));
      expect(bgm.isPaused, isTrue);
      expect(bgm.isPlaying, isFalse);

      await activity.onResume();
      expect(bgm.resumeCount, greaterThanOrEqualTo(1));
      expect(bgm.isPlaying, isTrue);
      expect(bgm.startLoopCount, 1);
    });

    test('TC-CS-BGM-006 background pauses; resume path restores BGM', () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(player: sfx, bgmPlayer: bgm);

      await activity.onBackground();
      expect(bgm.isPaused, isTrue);
      expect(activity.interactionsEnabled, isFalse);

      // Session controller calls onForeground then onResume when returning from
      // background while previously running. Foreground alone stays quiet while
      // gameplay is still blocked (see TC-CS-BGM-020).
      await activity.onForeground();
      expect(bgm.isPaused, isTrue);
      expect(bgm.resumeCount, 0);

      await activity.onResume();
      expect(activity.interactionsEnabled, isTrue);
      expect(bgm.isPlaying, isTrue);
      expect(bgm.startLoopCount, 1);
    });

    test('TC-CS-BGM-007 exit disposes BGM (Kids Mode leave)', () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(player: sfx, bgmPlayer: bgm);

      await activity.onExit();
      expect(bgm.stopCount, greaterThanOrEqualTo(1));
      expect(bgm.disposeCount, 1);
      expect(sfx.disposeCount, 1);
      expect(activity.audio.isDisposed, isTrue);
      expect(await activity.audio.ensureBgmPlaying(), isFalse);
    });

    test('TC-CS-BGM-008 soundOff skips BGM and SFX', () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(
        player: sfx,
        bgmPlayer: bgm,
        soundOff: true,
      );

      expect(activity.bgmReady, isFalse);
      expect(bgm.startLoopCount, 0);
      activity.sortIntoBin(activity.round!.objectColor);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sfx.plays, isEmpty);
      expect(bgm.volumeHistory, isEmpty);
    });

    test('TC-CS-BGM-009 independent gains — SFX comfortable, BGM ~20%',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        sfxGain: 0.85,
        bgmGain: 0.20,
      );
      await audio.probe('en-US');
      await audio.ensureBgmPlaying();
      await audio.playTap();

      expect(bgm.volume, closeTo(0.20, 0.001));
      expect(sfx.volumes.single, closeTo(0.85, 0.001));
    });

    test('TC-CS-BGM-010 ducks on correct then restores after celebrate',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        matchDuckRestore: const Duration(milliseconds: 40),
      );
      await audio.probe('en-US');
      await audio.ensureBgmPlaying();
      expect(bgm.volume, closeTo(0.20, 0.001));

      await audio.playCorrectMatch(serial: 1, isCompletion: false);
      expect(bgm.volume, closeTo(0.05, 0.001)); // 0.20 * 0.25

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bgm.volume, closeTo(0.20, 0.001));
      expect(audio.lastDuckSerial, 1);
    });

    test('TC-CS-BGM-011 longer duck on completion than mid-match', () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        matchDuckRestore: const Duration(milliseconds: 30),
        completionDuckRestore: const Duration(milliseconds: 90),
      );
      await audio.probe('en-US');
      await audio.ensureBgmPlaying();

      await audio.playCorrectMatch(serial: 1, isCompletion: true);
      expect(bgm.volume, closeTo(0.05, 0.001));

      await Future<void>.delayed(const Duration(milliseconds: 45));
      // Still ducked — completion window longer than mid-match 30ms.
      expect(bgm.volume, closeTo(0.05, 0.001));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bgm.volume, closeTo(0.20, 0.001));
    });

    test('TC-CS-BGM-012 rapid matches race-safe — only latest duck restores',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        matchDuckRestore: const Duration(milliseconds: 40),
      );
      await audio.probe('en-US');
      await audio.ensureBgmPlaying();

      await audio.playCorrectMatch(serial: 1, isCompletion: false);
      await audio.playCorrectMatch(serial: 2, isCompletion: false);
      expect(audio.lastDuckSerial, 2);
      expect(bgm.volume, closeTo(0.05, 0.001));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bgm.volume, closeTo(0.20, 0.001));
      // One restore to base after the latest duck (not stacked bounce).
      final restores = bgm.volumeHistory.where((v) => (v - 0.20).abs() < 0.001);
      expect(restores.length, greaterThanOrEqualTo(2)); // start + restore
    });

    test('TC-CS-BGM-013 silence cancels pending duck restore', () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        matchDuckRestore: const Duration(milliseconds: 80),
      );
      await audio.probe('en-US');
      await audio.ensureBgmPlaying();
      await audio.playCorrectMatch(serial: 1, isCompletion: false);
      expect(bgm.volume, closeTo(0.05, 0.001));

      await audio.silence();
      final volumesAfterSilence = List<double>.from(bgm.volumeHistory);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(bgm.volumeHistory, volumesAfterSilence);
      expect(bgm.isPaused, isTrue);
    });

    test('TC-CS-BGM-014 missing BGM asset fails soft without blocking SFX',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        present: _allSfxPaths(), // SFX only
      );
      await audio.probe('en-US');
      expect(audio.ready, isTrue);
      expect(audio.bgmReady, isFalse);
      expect(await audio.ensureBgmPlaying(), isFalse);
      expect(await audio.playTap(), isTrue);
      expect(sfx.plays, [ColorSortingSfxCue.tapPop]);
      expect(bgm.startLoopCount, 0);
    });
  });

  group('ColorSortingAudio BGM delayed-future races', () {
    Future<void> waitForHeld(RecordingColorSortingBgmPlayer bgm, int n) async {
      for (var i = 0; i < 40; i++) {
        if (bgm.pendingOperationCount >= n) return;
        await Future<void>.delayed(Duration.zero);
      }
      fail('expected $n held BGM op(s), got ${bgm.pendingOperationCount}');
    }

    test(
        'TC-CS-BGM-015 pause during startup leaves BGM paused (no late start)',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer(holdOperations: true);
      final audio = _audio(player: sfx, bgmPlayer: bgm);
      await audio.probe('en-US');

      final startup = audio.ensureBgmPlaying();
      await waitForHeld(bgm, 1);

      await audio.silence(); // pause / screen-time
      expect(bgm.releaseNextOperation(), isTrue);
      expect(await startup, isFalse);
      expect(bgm.isPlaying, isFalse);
      expect(bgm.isPaused, isTrue);
      expect(bgm.startLoopCount, 1);
    });

    test(
        'TC-CS-BGM-016 dispose during startup does not leave music on',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer(holdOperations: true);
      final audio = _audio(player: sfx, bgmPlayer: bgm);
      await audio.probe('en-US');

      final startup = audio.ensureBgmPlaying();
      await waitForHeld(bgm, 1);

      await audio.dispose(); // releases held startLoop
      expect(await startup, isFalse);
      expect(bgm.isPlaying, isFalse);
      expect(bgm.disposeCount, 1);
      expect(audio.isDisposed, isTrue);
    });

    test(
        'TC-CS-BGM-017 screen-time pause during startup via activity',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer(holdOperations: true);
      final audio = _audio(player: sfx, bgmPlayer: bgm);
      final activity = ColorSortingActivity(
        ageMonthsProvider: () => 36,
        audio: audio,
        playSessionId: '00000000-0000-4000-8000-0000000000cc',
      );
      await activity.prepare();

      final enter = activity.onEnter();
      await waitForHeld(bgm, 1);

      await activity.onPause(); // interactions off + silence
      expect(activity.interactionsEnabled, isFalse);
      expect(bgm.releaseNextOperation(), isTrue);
      await enter;

      expect(bgm.isPlaying, isFalse);
      expect(bgm.isPaused, isTrue);
    });

    test(
        'TC-CS-BGM-018 newer celebrate during in-flight duck blocks stale restore',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer(holdOperations: true);
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        matchDuckRestore: const Duration(milliseconds: 30),
      );
      await audio.probe('en-US');
      bgm.holdOperations = false;
      await audio.ensureBgmPlaying();
      expect(bgm.volume, closeTo(0.20, 0.001));

      bgm.holdOperations = true;
      // Duck is fire-and-forget inside celebrate; hold gates setVolume only.
      // ignore: discarded_futures
      audio.playCorrectMatch(serial: 1, isCompletion: false);
      await waitForHeld(bgm, 1); // older setVolume(duck)

      // ignore: discarded_futures
      audio.playCorrectMatch(serial: 2, isCompletion: false);
      await waitForHeld(bgm, 2); // newer setVolume(duck)

      // Stale duck finishes after newer claimed serial — must not schedule restore.
      expect(bgm.releaseNextOperation(), isTrue);
      await Future<void>.delayed(Duration.zero);

      bgm.holdOperations = false;
      expect(bgm.releaseNextOperation(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(bgm.volume, closeTo(0.05, 0.001));
      expect(audio.lastDuckSerial, 2);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bgm.volume, closeTo(0.20, 0.001));
      // start + one restore (stale duck must not add a second restore).
      final restores =
          bgm.volumeHistory.where((v) => (v - 0.20).abs() < 0.001).length;
      expect(restores, 2); // initial start + single restore
    });

    test(
        'TC-CS-BGM-019 pause during in-flight duck does not restore after silence',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer(holdOperations: true);
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        matchDuckRestore: const Duration(milliseconds: 30),
      );
      await audio.probe('en-US');
      bgm.holdOperations = false;
      await audio.ensureBgmPlaying();

      bgm.holdOperations = true;
      // ignore: discarded_futures
      audio.playCorrectMatch(serial: 1, isCompletion: false);
      await waitForHeld(bgm, 1);

      await audio.silence();
      final restoresBeforeRelease = bgm.volumeHistory
          .where((v) => (v - 0.20).abs() < 0.001)
          .length;
      expect(bgm.releaseNextOperation(), isTrue);
      await Future<void>.delayed(Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Late duck may apply ducked gain on the paused bus, but must not
      // schedule a restore back to idle gain after silence won the epoch.
      final restoresAfter = bgm.volumeHistory
          .where((v) => (v - 0.20).abs() < 0.001)
          .length;
      expect(restoresAfter, restoresBeforeRelease);
      expect(bgm.isPaused, isTrue);
      expect(bgm.isPlaying, isFalse);
    });

    test(
        'TC-CS-BGM-020 foreground while gameplay blocked does not resume BGM',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(player: sfx, bgmPlayer: bgm);
      expect(bgm.isPlaying, isTrue);

      await activity.onPause();
      expect(activity.interactionsEnabled, isFalse);
      expect(bgm.isPaused, isTrue);

      await activity.onForeground();
      expect(bgm.isPlaying, isFalse);
      expect(bgm.isPaused, isTrue);
      expect(bgm.resumeCount, 0);
      expect(bgm.startLoopCount, 1);
    });

    test(
        'TC-CS-BGM-021 replay ensureBgmPlaying does not duplicate startLoop',
        () async {
      final sfx = RecordingColorSortingSfxPlayer();
      final bgm = RecordingColorSortingBgmPlayer();
      final activity = await _preparedActivity(player: sfx, bgmPlayer: bgm);
      expect(bgm.startLoopCount, 1);

      await activity.onRestart();
      expect(bgm.startLoopCount, 1);
      expect(bgm.isPlaying, isTrue);
      expect(bgm.stopCount, 0);

      await activity.audio.ensureBgmPlaying();
      await activity.audio.ensureBgmPlaying();
      expect(bgm.startLoopCount, 1);
    });
  });
}

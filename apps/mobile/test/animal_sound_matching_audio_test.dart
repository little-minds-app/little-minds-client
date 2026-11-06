import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_activity.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_audio.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_constants.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_logic.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';

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
      for (final cue in AnimalSoundMatchingAudio.requiredCues) cue.assetPath,
    };

Set<String> _allAnimalPaths() => {
      for (final k in AnimalKind.values) AnimalSoundMatchingAnimalTrack.assetPath(k),
    };

Set<String> _allAudioPaths() => {
      ..._allSfxPaths(),
      AnimalSoundMatchingBgmTrack.assetPath,
      ..._allAnimalPaths(),
    };

AnimalSoundMatchingAudio _audio({
  bool soundOff = false,
  RecordingAnimalSoundMatchingSfxPlayer? player,
  RecordingAnimalSoundMatchingBgmPlayer? bgmPlayer,
  RecordingAnimalSoundMatchingAnimalPlayer? animalPlayer,
  Set<String>? present,
  Duration clapDelay = const Duration(milliseconds: 20),
  Duration twinkleDelay = const Duration(milliseconds: 40),
  Duration completionClapDelay = const Duration(milliseconds: 20),
  Duration completionTwinkleDelay = const Duration(milliseconds: 40),
  Duration matchDuckRestore = const Duration(milliseconds: 50),
  Duration completionDuckRestore = const Duration(milliseconds: 80),
  Duration promptDuckRestore = const Duration(milliseconds: 50),
  double bgmGain = 0.20,
  double sfxGain = 0.85,
  double bgmDuckFactor = 0.25,
}) {
  return AnimalSoundMatchingAudio(
    soundOff: soundOff,
    player: player ?? RecordingAnimalSoundMatchingSfxPlayer(),
    bgmPlayer: bgmPlayer ?? RecordingAnimalSoundMatchingBgmPlayer(),
    animalPlayer: animalPlayer ?? RecordingAnimalSoundMatchingAnimalPlayer(),
    bundle: _ProbeBundle(presentPaths: present ?? _allAudioPaths()),
    clapDelay: clapDelay,
    twinkleDelay: twinkleDelay,
    completionClapDelay: completionClapDelay,
    completionTwinkleDelay: completionTwinkleDelay,
    matchDuckRestore: matchDuckRestore,
    completionDuckRestore: completionDuckRestore,
    promptDuckRestore: promptDuckRestore,
    bgmGain: bgmGain,
    sfxGain: sfxGain,
    bgmDuckFactor: bgmDuckFactor,
  );
}

Future<AnimalSoundMatchingActivity> _preparedActivity({
  required RecordingAnimalSoundMatchingSfxPlayer player,
  RecordingAnimalSoundMatchingBgmPlayer? bgmPlayer,
  RecordingAnimalSoundMatchingAnimalPlayer? animalPlayer,
  bool soundOff = false,
  int ageMonths = 36,
  Set<String>? present,
}) async {
  final audio = _audio(
    player: player,
    bgmPlayer: bgmPlayer,
    animalPlayer: animalPlayer,
    soundOff: soundOff,
    present: present,
  );
  final activity = AnimalSoundMatchingActivity(
    ageMonthsProvider: () => ageMonths,
    audio: audio,
    soundOff: soundOff,
    playSessionId: '00000000-0000-4000-8000-0000000000aa',
  );
  await activity.prepare();
  await activity.onEnter();
  return activity;
}

AnimalKind _wrongChoice(AnimalSoundMatchingActivity activity) {
  final round = activity.round!;
  return round.choices.firstWhere((c) => c != round.targetAnimal);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnimalSoundMatchingAudio cue mapping', () {
    test('TC-ASM-SFX-001 maps tap / wrong / correct / complete cues', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final audio = _audio(player: player);
      await audio.probe('en-US');
      expect(audio.assetsPresent, isTrue);
      expect(audio.ready, isTrue);

      await audio.playTap();
      await audio.playWrong();
      await audio.playCorrectMatch(serial: 1, isCompletion: false);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await audio.playCorrectMatch(serial: 2, isCompletion: true);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        player.plays,
        containsAllInOrder([
          AnimalSoundMatchingSfxCue.tapPop,
          AnimalSoundMatchingSfxCue.wrongSoft,
          AnimalSoundMatchingSfxCue.correctChime,
          AnimalSoundMatchingSfxCue.softClap,
          AnimalSoundMatchingSfxCue.twinkle,
          AnimalSoundMatchingSfxCue.completeJingle,
          AnimalSoundMatchingSfxCue.softClap,
          AnimalSoundMatchingSfxCue.twinkle,
        ]),
      );
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.completeJingle),
        hasLength(1),
      );
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.correctChime),
        hasLength(1),
      );
    });
  });

  group('AnimalSoundMatchingAudio animal prompt + replay', () {
    test('TC-ASM-SFX-002 replay stops prior prompt (no stacked overlap signal)',
        () async {
      final sfx = RecordingAnimalSoundMatchingSfxPlayer();
      final animal = RecordingAnimalSoundMatchingAnimalPlayer();
      final audio = _audio(player: sfx, animalPlayer: animal);
      await audio.probe('en-US');
      await audio.ensureBgmPlaying();

      await audio.playAnimalPrompt(AnimalKind.cat, forceRestart: true);
      animal.isPlaying = true;
      await audio.playAnimalPrompt(AnimalKind.dog, forceRestart: true);

      expect(animal.stopCount, greaterThanOrEqualTo(1));
      expect(animal.plays.last, AnimalKind.dog);
    });

    test('TC-ASM-SFX-003 soundOff keeps animalPromptReady false', () async {
      final audio = _audio(soundOff: true);
      await audio.probe('en-US');
      expect(audio.animalPromptReady, isFalse);
      expect(await audio.playAnimalPrompt(AnimalKind.cat), isFalse);
    });

    test(
        'TC-ASM-SFX-004 missing animal assets keep animalPromptReady false',
        () async {
      final animal = RecordingAnimalSoundMatchingAnimalPlayer();
      final audio = _audio(
        animalPlayer: animal,
        present: {
          ..._allSfxPaths(),
          AnimalSoundMatchingBgmTrack.assetPath,
        },
      );
      await audio.probe('en-US');
      expect(audio.assetsPresent, isTrue);
      expect(audio.animalAssetsPresent, isFalse);
      expect(audio.animalPromptReady, isFalse);
      expect(await audio.playAnimalPrompt(AnimalKind.cat), isFalse);
      expect(animal.plays, isEmpty);
    });
  });

  group('AnimalSoundMatchingAudio wrong + sound-off', () {
    test('TC-ASM-SFX-005 wrong plays friendly cue via activity', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.selectAnimal(_wrongChoice(activity));
      expect(player.plays, [AnimalSoundMatchingSfxCue.wrongSoft]);
      expect(activity.lastOutcome, isA<EncouragementOutcome>());
    });

    test('TC-ASM-SFX-006 soundOff skips all SFX including celebrate', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final activity =
          await _preparedActivity(player: player, soundOff: true);

      expect(activity.audioReady, isFalse);

      activity.notifyChoiceTap();
      activity.selectAnimal(_wrongChoice(activity));
      activity.selectAnimal(activity.round!.targetAnimal);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(player.plays, isEmpty);
      expect(player.stopCount, 0);
    });
  });

  group('AnimalSoundMatchingAudio anti-spam + rapid + complete', () {
    test('TC-ASM-SFX-007 duplicate serial does not double-celebrate', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final audio = _audio(player: player);
      await audio.probe('en-US');

      expect(
        await audio.playCorrectMatch(serial: 1, isCompletion: false),
        isTrue,
      );
      expect(
        await audio.playCorrectMatch(serial: 1, isCompletion: false),
        isFalse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.correctChime),
        hasLength(1),
      );
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.softClap),
        hasLength(1),
      );
    });

    test('TC-ASM-SFX-008 rapid matches celebrate each serial once', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player, ageMonths: 40);

      activity.selectAnimal(activity.round!.targetAnimal);
      activity.selectAnimal(activity.round!.targetAnimal);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.correctChime),
        hasLength(2),
      );
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.softClap).length,
        greaterThanOrEqualTo(1),
      );
      expect(activity.correctMatchSerial, 2);
    });

    test('TC-ASM-SFX-009 completion uses complete jingle not mid-match chime',
        () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player, ageMonths: 40);

      for (var i = 0; i < AnimalSoundMatchingConstants.roundsPerSession; i++) {
        activity.selectAnimal(activity.round!.targetAnimal);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.completeJingle),
        hasLength(1),
      );
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.correctChime),
        hasLength(AnimalSoundMatchingConstants.roundsPerSession - 1),
      );
    });
  });

  group('AnimalSoundMatchingAudio lifecycle / replay / dispose', () {
    test('TC-ASM-SFX-010 silence on pause stops pending sequence', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.selectAnimal(activity.round!.targetAnimal);
      expect(player.plays, contains(AnimalSoundMatchingSfxCue.correctChime));

      await activity.onPause();
      final playsAfterPause = List<AnimalSoundMatchingSfxCue>.from(player.plays);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(player.stopCount, greaterThanOrEqualTo(1));
      expect(player.plays, playsAfterPause);
    });

    test('TC-ASM-SFX-011 background silences SFX', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.selectAnimal(activity.round!.targetAnimal);
      await activity.onBackground();
      expect(player.stopCount, greaterThanOrEqualTo(1));
    });

    test('TC-ASM-SFX-012 replay resets celebrate serial and silences',
        () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final activity = await _preparedActivity(player: player);
      activity.selectAnimal(activity.round!.targetAnimal);
      expect(activity.audio.lastCelebratedSerial, 1);

      await activity.onRestart();
      expect(activity.audio.lastCelebratedSerial, 0);
      expect(player.stopCount, greaterThanOrEqualTo(1));

      activity.selectAnimal(activity.round!.targetAnimal);
      expect(activity.audio.lastCelebratedSerial, 1);
      expect(
        player.plays
            .where((c) => c == AnimalSoundMatchingSfxCue.correctChime)
            .length,
        2,
      );
    });

    test('TC-ASM-SFX-013 exit disposes players', () async {
      final sfx = RecordingAnimalSoundMatchingSfxPlayer();
      final bgm = RecordingAnimalSoundMatchingBgmPlayer();
      final animal = RecordingAnimalSoundMatchingAnimalPlayer();
      final activity = await _preparedActivity(
        player: sfx,
        bgmPlayer: bgm,
        animalPlayer: animal,
      );
      activity.notifyChoiceTap();
      expect(sfx.plays, [AnimalSoundMatchingSfxCue.tapPop]);

      await activity.onExit();
      expect(sfx.disposeCount, 1);
      expect(bgm.disposeCount, 1);
      expect(animal.disposeCount, 1);
      expect(activity.audio.isDisposed, isTrue);

      await activity.disposeResources();
      expect(sfx.disposeCount, 1);

      activity.notifyChoiceTap();
      activity.selectAnimal(activity.round!.targetAnimal);
      expect(sfx.plays, [AnimalSoundMatchingSfxCue.tapPop]);
    });

    test('TC-ASM-SFX-014 missing assets keep ready false', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final bgm = RecordingAnimalSoundMatchingBgmPlayer();
      final audio = AnimalSoundMatchingAudio(
        player: player,
        bgmPlayer: bgm,
        bundle: _ProbeBundle(presentPaths: {}),
      );
      await audio.probe('tr-TR');
      expect(audio.assetsPresent, isFalse);
      expect(audio.ready, isFalse);
      expect(await audio.playTap(), isFalse);
      expect(player.plays, isEmpty);
    });
  });

  group('AnimalSoundMatchingAudio regressions', () {
    test('TC-ASM-SFX-015 correct still advances without waiting for SFX',
        () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer();
      final audio = _audio(
        player: player,
        clapDelay: const Duration(seconds: 2),
        twinkleDelay: const Duration(seconds: 3),
      );
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 36,
        audio: audio,
        playSessionId: '00000000-0000-4000-8000-0000000000bb',
      );
      await activity.prepare();
      final before = activity.roundIndex;
      activity.selectAnimal(activity.round!.targetAnimal);
      expect(activity.roundIndex, before + 1);
      expect(activity.correctMatchSerial, 1);
    });

    test('TC-ASM-SFX-016 player canPlay false keeps ready false', () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer(canPlay: false);
      final audio = _audio(player: player);
      await audio.probe('en-US');
      expect(audio.assetsPresent, isTrue);
      expect(audio.ready, isFalse);
      expect(await audio.playWrong(), isFalse);
      expect(player.plays, isEmpty);
    });
  });

  group('AnimalSoundMatchingAudio celebrate in-flight serial race', () {
    Future<void> waitForHeld(RecordingAnimalSoundMatchingSfxPlayer player, int n) async {
      for (var i = 0; i < 40; i++) {
        if (player.pendingPlayCount >= n) return;
        await Future<void>.delayed(Duration.zero);
      }
      fail('expected $n held play(s), got ${player.pendingPlayCount}');
    }

    test(
        'TC-ASM-SFX-017 newer serial invalidates older in-flight lead',
        () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer(holdPlays: true);
      final audio = _audio(
        player: player,
        clapDelay: const Duration(milliseconds: 10),
        twinkleDelay: const Duration(milliseconds: 20),
      );
      await audio.probe('en-US');

      final older = audio.playCorrectMatch(serial: 1, isCompletion: false);
      await waitForHeld(player, 1);
      expect(player.nextHeldCue, AnimalSoundMatchingSfxCue.correctChime);

      final newer = audio.playCorrectMatch(serial: 2, isCompletion: false);
      await waitForHeld(player, 2);

      expect(player.releaseNextPlay(), isTrue);
      expect(await older, isFalse);

      player.holdPlays = false;
      expect(player.releaseNextPlay(), isTrue);
      expect(await newer, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.correctChime),
        hasLength(2),
      );
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.softClap),
        hasLength(1),
      );
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.twinkle),
        hasLength(1),
      );
      expect(audio.lastCelebratedSerial, 2);
    });

    test('TC-ASM-SFX-018 silence during in-flight lead blocks delayed sequence',
        () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer(holdPlays: true);
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
      expect(player.plays, [AnimalSoundMatchingSfxCue.correctChime]);
      expect(player.stopCount, greaterThanOrEqualTo(1));
      expect(audio.lifecycleEpoch, epochAfterSilence);
    });

    test('TC-ASM-SFX-019 dispose during in-flight lead blocks delayed sequence',
        () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer(holdPlays: true);
      final audio = _audio(
        player: player,
        clapDelay: const Duration(milliseconds: 10),
        twinkleDelay: const Duration(milliseconds: 20),
      );
      await audio.probe('en-US');

      final celebrate = audio.playCorrectMatch(serial: 1, isCompletion: false);
      await waitForHeld(player, 1);

      await audio.dispose();
      expect(await celebrate, isFalse);
      expect(audio.isDisposed, isTrue);
      expect(player.disposeCount, 1);
      expect(player.plays, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(player.plays, isEmpty);
    });

    test('TC-ASM-SFX-020 resetForReplay during in-flight lead blocks delayed cues',
        () async {
      final player = RecordingAnimalSoundMatchingSfxPlayer(holdPlays: true);
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
      expect(player.plays, [AnimalSoundMatchingSfxCue.correctChime]);
      expect(
        player.plays.where((c) => c == AnimalSoundMatchingSfxCue.softClap),
        isEmpty,
      );
    });
  });

  group('AnimalSoundMatchingAudio BGM + prompt duck', () {
    test('TC-ASM-BGM-001 ducks under animal prompt then restores', () async {
      final sfx = RecordingAnimalSoundMatchingSfxPlayer();
      final bgm = RecordingAnimalSoundMatchingBgmPlayer();
      final animal = RecordingAnimalSoundMatchingAnimalPlayer();
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        animalPlayer: animal,
        promptDuckRestore: const Duration(milliseconds: 40),
      );
      await audio.probe('en-US');
      await audio.ensureBgmPlaying();
      expect(bgm.volume, closeTo(0.20, 0.001));

      await audio.playAnimalPrompt(AnimalKind.duck);
      expect(bgm.volume, closeTo(0.05, 0.001));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bgm.volume, closeTo(0.20, 0.001));
    });

    test('TC-ASM-BGM-002 ducks on correct match then restores', () async {
      final sfx = RecordingAnimalSoundMatchingSfxPlayer();
      final bgm = RecordingAnimalSoundMatchingBgmPlayer();
      final audio = _audio(
        player: sfx,
        bgmPlayer: bgm,
        matchDuckRestore: const Duration(milliseconds: 40),
      );
      await audio.probe('en-US');
      await audio.ensureBgmPlaying();
      expect(bgm.volume, closeTo(0.20, 0.001));

      await audio.playCorrectMatch(serial: 1, isCompletion: false);
      expect(bgm.volume, closeTo(0.05, 0.001));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bgm.volume, closeTo(0.20, 0.001));
      expect(audio.lastDuckSerial, 1);
    });

    test('TC-ASM-BGM-003 pause during startup via activity', () async {
      final sfx = RecordingAnimalSoundMatchingSfxPlayer();
      final bgm = RecordingAnimalSoundMatchingBgmPlayer(holdOperations: true);
      final audio = _audio(player: sfx, bgmPlayer: bgm);
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 36,
        audio: audio,
        playSessionId: '00000000-0000-4000-8000-0000000000cc',
      );
      await activity.prepare();

      final enter = activity.onEnter();
      for (var i = 0; i < 40; i++) {
        if (bgm.pendingOperationCount >= 1) break;
        await Future<void>.delayed(Duration.zero);
      }

      await activity.onPause();
      expect(activity.interactionsEnabled, isFalse);
      expect(bgm.releaseNextOperation(), isTrue);
      await enter;

      expect(bgm.isPlaying, isFalse);
      expect(bgm.isPaused, isTrue);
    });
  });
}

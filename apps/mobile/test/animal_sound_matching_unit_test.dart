import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_activity.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_audio.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_constants.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_events.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_flame_layer.dart';
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

Set<String> _allAudioPaths() => {
      for (final cue in AnimalSoundMatchingAudio.requiredCues) cue.assetPath,
      AnimalSoundMatchingBgmTrack.assetPath,
      for (final k in AnimalKind.values)
        AnimalSoundMatchingAnimalTrack.assetPath(k),
    };

AnimalSoundMatchingAudio _testAudio({
  bool soundOff = false,
  RecordingAnimalSoundMatchingSfxPlayer? player,
  RecordingAnimalSoundMatchingBgmPlayer? bgmPlayer,
  RecordingAnimalSoundMatchingAnimalPlayer? animalPlayer,
}) {
  return AnimalSoundMatchingAudio(
    soundOff: soundOff,
    player: player ?? RecordingAnimalSoundMatchingSfxPlayer(),
    bgmPlayer: bgmPlayer ?? RecordingAnimalSoundMatchingBgmPlayer(),
    animalPlayer: animalPlayer ?? RecordingAnimalSoundMatchingAnimalPlayer(),
    bundle: _ProbeBundle(presentPaths: _allAudioPaths()),
  );
}

void main() {
  group('AnimalSoundMatchingBand', () {
    test('maps age bands to choice counts', () {
      expect(AnimalSoundMatchingBand.forAgeMonths(24)?.choiceCount, 2);
      expect(AnimalSoundMatchingBand.forAgeMonths(35)?.choiceCount, 2);
      expect(AnimalSoundMatchingBand.forAgeMonths(36)?.choiceCount, 3);
      expect(AnimalSoundMatchingBand.forAgeMonths(47)?.choiceCount, 3);
      expect(AnimalSoundMatchingBand.forAgeMonths(48)?.choiceCount, 4);
      expect(AnimalSoundMatchingBand.forAgeMonths(71)?.choiceCount, 4);
    });

    test('rejects unsupported ages fail-safe', () {
      expect(AnimalSoundMatchingBand.forAgeMonths(23), isNull);
      expect(AnimalSoundMatchingBand.forAgeMonths(72), isNull);
    });
  });

  group('AnimalSoundMatchingLogic determinism', () {
    test('same session and round yields identical layout', () {
      const session = 'session-abc';
      const band = AnimalSoundMatchingBand(
        minMonths: 24,
        maxMonths: 35,
        choiceCount: 2,
      );
      final a = AnimalSoundMatchingLogic.buildRound(
        playSessionId: session,
        roundIndex: 0,
        band: band,
      );
      final b = AnimalSoundMatchingLogic.buildRound(
        playSessionId: session,
        roundIndex: 0,
        band: band,
      );
      expect(a.targetAnimal, b.targetAnimal);
      expect(a.choices, b.choices);
    });

    test('different rounds can differ for same session', () {
      const session = 'session-abc';
      const band = AnimalSoundMatchingBand(
        minMonths: 48,
        maxMonths: 71,
        choiceCount: 4,
      );
      final r0 = AnimalSoundMatchingLogic.buildRound(
        playSessionId: session,
        roundIndex: 0,
        band: band,
      );
      final r1 = AnimalSoundMatchingLogic.buildRound(
        playSessionId: session,
        roundIndex: 1,
        band: band,
      );
      expect(r0.roundIndex, 0);
      expect(r1.roundIndex, 1);
      expect(
        AnimalSoundMatchingLogic.buildRound(
          playSessionId: session,
          roundIndex: 1,
          band: band,
        ).choices,
        r1.choices,
      );
    });

    test('target is always among choices', () {
      const session = 'session-target';
      for (final band in [
        AnimalSoundMatchingBand.forAgeMonths(30)!,
        AnimalSoundMatchingBand.forAgeMonths(40)!,
        AnimalSoundMatchingBand.forAgeMonths(55)!,
      ]) {
        for (var i = 0; i < 5; i++) {
          final r = AnimalSoundMatchingLogic.buildRound(
            playSessionId: session,
            roundIndex: i,
            band: band,
          );
          expect(r.choices.contains(r.targetAnimal), isTrue);
        }
      }
    });

    test('pool validation / restore layout gate', () {
      const toddler =
          AnimalSoundMatchingBand(minMonths: 24, maxMonths: 35, choiceCount: 2);
      expect(
        AnimalSoundMatchingLogic.animalPoolForBand(toddler),
        AnimalSoundMatchingLogic.toddlerPool,
      );
      expect(
        AnimalSoundMatchingLogic.isValidRestoredLayout(
          band: toddler,
          targetAnimal: AnimalKind.cat,
          choices: const [AnimalKind.dog, AnimalKind.cat],
        ),
        isTrue,
      );
      expect(
        AnimalSoundMatchingLogic.isValidRestoredLayout(
          band: toddler,
          targetAnimal: AnimalKind.horse,
          choices: const [AnimalKind.cat, AnimalKind.dog],
        ),
        isFalse,
      );
      expect(
        AnimalSoundMatchingLogic.isValidRestoredLayout(
          band: toddler,
          targetAnimal: AnimalKind.cat,
          choices: const [AnimalKind.cat, AnimalKind.cat],
        ),
        isFalse,
      );
    });
  });

  group('AnimalSoundMatching eligibility', () {
    test('17 months fail-safe', () async {
      final activity = AnimalSoundMatchingActivity(ageMonthsProvider: () => 17);
      expect(activity.isPlayable, isFalse);
      expect(activity.prepare(), throwsStateError);
    });

    test('24 months uses two choices', () async {
      final activity = AnimalSoundMatchingActivity(ageMonthsProvider: () => 24);
      await activity.prepare();
      expect(activity.round?.choices.length, 2);
    });

    test('36 months uses three choices', () async {
      final activity = AnimalSoundMatchingActivity(ageMonthsProvider: () => 36);
      await activity.prepare();
      expect(activity.round?.choices.length, 3);
    });

    test('60 months uses four choices', () async {
      final activity = AnimalSoundMatchingActivity(ageMonthsProvider: () => 60);
      await activity.prepare();
      expect(activity.round?.choices.length, 4);
    });
  });

  group('AnimalSoundMatchingActivity gameplay', () {
    test('completes after three correct matches', () async {
      final buffer = AnimalSoundMatchingLocalEventBuffer();
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 40,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000088',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      await activity.onEnter();

      for (var round = 0;
          round < AnimalSoundMatchingConstants.roundsPerSession;
          round++) {
        final target = activity.round!.targetAnimal;
        activity.selectAnimal(target);
      }

      expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
      expect(
        activity.correctMatchSerial,
        AnimalSoundMatchingConstants.roundsPerSession,
      );
      expect(
        buffer.events.where((e) => e.eventType == 'activity_completed').length,
        1,
      );
    });

    test('wrong choice does not advance and allows retry', () async {
      final buffer = AnimalSoundMatchingLocalEventBuffer();
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 30,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000077',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      await activity.onEnter();
      final before = activity.roundIndex;
      final wrong = activity.round!.choices
          .firstWhere((c) => c != activity.round!.targetAnimal);
      activity.selectAnimal(wrong);
      expect(activity.roundIndex, before);
      expect(activity.lastOutcome, isA<EncouragementOutcome>());
      expect((activity.lastOutcome as EncouragementOutcome).cueKey, 'try_again');
      activity.selectAnimal(activity.round!.targetAnimal);
      expect(activity.roundIndex, before + 1);
    });

    test('hint after two wrongs', () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 32,
        playSessionId: '00000000-0000-4000-8000-000000000076',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      await activity.onEnter();
      final wrong = activity.round!.choices
          .firstWhere((c) => c != activity.round!.targetAnimal);
      activity.selectAnimal(wrong);
      expect(activity.hintLevel, 0);
      activity.selectAnimal(wrong);
      expect(activity.hintLevel, 1);
      expect(activity.lastOutcome, isA<HintOfferedOutcome>());
    });

    test('privacy rejects forbidden payload keys', () {
      expect(
        AnimalSoundMatchingEventPrivacy.payloadLooksSafe({'child_name': 'x'}),
        isFalse,
      );
      expect(
        AnimalSoundMatchingEventPrivacy.payloadLooksSafe({'pointer_x': 1}),
        isFalse,
      );
      expect(
        AnimalSoundMatchingEventPrivacy.payloadLooksSafe({
          'animal_id': 'cat',
          'choice_id': 'dog',
          'correct': false,
        }),
        isTrue,
      );
    });

    test('local buffer uses fixture content version not a UUID', () {
      final buffer = AnimalSoundMatchingLocalEventBuffer();
      expect(buffer.contentVersionId, AnimalSoundMatchingConstants.contentVersionId);
      expect(buffer.contentVersionId.contains('fixture'), isTrue);
    });

    test('soundOff uses visual fallback prompt mode and emits prompt_mode', () async {
      final buffer = AnimalSoundMatchingLocalEventBuffer();
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 36,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000075',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      expect(activity.promptMode, AnimalPromptMode.visualFallback);
      expect(activity.usesVisualFallback, isTrue);
      await activity.onEnter();
      final started = buffer.events
          .singleWhere((e) => e.eventType == 'activity_started');
      expect(started.payload['prompt_mode'], 'visual');
    });

    test('prompt playback failure switches to sticky visual fallback', () async {
      final buffer = AnimalSoundMatchingLocalEventBuffer();
      final animal = RecordingAnimalSoundMatchingAnimalPlayer()..succeed = false;
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 36,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000076',
        audio: _testAudio(animalPlayer: animal),
      );
      await activity.prepare();
      expect(activity.promptMode, AnimalPromptMode.audio);
      await activity.onEnter();
      expect(activity.promptMode, AnimalPromptMode.visualFallback);
      expect(activity.usesVisualFallback, isTrue);
      // Sticky: subsequent refresh must not flip back while force flag holds.
      activity.selectAnimal(activity.round!.targetAnimal);
      expect(
        buffer.events
            .where((e) => e.eventType == 'activity_attempted')
            .last
            .payload['prompt_mode'],
        'visual',
      );
    });

    test('replay playback failure switches to visual fallback', () async {
      final animal = RecordingAnimalSoundMatchingAnimalPlayer();
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 30,
        playSessionId: '00000000-0000-4000-8000-000000000077',
        audio: _testAudio(animalPlayer: animal),
      );
      await activity.prepare();
      await activity.onEnter();
      expect(activity.promptMode, AnimalPromptMode.audio);

      animal.succeed = false;
      final replayed = await activity.replayAnimalSound();
      expect(replayed, isFalse);
      expect(activity.promptMode, AnimalPromptMode.visualFallback);
      expect(activity.usesVisualFallback, isTrue);
    });

    test('stale prompt completion after pause does not force visual mode',
        () async {
      final animal = RecordingAnimalSoundMatchingAnimalPlayer(holdPlays: true);
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 36,
        playSessionId: '00000000-0000-4000-8000-000000000078',
        audio: _testAudio(animalPlayer: animal),
      );
      await activity.prepare();
      // onEnter starts a held prompt.
      final enter = activity.onEnter();
      for (var i = 0; i < 40; i++) {
        if (animal.pendingPlayCount >= 1) break;
        await Future<void>.delayed(Duration.zero);
      }
      expect(animal.pendingPlayCount, 1);
      await activity.onPause();
      // silence/stop fails the held play; generation was already invalidated.
      await enter;
      // Pause invalidated the prompt; no sticky visual from a cancelled play.
      expect(activity.usesVisualFallback, isFalse);
      expect(activity.promptMode, AnimalPromptMode.audio);
    });

    test('abandon emits once on exit before completion', () async {
      final buffer = AnimalSoundMatchingLocalEventBuffer();
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 36,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000066',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
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
      final buffer = AnimalSoundMatchingLocalEventBuffer();
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 36,
        eventBuffer: buffer,
        playSessionId: '00000000-0000-4000-8000-000000000055',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      await activity.onEnter();
      activity.selectAnimal(activity.round!.targetAnimal);
      await activity.onRestart();
      expect(activity.roundIndex, 0);
      expect(activity.correctMatchSerial, 0);
      expect(
        buffer.events.where((e) => e.eventType == 'activity_started').length,
        greaterThanOrEqualTo(2),
      );
    });

    test('capture/restore play state is round-safe', () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 48,
        playSessionId: '00000000-0000-4000-8000-000000000044',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      final snap = activity.capturePlayState();
      await activity.restorePlayState(snap);
      expect(activity.round?.targetAnimal.name, snap['target_animal']);
      expect(activity.round?.choices.map((c) => c.name).toList(), snap['choices']);
    });

    test('restorePlayState rejects unknown animal enum without crashing',
        () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 30,
        playSessionId: '00000000-0000-4000-8000-000000000033',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      final before = activity.capturePlayState();
      await activity.restorePlayState({
        ...before,
        'target_animal': 'not_an_animal',
      });
      expect(activity.round, isNotNull);
      expect(activity.round!.choices.length, 2);
      expect(
        AnimalKind.values.map((c) => c.name),
        contains(activity.round!.targetAnimal.name),
      );
    });

    test('restorePlayState rejects wrong choice count for age band', () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 30,
        playSessionId: '00000000-0000-4000-8000-000000000032',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      await activity.restorePlayState({
        'round_index': 1,
        'hint_level': 0,
        'wrong_attempts': 0,
        'celebration': false,
        'target_animal': 'cat',
        'choices': ['cat', 'dog', 'cow', 'duck'],
      });
      expect(activity.roundIndex, 1);
      expect(activity.round!.choices.length, 2);
      expect(activity.round!.choices.toSet().length, 2);
    });

    test('restorePlayState rejects duplicate choices and out-of-range round',
        () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 40,
        playSessionId: '00000000-0000-4000-8000-000000000031',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      await activity.restorePlayState({
        'round_index': 99,
        'hint_level': 0,
        'wrong_attempts': 0,
        'celebration': false,
        'target_animal': 'cat',
        'choices': ['cat', 'cat', 'duck'],
      });
      expect(activity.roundIndex, 0);
      expect(activity.round, isNotNull);
      expect(activity.round!.choices.length, 3);
      expect(activity.round!.choices.toSet().length, 3);
    });

    test('restorePlayState rejects target absent from choices', () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 40,
        playSessionId: '00000000-0000-4000-8000-000000000030',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      final safe = activity.capturePlayState();
      await activity.restorePlayState({
        ...safe,
        'target_animal': 'horse',
        'choices': ['cat', 'dog', 'duck'],
      });
      expect(activity.round!.choices.length, 3);
      expect(
        activity.round!.choices.contains(activity.round!.targetAnimal),
        isTrue,
      );
    });

    test('restorePlayState rejects valid-length out-of-band choices', () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 28,
        playSessionId: '00000000-0000-4000-8000-000000000029',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      final beforeChoices = activity.round!.choices.toList(growable: false);
      await activity.restorePlayState({
        'round_index': 0,
        'hint_level': 0,
        'wrong_attempts': 0,
        'celebration': false,
        'target_animal': 'bird',
        'choices': ['bird', 'sheep'],
      });
      expect(activity.round!.choices.length, 2);
      final pool = AnimalSoundMatchingLogic.animalPoolForBand(activity.band!);
      expect(
        activity.round!.choices.every(pool.contains),
        isTrue,
      );
      expect(activity.round!.choices.toSet().length, 2);
      // Fail-closed reload — may reshuffle order but stays in-band vs. stale layout.
      expect(beforeChoices.toSet(), activity.round!.choices.toSet());
    });

    test('restorePlayState accepts valid in-band roundtrip', () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 50,
        playSessionId: '00000000-0000-4000-8000-000000000027',
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      const layout = {
        'round_index': 1,
        'hint_level': 1,
        'wrong_attempts': 2,
        'celebration': false,
        'target_animal': 'frog',
        'choices': ['frog', 'cat', 'horse', 'bird'],
      };
      expect(
        AnimalSoundMatchingLogic.isValidRestoredLayout(
          band: activity.band!,
          targetAnimal: AnimalKind.frog,
          choices: const [
            AnimalKind.frog,
            AnimalKind.cat,
            AnimalKind.horse,
            AnimalKind.bird,
          ],
        ),
        isTrue,
      );
      await activity.restorePlayState(layout);
      expect(activity.roundIndex, 1);
      expect(activity.hintLevel, 1);
      expect(activity.round!.targetAnimal, AnimalKind.frog);
      expect(
        activity.round!.choices.map((c) => c.name).toList(),
        ['frog', 'cat', 'horse', 'bird'],
      );
      final snap = activity.capturePlayState();
      await activity.restorePlayState(snap);
      expect(activity.round!.targetAnimal.name, snap['target_animal']);
      expect(activity.round!.choices.map((c) => c.name).toList(), snap['choices']);
    });

    test('flame layer mounts and unmounts', () async {
      final activity = AnimalSoundMatchingActivity(
        ageMonthsProvider: () => 36,
        audio: AnimalSoundMatchingAudio(
          soundOff: true,
          player: RecordingAnimalSoundMatchingSfxPlayer(),
          bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
          animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
        ),
        soundOff: true,
      );
      await activity.prepare();
      final game = FlameGame();
      await game.onLoad();
      activity.bindFlameGame(game);
      await activity.mountFlameLayer(game);
      expect(game.children.query<AnimalSoundMatchingFlameLayer>(), isNotEmpty);
      await activity.unmountFlameLayer(game);
      expect(game.children.query<AnimalSoundMatchingFlameLayer>(), isEmpty);
    });
  });
}

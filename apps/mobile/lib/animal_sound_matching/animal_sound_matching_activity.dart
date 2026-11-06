import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../game/learning_activity.dart';
import '../game/scoring_neutral_outcome.dart';
import 'animal_sound_matching_audio.dart';
import 'animal_sound_matching_constants.dart';
import 'animal_sound_matching_events.dart';
import 'animal_sound_matching_flame_layer.dart';
import 'animal_sound_matching_logic.dart';
import 'animal_sound_matching_production_event_buffer.dart';

/// Developer-owned Animal Sound Matching hub activity (LMP-57 / ADR-015).
class AnimalSoundMatchingActivity extends LearningActivity {
  AnimalSoundMatchingActivity({
    required this.ageMonthsProvider,
    AnimalSoundMatchingLocalEventBuffer? eventBuffer,
    AnimalSoundMatchingAudio? audio,
    this.localeTag = 'en-US',
    this.soundOff = false,
    String? playSessionId,
    String Function()? sessionIdFactory,
  })  : eventBuffer = eventBuffer ?? AnimalSoundMatchingLocalEventBuffer(),
        _audio = audio ?? AnimalSoundMatchingAudio(soundOff: soundOff),
        playSessionId = playSessionId ??
            (sessionIdFactory?.call() ??
                'session-${DateTime.now().toUtc().microsecondsSinceEpoch}');

  final int? Function() ageMonthsProvider;
  final AnimalSoundMatchingLocalEventBuffer eventBuffer;
  final AnimalSoundMatchingAudio _audio;
  final String localeTag;
  final bool soundOff;
  final String playSessionId;

  /// Exposed for play-field SFX / prompt replay and tests.
  AnimalSoundMatchingAudio get audio => _audio;

  FlameGame? _game;
  var _ageMonths = -1;
  AnimalSoundMatchingBand? _band;
  var _roundIndex = 0;
  AnimalSoundMatchingRound? _round;
  var _interactionsEnabled = true;
  var _startedEmitted = false;
  var _abandonedEmitted = false;
  var _hintLevel = 0;
  var _wrongAttemptsThisRound = 0;
  var _showCelebrationPulse = false;
  /// UI-only monotonic success id — one tick per correct match (not telemetry).
  var _correctMatchSerial = 0;
  AnimalPromptMode _promptMode = AnimalPromptMode.audio;
  /// Sticky visual mode after a runtime prompt/replay playback failure.
  /// Cleared on prepare / replay when animal prompts become eligible again.
  var _forceVisualFallback = false;
  /// Cancels stale async prompt/replay completions after pause / advance / exit.
  var _promptPlayGeneration = 0;
  ScoringNeutralOutcome? _lastOutcome;
  final _listeners = <VoidCallback>[];

  bool get interactionsEnabled => _interactionsEnabled;
  bool get showCelebrationPulse => _showCelebrationPulse;
  int get correctMatchSerial => _correctMatchSerial;
  int get ageMonths => _ageMonths;
  AnimalSoundMatchingBand? get band => _band;
  int get roundIndex => _roundIndex;
  AnimalSoundMatchingRound? get round => _round;
  ScoringNeutralOutcome? get lastOutcome => _lastOutcome;
  int get hintLevel => _hintLevel;
  AnimalPromptMode get promptMode => _promptMode;
  bool get usesVisualFallback =>
      _promptMode == AnimalPromptMode.visualFallback;
  bool get audioAssetsPresent => _audio.assetsPresent;
  bool get audioReady => _audio.ready;
  bool get bgmAssetPresent => _audio.bgmAssetPresent;
  bool get bgmReady => _audio.bgmReady;
  bool get animalAssetsPresent => _audio.animalAssetsPresent;
  bool get animalPromptReady => _audio.animalPromptReady;

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  void bindFlameGame(FlameGame game) {
    _game = game;
  }

  @override
  String get id => AnimalSoundMatchingConstants.activityId;

  @override
  String get displayName => 'Animal Sound Matching';

  @override
  bool get isPlayable {
    final age = ageMonthsProvider();
    if (age == null) {
      return false;
    }
    return AnimalSoundMatchingBand.forAgeMonths(age) != null;
  }

  @override
  Future<void> prepare() async {
    final age = ageMonthsProvider();
    if (age == null) {
      throw StateError(
        'Animal Sound Matching requires a selected child profile with age.',
      );
    }
    final band = AnimalSoundMatchingBand.forAgeMonths(age);
    if (band == null) {
      throw StateError(
        'Animal Sound Matching age $age is outside supported bands '
        '${AnimalSoundMatchingConstants.productAgeMinMonths}–'
        '${AnimalSoundMatchingConstants.productAgeMaxMonths} months.',
      );
    }
    _ageMonths = age;
    _band = band;
    await _audio.probe(localeTag);
    _forceVisualFallback = false;
    _invalidatePromptPlays();
    _refreshPromptMode();
    _resetProgress(emitStarted: false);
  }

  @override
  Future<void> onEnter() async {
    _emitStartedIfNeeded();
    await _audio.ensureBgmPlaying();
    await _playRoundPrompt();
    final game = _game;
    if (game != null) {
      await mountFlameLayer(game);
    }
  }

  @override
  Future<void> onPause() async {
    setInteractionsEnabled(false);
    _invalidatePromptPlays();
    await _audio.silence();
    await _drainProduction();
  }

  @override
  Future<void> onResume() async {
    if (_lastOutcome is! ActivityCompletedOutcome) {
      setInteractionsEnabled(true);
    }
    if (!_interactionsEnabled) return;
    await _audio.resumeBgm();
  }

  @override
  Future<void> onBackground() async {
    setInteractionsEnabled(false);
    _invalidatePromptPlays();
    await _audio.silence();
    await _drainProduction();
  }

  @override
  Future<void> onForeground() async {
    if (!_interactionsEnabled) return;
    await _audio.resumeBgm();
  }

  @override
  Future<void> onRestart() async {
    _invalidatePromptPlays();
    await _audio.resetForReplay();
    // Fresh session may recover from a prior sticky visual fallback.
    _forceVisualFallback = false;
    _refreshPromptMode();
    _resetProgress(emitStarted: true);
    setInteractionsEnabled(true);
    await _playRoundPrompt();
    _notify();
  }

  @override
  Future<void> onExit() async {
    _invalidatePromptPlays();
    if (_lastOutcome is! ActivityCompletedOutcome &&
        _lastOutcome is! ActivityAbandonedOutcome &&
        !_abandonedEmitted) {
      _abandonedEmitted = true;
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: AnimalSoundMatchingEventType.activityAbandoned,
        payload: {
          'completion_status': 'abandoned',
          'prompt_mode': _promptModeWire,
        },
      );
    }
    await _audio.dispose();
    await _drainProduction();
    final game = _game;
    if (game != null) {
      await unmountFlameLayer(game);
    }
  }

  @override
  Future<void> disposeResources() async {
    _invalidatePromptPlays();
    await _audio.dispose();
    final game = _game;
    if (game != null) {
      await unmountFlameLayer(game);
    }
    _game = null;
  }

  void notifyChoiceTap() {
    // ignore: discarded_futures
    _audio.playTap();
  }

  /// Replay the current animal prompt. No-op / visual-only when muted or missing.
  ///
  /// On runtime playback failure, switches to accessible visual fallback and
  /// notifies the UI so gameplay never deadlocks waiting for sound.
  Future<bool> replayAnimalSound() async {
    if (!_interactionsEnabled) return false;
    if (_lastOutcome is ActivityCompletedOutcome) return false;
    _refreshPromptMode();
    if (_promptMode == AnimalPromptMode.visualFallback) {
      _notify();
      return false;
    }
    final target = _round?.targetAnimal;
    if (target == null) return false;
    final gen = ++_promptPlayGeneration;
    final played = await _audio.playAnimalPrompt(target, forceRestart: true);
    if (gen != _promptPlayGeneration) return false;
    if (!played) {
      _enterVisualFallback();
      return false;
    }
    return true;
  }

  void setInteractionsEnabled(bool enabled) {
    if (_interactionsEnabled == enabled) return;
    _interactionsEnabled = enabled;
    _notify();
  }

  String get _promptModeWire =>
      _promptMode == AnimalPromptMode.visualFallback ? 'visual' : 'audio';

  void _refreshPromptMode() {
    // Explicit accessible visual fallback — never deadlock, never pretend audio.
    if (soundOff || !_audio.animalPromptReady || _forceVisualFallback) {
      _promptMode = AnimalPromptMode.visualFallback;
    } else {
      _promptMode = AnimalPromptMode.audio;
    }
  }

  /// Sticky visual matching after sound-off / missing assets / playback failure.
  void _enterVisualFallback() {
    _forceVisualFallback = true;
    _promptMode = AnimalPromptMode.visualFallback;
    _notify();
  }

  void _invalidatePromptPlays() {
    _promptPlayGeneration++;
  }

  void _resetProgress({required bool emitStarted}) {
    _roundIndex = 0;
    _hintLevel = 0;
    _wrongAttemptsThisRound = 0;
    _showCelebrationPulse = false;
    _correctMatchSerial = 0;
    _lastOutcome = null;
    _startedEmitted = false;
    _abandonedEmitted = false;
    _loadRound();
    if (emitStarted) {
      _emitStartedIfNeeded(restart: true);
    }
  }

  void _loadRound() {
    final band = _band;
    if (band == null) return;
    _round = AnimalSoundMatchingLogic.buildRound(
      playSessionId: playSessionId,
      roundIndex: _roundIndex,
      band: band,
    );
    _wrongAttemptsThisRound = 0;
    _hintLevel = 0;
  }

  Future<void> _playRoundPrompt() async {
    _refreshPromptMode();
    if (_promptMode == AnimalPromptMode.visualFallback) {
      _notify();
      return;
    }
    final target = _round?.targetAnimal;
    if (target == null) return;
    final gen = ++_promptPlayGeneration;
    final played = await _audio.playAnimalPrompt(target, forceRestart: true);
    if (gen != _promptPlayGeneration) return;
    if (!played) {
      _enterVisualFallback();
    }
  }

  void _emitStartedIfNeeded({bool restart = false}) {
    if (_startedEmitted) return;
    _startedEmitted = true;
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: AnimalSoundMatchingEventType.activityStarted,
      payload: {
        'activity_variant_id': AnimalSoundMatchingConstants.activityId,
        'age_months': _ageMonths,
        'choice_count': _band?.choiceCount,
        'prompt_mode': _promptModeWire,
        if (restart) 'restart': true,
      },
    );
  }

  Future<void> _drainProduction() async {
    if (eventBuffer is AnimalSoundMatchingProductionEventBuffer) {
      await (eventBuffer as AnimalSoundMatchingProductionEventBuffer).drain();
    }
  }

  /// Select [choice] as the matching animal for the current prompt.
  void selectAnimal(AnimalKind choice) {
    if (!_interactionsEnabled) return;
    final current = _round;
    if (current == null || _lastOutcome is ActivityCompletedOutcome) return;

    _refreshPromptMode();
    final correct = AnimalSoundMatchingLogic.isCorrectChoice(current, choice);
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: AnimalSoundMatchingEventType.activityAttempted,
      payload: {
        'animal_id': current.targetAnimal.name,
        'choice_id': choice.name,
        'correct': correct,
        'round_index': _roundIndex,
        'prompt_mode': _promptModeWire,
      },
    );

    if (correct) {
      _correctMatchSerial++;
      _showCelebrationPulse = true;
      final willComplete =
          _roundIndex + 1 >= AnimalSoundMatchingConstants.roundsPerSession;
      // ignore: discarded_futures
      _audio.playCorrectMatch(
        serial: _correctMatchSerial,
        isCompletion: willComplete,
      );
      _lastOutcome = const EncouragementOutcome(cueKey: 'animal_match');
      _notify();
      _advanceAfterCorrect();
      return;
    }

    _wrongAttemptsThisRound++;
    // ignore: discarded_futures
    _audio.playWrong();
    _lastOutcome = const EncouragementOutcome(cueKey: 'try_again');
    if (_wrongAttemptsThisRound >= 2) {
      offerHint();
    }
    _notify();
  }

  void offerHint() {
    if (_hintLevel >= 2) return;
    final nextLevel = _hintLevel + 1;
    _hintLevel = nextLevel;
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: AnimalSoundMatchingEventType.activityHintUsed,
      payload: {'hint_level': nextLevel},
    );
    _lastOutcome = HintOfferedOutcome(level: nextLevel);
    _notify();
  }

  void _advanceAfterCorrect() {
    _roundIndex++;
    if (_roundIndex >= AnimalSoundMatchingConstants.roundsPerSession) {
      onOutcome(const ActivityCompletedOutcome());
      return;
    }
    _showCelebrationPulse = false;
    _loadRound();
    // Invalidate any in-flight prompt from the previous round.
    _invalidatePromptPlays();
    // ignore: discarded_futures
    _playRoundPrompt();
    _notify();
  }

  @override
  void onOutcome(ScoringNeutralOutcome outcome) {
    if (_lastOutcome is ActivityCompletedOutcome &&
        outcome is ActivityCompletedOutcome) {
      return;
    }
    if (_lastOutcome is ActivityAbandonedOutcome &&
        outcome is ActivityAbandonedOutcome) {
      return;
    }
    _lastOutcome = outcome;
    if (outcome is ActivityCompletedOutcome) {
      setInteractionsEnabled(false);
      _showCelebrationPulse = true;
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: AnimalSoundMatchingEventType.activityCompleted,
        payload: {
          'completion_status': 'completed',
          'scoring': 'neutral',
          'prompt_mode': _promptModeWire,
        },
      );
    } else if (outcome is ActivityAbandonedOutcome) {
      if (_abandonedEmitted) return;
      _abandonedEmitted = true;
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: AnimalSoundMatchingEventType.activityAbandoned,
        payload: {
          'completion_status': 'abandoned',
          'prompt_mode': _promptModeWire,
        },
      );
    } else if (outcome is HintOfferedOutcome) {
      // Telemetry for hints is owned by [offerHint] only.
    }
    _notify();
  }

  @override
  Map<String, Object?> capturePlayState() => {
        'round_index': _roundIndex,
        'hint_level': _hintLevel,
        'target_animal': _round?.targetAnimal.name,
        'choices': _round?.choices.map((c) => c.name).toList(),
        'wrong_attempts': _wrongAttemptsThisRound,
        'celebration': _showCelebrationPulse,
        'prompt_mode': _promptModeWire,
      };

  @override
  Future<void> restorePlayState(Map<String, Object?> state) async {
    final restored = _tryParsePlayState(state);
    if (restored == null) {
      // Malformed / stale / cross-band state — fail closed into a valid
      // deterministic round for the current age band (no crash, no leakage).
      _hintLevel = 0;
      _wrongAttemptsThisRound = 0;
      _showCelebrationPulse = false;
      final candidateRound = state['round_index'];
      if (candidateRound is int &&
          candidateRound >= 0 &&
          candidateRound < AnimalSoundMatchingConstants.roundsPerSession) {
        _roundIndex = candidateRound;
      } else if (_roundIndex < 0 ||
          _roundIndex >= AnimalSoundMatchingConstants.roundsPerSession) {
        _roundIndex = 0;
      }
      _loadRound();
      _refreshPromptMode();
      _notify();
      return;
    }

    _roundIndex = restored.roundIndex;
    _hintLevel = restored.hintLevel;
    _wrongAttemptsThisRound = restored.wrongAttempts;
    _showCelebrationPulse = restored.celebration;
    _round = restored.round;
    _refreshPromptMode();
    _notify();
  }

  /// Validates captured play state against the active age band.
  _RestoredPlayState? _tryParsePlayState(Map<String, Object?> state) {
    final band = _band;
    if (band == null) return null;

    final roundIndex = state['round_index'];
    if (roundIndex is! int ||
        roundIndex < 0 ||
        roundIndex >= AnimalSoundMatchingConstants.roundsPerSession) {
      return null;
    }

    final hintLevel = state['hint_level'];
    if (hintLevel is! int || hintLevel < 0 || hintLevel > 2) {
      return null;
    }

    final wrongAttempts = state['wrong_attempts'];
    if (wrongAttempts is! int || wrongAttempts < 0) {
      return null;
    }

    final celebration = state['celebration'];
    if (celebration is! bool) {
      return null;
    }

    final targetName = state['target_animal'];
    final choiceNames = state['choices'];
    if (targetName is! String || choiceNames is! List) {
      return null;
    }

    final targetAnimal = _animalNamed(targetName);
    if (targetAnimal == null) {
      return null;
    }

    final choices = <AnimalKind>[];
    for (final name in choiceNames) {
      if (name is! String) return null;
      final token = _animalNamed(name);
      if (token == null) return null;
      choices.add(token);
    }

    if (!AnimalSoundMatchingLogic.isValidRestoredLayout(
      band: band,
      targetAnimal: targetAnimal,
      choices: choices,
    )) {
      return null;
    }

    return _RestoredPlayState(
      roundIndex: roundIndex,
      hintLevel: hintLevel,
      wrongAttempts: wrongAttempts,
      celebration: celebration,
      round: AnimalSoundMatchingRound(
        roundIndex: roundIndex,
        targetAnimal: targetAnimal,
        choices: List.unmodifiable(choices),
      ),
    );
  }

  static AnimalKind? _animalNamed(String name) {
    for (final token in AnimalKind.values) {
      if (token.name == name) return token;
    }
    return null;
  }
}

final class _RestoredPlayState {
  const _RestoredPlayState({
    required this.roundIndex,
    required this.hintLevel,
    required this.wrongAttempts,
    required this.celebration,
    required this.round,
  });

  final int roundIndex;
  final int hintLevel;
  final int wrongAttempts;
  final bool celebration;
  final AnimalSoundMatchingRound round;
}

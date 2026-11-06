import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../game/learning_activity.dart';
import '../game/scoring_neutral_outcome.dart';
import 'shape_matching_audio.dart';
import 'shape_matching_constants.dart';
import 'shape_matching_events.dart';
import 'shape_matching_flame_layer.dart';
import 'shape_matching_logic.dart';
import 'shape_matching_production_event_buffer.dart';

/// Developer-owned Shape Matching hub activity (LMP-55 / ADR-015).
class ShapeMatchingActivity extends LearningActivity {
  ShapeMatchingActivity({
    required this.ageMonthsProvider,
    ShapeMatchingLocalEventBuffer? eventBuffer,
    ShapeMatchingAudio? audio,
    this.localeTag = 'en-US',
    this.soundOff = false,
    String? playSessionId,
    String Function()? sessionIdFactory,
  })  : eventBuffer = eventBuffer ?? ShapeMatchingLocalEventBuffer(),
        _audio = audio ?? ShapeMatchingAudio(soundOff: soundOff),
        playSessionId = playSessionId ??
            (sessionIdFactory?.call() ??
                'session-${DateTime.now().toUtc().microsecondsSinceEpoch}');

  final int? Function() ageMonthsProvider;
  final ShapeMatchingLocalEventBuffer eventBuffer;
  final ShapeMatchingAudio _audio;
  final String localeTag;
  final bool soundOff;
  final String playSessionId;

  /// Exposed for play-field tap/drag SFX and tests — single shared audio system.
  ShapeMatchingAudio get audio => _audio;

  FlameGame? _game;
  var _ageMonths = -1;
  ShapeMatchingBand? _band;
  var _roundIndex = 0;
  ShapeMatchingRound? _round;
  var _interactionsEnabled = true;
  var _startedEmitted = false;
  var _abandonedEmitted = false;
  var _hintLevel = 0;
  var _wrongAttemptsThisRound = 0;
  var _showCelebrationPulse = false;
  /// UI-only monotonic success id — one tick per correct match (not telemetry).
  var _correctMatchSerial = 0;
  ScoringNeutralOutcome? _lastOutcome;
  final _listeners = <VoidCallback>[];

  bool get interactionsEnabled => _interactionsEnabled;
  bool get showCelebrationPulse => _showCelebrationPulse;
  /// Increments once per correct pick; play-field uses this for one celebration
  /// per match under rapid / duplicate notifications (not a wire payload field).
  int get correctMatchSerial => _correctMatchSerial;
  int get ageMonths => _ageMonths;
  ShapeMatchingBand? get band => _band;
  int get roundIndex => _roundIndex;
  ShapeMatchingRound? get round => _round;
  ScoringNeutralOutcome? get lastOutcome => _lastOutcome;
  int get hintLevel => _hintLevel;
  bool get audioAssetsPresent => _audio.assetsPresent;
  bool get audioReady => _audio.ready;
  bool get bgmAssetPresent => _audio.bgmAssetPresent;
  bool get bgmReady => _audio.bgmReady;

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
  String get id => ShapeMatchingConstants.activityId;

  @override
  String get displayName => 'Shape Matching';

  @override
  bool get isPlayable {
    final age = ageMonthsProvider();
    if (age == null) {
      return false;
    }
    return ShapeMatchingBand.forAgeMonths(age) != null;
  }

  @override
  Future<void> prepare() async {
    final age = ageMonthsProvider();
    if (age == null) {
      throw StateError(
        'Shape Matching requires a selected child profile with age.',
      );
    }
    final band = ShapeMatchingBand.forAgeMonths(age);
    if (band == null) {
      throw StateError(
        'Shape Matching age $age is outside supported bands '
        '${ShapeMatchingConstants.productAgeMinMonths}–'
        '${ShapeMatchingConstants.productAgeMaxMonths} months.',
      );
    }
    _ageMonths = age;
    _band = band;
    await _audio.probe(localeTag);
    _resetProgress(emitStarted: false);
  }

  @override
  Future<void> onEnter() async {
    _emitStartedIfNeeded();
    // Single Happy Garden BGM instance — loops for the whole play session.
    await _audio.ensureBgmPlaying();
    final game = _game;
    if (game != null) {
      await mountFlameLayer(game);
    }
  }

  @override
  Future<void> onPause() async {
    setInteractionsEnabled(false);
    // Screen-time / pause — stop SFX + pause BGM (resume restores loop).
    await _audio.silence();
    await _drainProduction();
  }

  @override
  Future<void> onResume() async {
    if (_lastOutcome is! ActivityCompletedOutcome) {
      setInteractionsEnabled(true);
    }
    // No BGM while gameplay remains blocked (screen-time / pause / complete).
    if (!_interactionsEnabled) return;
    await _audio.resumeBgm();
  }

  @override
  Future<void> onBackground() async {
    setInteractionsEnabled(false);
    await _audio.silence();
    await _drainProduction();
  }

  @override
  Future<void> onForeground() async {
    // Foreground alone must not restart BGM while pause / screen-time still
    // blocks play (_pausedBeforeBackground → onForeground without onResume).
    if (!_interactionsEnabled) return;
    await _audio.resumeBgm();
  }

  @override
  Future<void> onRestart() async {
    // Replay keeps the same BGM instance (no duplicate startLoop).
    await _audio.resetForReplay();
    _resetProgress(emitStarted: true);
    setInteractionsEnabled(true);
    _notify();
  }

  @override
  Future<void> onExit() async {
    if (_lastOutcome is! ActivityCompletedOutcome &&
        _lastOutcome is! ActivityAbandonedOutcome &&
        !_abandonedEmitted) {
      _abandonedEmitted = true;
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: ShapeMatchingEventType.activityAbandoned,
        payload: const {'completion_status': 'abandoned'},
      );
    }
    // Kids Mode / activity exit — stop + dispose BGM and SFX.
    await _audio.dispose();
    await _drainProduction();
    final game = _game;
    if (game != null) {
      await unmountFlameLayer(game);
    }
  }

  @override
  Future<void> disposeResources() async {
    await _audio.dispose();
    final game = _game;
    if (game != null) {
      await unmountFlameLayer(game);
    }
    _game = null;
  }

  /// Choice tap affordance SFX (non-blocking).
  void notifyChoiceTap() {
    // ignore: discarded_futures
    _audio.playTap();
  }

  /// Drag-start bounce SFX (non-blocking).
  void notifyChoiceDragStart() {
    // ignore: discarded_futures
    _audio.playDragBounce();
  }

  void setInteractionsEnabled(bool enabled) {
    if (_interactionsEnabled == enabled) return;
    _interactionsEnabled = enabled;
    _notify();
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
    _round = ShapeMatchingLogic.buildRound(
      playSessionId: playSessionId,
      roundIndex: _roundIndex,
      band: band,
    );
    _wrongAttemptsThisRound = 0;
    _hintLevel = 0;
  }

  void _emitStartedIfNeeded({bool restart = false}) {
    if (_startedEmitted) return;
    _startedEmitted = true;
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: ShapeMatchingEventType.activityStarted,
      payload: {
        'activity_variant_id': ShapeMatchingConstants.activityId,
        'age_months': _ageMonths,
        'choice_count': _band?.choiceCount,
        if (restart) 'restart': true,
      },
    );
  }

  Future<void> _drainProduction() async {
    if (eventBuffer is ShapeMatchingProductionEventBuffer) {
      await (eventBuffer as ShapeMatchingProductionEventBuffer).drain();
    }
  }

  void pickShape(ShapeToken token) {
    if (!_interactionsEnabled) return;
    final current = _round;
    if (current == null || _lastOutcome is ActivityCompletedOutcome) return;

    final correct = ShapeMatchingLogic.isCorrectChoice(current, token);
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: ShapeMatchingEventType.activityAttempted,
      payload: {
        'shape_id': token.name,
        'correct': correct,
        'round_index': _roundIndex,
      },
    );

    if (correct) {
      _correctMatchSerial++;
      _showCelebrationPulse = true;
      final willComplete =
          _roundIndex + 1 >= ShapeMatchingConstants.roundsPerSession;
      // Celebrate SFX is non-blocking — never delays round advance / completion.
      // ignore: discarded_futures
      _audio.playCorrectMatch(
        serial: _correctMatchSerial,
        isCompletion: willComplete,
      );
      _lastOutcome = const EncouragementOutcome(cueKey: 'shape_match');
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
      type: ShapeMatchingEventType.activityHintUsed,
      payload: {'hint_level': nextLevel},
    );
    _lastOutcome = HintOfferedOutcome(level: nextLevel);
    _notify();
  }

  void _advanceAfterCorrect() {
    _roundIndex++;
    if (_roundIndex >= ShapeMatchingConstants.roundsPerSession) {
      onOutcome(const ActivityCompletedOutcome());
      return;
    }
    _showCelebrationPulse = false;
    _loadRound();
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
        type: ShapeMatchingEventType.activityCompleted,
        payload: const {
          'completion_status': 'completed',
          'scoring': 'neutral',
        },
      );
    } else if (outcome is ActivityAbandonedOutcome) {
      if (_abandonedEmitted) return;
      _abandonedEmitted = true;
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: ShapeMatchingEventType.activityAbandoned,
        payload: const {'completion_status': 'abandoned'},
      );
    } else if (outcome is HintOfferedOutcome) {
      // Telemetry for hints is owned by [offerHint] only (idempotent per level).
    }
    _notify();
  }

  @override
  Map<String, Object?> capturePlayState() => {
        'round_index': _roundIndex,
        'hint_level': _hintLevel,
        'target': _round?.target.name,
        'choices': _round?.choices.map((c) => c.name).toList(),
        'wrong_attempts': _wrongAttemptsThisRound,
        'celebration': _showCelebrationPulse,
      };

  @override
  Future<void> restorePlayState(Map<String, Object?> state) async {
    _roundIndex = state['round_index'] as int? ?? _roundIndex;
    _hintLevel = state['hint_level'] as int? ?? _hintLevel;
    _wrongAttemptsThisRound =
        state['wrong_attempts'] as int? ?? _wrongAttemptsThisRound;
    _showCelebrationPulse =
        state['celebration'] as bool? ?? _showCelebrationPulse;
    final targetName = state['target'] as String?;
    final choiceNames = state['choices'];
    if (targetName != null && choiceNames is List) {
      _round = ShapeMatchingRound(
        roundIndex: _roundIndex,
        target: ShapeToken.values.firstWhere((s) => s.name == targetName),
        choices: choiceNames
            .whereType<String>()
            .map(
              (name) => ShapeToken.values.firstWhere((s) => s.name == name),
            )
            .toList(growable: false),
      );
    } else {
      _loadRound();
    }
    _notify();
  }
}

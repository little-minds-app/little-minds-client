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
        _audio = audio ?? ShapeMatchingAudio(),
        playSessionId = playSessionId ??
            (sessionIdFactory?.call() ??
                'session-${DateTime.now().toUtc().microsecondsSinceEpoch}');

  final int? Function() ageMonthsProvider;
  final ShapeMatchingLocalEventBuffer eventBuffer;
  final ShapeMatchingAudio _audio;
  final String localeTag;
  final bool soundOff;
  final String playSessionId;

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
  ScoringNeutralOutcome? _lastOutcome;
  final _listeners = <VoidCallback>[];

  bool get interactionsEnabled => _interactionsEnabled;
  bool get showCelebrationPulse => _showCelebrationPulse;
  int get ageMonths => _ageMonths;
  ShapeMatchingBand? get band => _band;
  int get roundIndex => _roundIndex;
  ShapeMatchingRound? get round => _round;
  ScoringNeutralOutcome? get lastOutcome => _lastOutcome;
  int get hintLevel => _hintLevel;
  bool get audioAssetsPresent => _audio.assetsPresent;
  bool get audioReady => _audio.ready;

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
    final game = _game;
    if (game != null) {
      await mountFlameLayer(game);
    }
  }

  @override
  Future<void> onPause() async {
    setInteractionsEnabled(false);
    await _drainProduction();
  }

  @override
  Future<void> onResume() async {
    if (_lastOutcome is! ActivityCompletedOutcome) {
      setInteractionsEnabled(true);
    }
  }

  @override
  Future<void> onBackground() async {
    setInteractionsEnabled(false);
    await _drainProduction();
  }

  @override
  Future<void> onForeground() async {}

  @override
  Future<void> onRestart() async {
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
    await _drainProduction();
    final game = _game;
    if (game != null) {
      await unmountFlameLayer(game);
    }
  }

  @override
  Future<void> disposeResources() async {
    final game = _game;
    if (game != null) {
      await unmountFlameLayer(game);
    }
    _game = null;
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
      _showCelebrationPulse = true;
      // ignore: discarded_futures
      _audio.playCorrect();
      _lastOutcome = const EncouragementOutcome(cueKey: 'shape_match');
      _notify();
      _advanceAfterCorrect();
      return;
    }

    _wrongAttemptsThisRound++;
    _lastOutcome = const EncouragementOutcome(cueKey: 'try_again');
    if (_wrongAttemptsThisRound >= 2) {
      offerHint();
    }
    _notify();
  }

  void offerHint() {
    if (_hintLevel >= 2) return;
    _hintLevel++;
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: ShapeMatchingEventType.activityHintUsed,
      payload: {'hint_level': _hintLevel},
    );
    _lastOutcome = HintOfferedOutcome(level: _hintLevel);
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
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: ShapeMatchingEventType.activityHintUsed,
        payload: {'hint_level': outcome.level},
      );
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

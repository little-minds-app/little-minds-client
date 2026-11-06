import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../game/learning_activity.dart';
import '../game/scoring_neutral_outcome.dart';
import 'color_sorting_audio.dart';
import 'color_sorting_constants.dart';
import 'color_sorting_events.dart';
import 'color_sorting_flame_layer.dart';
import 'color_sorting_logic.dart';
import 'color_sorting_production_event_buffer.dart';

/// Developer-owned Color Sorting hub activity (LMP-56 / ADR-015).
class ColorSortingActivity extends LearningActivity {
  ColorSortingActivity({
    required this.ageMonthsProvider,
    ColorSortingLocalEventBuffer? eventBuffer,
    ColorSortingAudio? audio,
    this.localeTag = 'en-US',
    this.soundOff = false,
    String? playSessionId,
    String Function()? sessionIdFactory,
  })  : eventBuffer = eventBuffer ?? ColorSortingLocalEventBuffer(),
        _audio = audio ?? ColorSortingAudio(soundOff: soundOff),
        playSessionId = playSessionId ??
            (sessionIdFactory?.call() ??
                'session-${DateTime.now().toUtc().microsecondsSinceEpoch}');

  final int? Function() ageMonthsProvider;
  final ColorSortingLocalEventBuffer eventBuffer;
  final ColorSortingAudio _audio;
  final String localeTag;
  final bool soundOff;
  final String playSessionId;

  /// Exposed for play-field tap/drag SFX and tests — single shared audio system.
  ColorSortingAudio get audio => _audio;

  FlameGame? _game;
  var _ageMonths = -1;
  ColorSortingBand? _band;
  var _roundIndex = 0;
  ColorSortingRound? _round;
  var _interactionsEnabled = true;
  var _startedEmitted = false;
  var _abandonedEmitted = false;
  var _hintLevel = 0;
  var _wrongAttemptsThisRound = 0;
  var _showCelebrationPulse = false;
  /// UI-only monotonic success id — one tick per correct sort (not telemetry).
  var _correctSortSerial = 0;
  ScoringNeutralOutcome? _lastOutcome;
  final _listeners = <VoidCallback>[];

  bool get interactionsEnabled => _interactionsEnabled;
  bool get showCelebrationPulse => _showCelebrationPulse;
  int get correctSortSerial => _correctSortSerial;
  int get ageMonths => _ageMonths;
  ColorSortingBand? get band => _band;
  int get roundIndex => _roundIndex;
  ColorSortingRound? get round => _round;
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
  String get id => ColorSortingConstants.activityId;

  @override
  String get displayName => 'Color Sorting';

  @override
  bool get isPlayable {
    final age = ageMonthsProvider();
    if (age == null) {
      return false;
    }
    return ColorSortingBand.forAgeMonths(age) != null;
  }

  @override
  Future<void> prepare() async {
    final age = ageMonthsProvider();
    if (age == null) {
      throw StateError(
        'Color Sorting requires a selected child profile with age.',
      );
    }
    final band = ColorSortingBand.forAgeMonths(age);
    if (band == null) {
      throw StateError(
        'Color Sorting age $age is outside supported bands '
        '${ColorSortingConstants.productAgeMinMonths}–'
        '${ColorSortingConstants.productAgeMaxMonths} months.',
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
    await _audio.ensureBgmPlaying();
    final game = _game;
    if (game != null) {
      await mountFlameLayer(game);
    }
  }

  @override
  Future<void> onPause() async {
    setInteractionsEnabled(false);
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
        type: ColorSortingEventType.activityAbandoned,
        payload: const {'completion_status': 'abandoned'},
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
    await _audio.dispose();
    final game = _game;
    if (game != null) {
      await unmountFlameLayer(game);
    }
    _game = null;
  }

  void notifyObjectTap() {
    // ignore: discarded_futures
    _audio.playTap();
  }

  void notifyObjectDragStart() {
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
    _correctSortSerial = 0;
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
    _round = ColorSortingLogic.buildRound(
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
      type: ColorSortingEventType.activityStarted,
      payload: {
        'activity_variant_id': ColorSortingConstants.activityId,
        'age_months': _ageMonths,
        'bin_count': _band?.binCount,
        if (restart) 'restart': true,
      },
    );
  }

  Future<void> _drainProduction() async {
    if (eventBuffer is ColorSortingProductionEventBuffer) {
      await (eventBuffer as ColorSortingProductionEventBuffer).drain();
    }
  }

  /// Sort the current object into [bin] (tap-on-bin or drag-to-bin).
  void sortIntoBin(ColorToken bin) {
    if (!_interactionsEnabled) return;
    final current = _round;
    if (current == null || _lastOutcome is ActivityCompletedOutcome) return;

    final correct = ColorSortingLogic.isCorrectBin(current, bin);
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: ColorSortingEventType.activityAttempted,
      payload: {
        'color_id': current.objectColor.name,
        'bin_id': bin.name,
        'correct': correct,
        'round_index': _roundIndex,
      },
    );

    if (correct) {
      _correctSortSerial++;
      _showCelebrationPulse = true;
      final willComplete =
          _roundIndex + 1 >= ColorSortingConstants.roundsPerSession;
      // ignore: discarded_futures
      _audio.playCorrectMatch(
        serial: _correctSortSerial,
        isCompletion: willComplete,
      );
      _lastOutcome = const EncouragementOutcome(cueKey: 'color_sort');
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
      type: ColorSortingEventType.activityHintUsed,
      payload: {'hint_level': nextLevel},
    );
    _lastOutcome = HintOfferedOutcome(level: nextLevel);
    _notify();
  }

  void _advanceAfterCorrect() {
    _roundIndex++;
    if (_roundIndex >= ColorSortingConstants.roundsPerSession) {
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
        type: ColorSortingEventType.activityCompleted,
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
        type: ColorSortingEventType.activityAbandoned,
        payload: const {'completion_status': 'abandoned'},
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
        'object_color': _round?.objectColor.name,
        'object_form': _round?.objectForm.name,
        'bins': _round?.bins.map((c) => c.name).toList(),
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
    final colorName = state['object_color'] as String?;
    final formName = state['object_form'] as String?;
    final binNames = state['bins'];
    if (colorName != null && formName != null && binNames is List) {
      _round = ColorSortingRound(
        roundIndex: _roundIndex,
        objectColor:
            ColorToken.values.firstWhere((c) => c.name == colorName),
        objectForm:
            SortObjectForm.values.firstWhere((f) => f.name == formName),
        bins: binNames
            .whereType<String>()
            .map(
              (name) => ColorToken.values.firstWhere((c) => c.name == name),
            )
            .toList(growable: false),
      );
    } else {
      _loadRound();
    }
    _notify();
  }
}

import 'dart:ui' show Offset;

import '../game/learning_activity.dart';
import '../game/scoring_neutral_outcome.dart';
import 'near_far_constants.dart';
import 'near_far_events.dart';
import 'near_far_mentor_metadata.dart';
import 'near_far_mission_handoff.dart';
import 'near_far_relation.dart';
import 'near_far_spoken_labels.dart';

/// Prompted step inside the calm 1–2 minute digital invitation.
enum NearFarPromptStep {
  makeNear,
  makeFar,
  complete,
}

/// Developer-owned 32-month Near/Far [LearningActivity] (LMP-45 / ADR-015).
///
/// Launched only via the dedicated Kids Mode demo route — **not** registered
/// in the six-game [ActivityRegistry] / Hub catalog.
class NearFarActivity extends LearningActivity {
  NearFarActivity({
    NearFarLocalEventBuffer? eventBuffer,
    NearFarMissionHandoffController? missionHandoff,
    NearFarSpokenLabels? spokenLabels,
    this.ageMonths = NearFarConstants.focusAgeMonths,
    this.localeTag = 'en-US',
    this.soundOff = false,
    String? playSessionId,
    String Function()? sessionIdFactory,
  })  : eventBuffer = eventBuffer ?? NearFarLocalEventBuffer(),
        missionHandoff = missionHandoff ?? NearFarMissionHandoffController(),
        spokenLabels = spokenLabels ?? NearFarSpokenLabels(),
        playSessionId = playSessionId ??
            (sessionIdFactory?.call() ??
                'session-${DateTime.now().toUtc().microsecondsSinceEpoch}');

  final NearFarLocalEventBuffer eventBuffer;
  final NearFarMissionHandoffController missionHandoff;
  final NearFarSpokenLabels spokenLabels;
  final int ageMonths;
  final String localeTag;
  final bool soundOff;
  final String playSessionId;

  /// Mentor adjacency metadata (parent UI lives in LMP-48 mentor surfaces).
  final NearFarMentorAdjacency mentorAdjacency = const NearFarMentorAdjacency();

  var _prompt = NearFarPromptStep.makeNear;
  var _achievedNear = false;
  var _achievedFar = false;
  var _spokenAssetsPresent = false;
  var _spokenLabelsReady = false;
  var _startedEmitted = false;
  var _abandonedEmitted = false;
  var _missionOpenedEmitted = false;
  var _missionFeedbackEmitted = false;
  var _interactionsEnabled = true;
  NearFarRelation? _lastEmittedRelation;
  Offset _sock = NearFarRelationLogic.initialFarPositions().sock;
  Offset _softToy = NearFarRelationLogic.initialFarPositions().softToy;
  ScoringNeutralOutcome? _lastOutcome;
  final _listeners = <void Function()>[];

  NearFarPromptStep get prompt => _prompt;
  bool get achievedNear => _achievedNear;
  bool get achievedFar => _achievedFar;

  /// Licensed WAV **files** present in the bundle (not spoken AC).
  bool get spokenAssetsPresent => _spokenAssetsPresent;

  /// Spoken-label readiness: assets present **and** capable offline player.
  ///
  /// Default [UnavailableNearFarLabelPlayer] always keeps this false.
  bool get spokenLabelsReady => _spokenLabelsReady;

  /// Back-compat alias — prefer [spokenLabelsReady] for AC / UI gating.
  @Deprecated('Use spokenLabelsReady — assets alone never satisfy spoken AC')
  bool get spokenAssetsReady => _spokenLabelsReady;

  bool get interactionsEnabled => _interactionsEnabled;
  Offset get sockPosition => _sock;
  Offset get softToyPosition => _softToy;
  ScoringNeutralOutcome? get lastOutcome => _lastOutcome;
  NearFarRelation get currentRelation => NearFarRelationLogic.classify(
        a: _sock,
        b: _softToy,
      );

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  /// Host gates drag while paused / backgrounded / completed / preparing.
  void setInteractionsEnabled(bool enabled) {
    if (_interactionsEnabled == enabled) {
      return;
    }
    _interactionsEnabled = enabled;
    _notify();
  }

  @override
  String get id => NearFarConstants.activityId;

  @override
  String get displayName => 'Near / Far';

  /// Playable on the dedicated demo route only — never via Hub catalog.
  @override
  bool get isPlayable => true;

  @override
  Future<void> prepare() async {
    if (!NearFarRelationLogic.isAgeEligible(ageMonths)) {
      throw StateError(
        'Near/Far demo requires age band '
        '${NearFarConstants.ageMinMonths}–${NearFarConstants.ageMaxMonths} months',
      );
    }
    // Offline gate: relation math + fixtures are local. Spoken WAV readiness
    // is probed but never fails prepare — spoken AC stays blocked until
    // licensed assets + a real offline player are integrated.
    _spokenAssetsPresent = await spokenLabels.areAssetsPresent(localeTag);
    _spokenLabelsReady = await spokenLabels.areSpokenLabelsReady(localeTag);
    _resetPlayProgress(emitStarted: false);
  }

  @override
  Future<void> onEnter() async {
    _emitStartedIfNeeded();
  }

  @override
  Future<void> onPause() async {
    setInteractionsEnabled(false);
  }

  @override
  Future<void> onResume() async {
    if (_prompt != NearFarPromptStep.complete &&
        _lastOutcome is! ActivityCompletedOutcome) {
      setInteractionsEnabled(true);
    }
  }

  @override
  Future<void> onBackground() async {
    setInteractionsEnabled(false);
  }

  @override
  Future<void> onForeground() async {
    // Resume path decides whether interactions re-enable after foreground.
  }

  @override
  Future<void> onRestart() async {
    // Full event-state reset so replay does not inherit stale flags.
    _resetPlayProgress(emitStarted: true);
    setInteractionsEnabled(true);
    _notify();
  }

  void _resetPlayProgress({required bool emitStarted}) {
    final initial = NearFarRelationLogic.initialFarPositions();
    _sock = initial.sock;
    _softToy = initial.softToy;
    _prompt = NearFarPromptStep.makeNear;
    _achievedNear = false;
    _achievedFar = false;
    _lastOutcome = null;
    _lastEmittedRelation = null;
    _startedEmitted = false;
    _abandonedEmitted = false;
    _missionOpenedEmitted = false;
    _missionFeedbackEmitted = false;
    missionHandoff.reset();
    if (emitStarted) {
      _emitStartedIfNeeded(restart: true);
    }
  }

  void _emitStartedIfNeeded({bool restart = false}) {
    if (_startedEmitted) {
      return;
    }
    _startedEmitted = true;
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: NearFarEventType.activityStarted,
      payload: {
        'activity_variant_id': NearFarConstants.activityId,
        'age_months': ageMonths,
        'spoken_assets_present': _spokenAssetsPresent,
        'spoken_labels_ready': _spokenLabelsReady,
        if (restart) 'restart': true,
      },
    );
  }

  @override
  Future<void> onExit() async {
    if (_lastOutcome is ActivityCompletedOutcome ||
        _lastOutcome is ActivityAbandonedOutcome ||
        _abandonedEmitted) {
      return;
    }
    _abandonedEmitted = true;
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: NearFarEventType.activityAbandoned,
      payload: const {'completion_status': 'abandoned'},
    );
  }

  @override
  Map<String, Object?> capturePlayState() => {
        'prompt': _prompt.name,
        'achieved_near': _achievedNear,
        'achieved_far': _achievedFar,
        'sock_x': _sock.dx,
        'sock_y': _sock.dy,
        'toy_x': _softToy.dx,
        'toy_y': _softToy.dy,
        // Coarse object centers for orientation restore only — never raw touch
        // streams / pointer paths (Blueprint §14).
      };

  @override
  Future<void> restorePlayState(Map<String, Object?> state) async {
    final promptName = state['prompt'] as String?;
    if (promptName != null) {
      _prompt = NearFarPromptStep.values.firstWhere(
        (p) => p.name == promptName,
        orElse: () => NearFarPromptStep.makeNear,
      );
    }
    _achievedNear = state['achieved_near'] as bool? ?? _achievedNear;
    _achievedFar = state['achieved_far'] as bool? ?? _achievedFar;
    final sockX = state['sock_x'];
    final sockY = state['sock_y'];
    final toyX = state['toy_x'];
    final toyY = state['toy_y'];
    if (sockX is num && sockY is num) {
      _sock = Offset(sockX.toDouble(), sockY.toDouble());
    }
    if (toyX is num && toyY is num) {
      _softToy = Offset(toyX.toDouble(), toyY.toDouble());
    }
    _notify();
  }

  @override
  void onOutcome(ScoringNeutralOutcome outcome) {
    // Idempotent — controller.reportOutcome may re-enter after local complete.
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
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: NearFarEventType.activityCompleted,
        payload: const {
          'completion_status': 'completed',
          'scoring': 'neutral',
        },
      );
      missionHandoff.offer();
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: NearFarEventType.realWorldMissionOffered,
        payload: {
          'mission_id': NearFarConstants.missionId,
          'mentor_card_id': mentorAdjacency.mentorCardId,
          'materials': const ['one sock', 'one soft toy'],
        },
      );
    } else if (outcome is ActivityAbandonedOutcome) {
      if (_abandonedEmitted) {
        return;
      }
      _abandonedEmitted = true;
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: NearFarEventType.activityAbandoned,
        payload: const {'completion_status': 'abandoned'},
      );
    } else if (outcome is HintOfferedOutcome) {
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: NearFarEventType.activityHintUsed,
        payload: {'hint_level': outcome.level},
      );
    }
    _notify();
  }

  void moveSock(Offset designPosition) {
    if (!_interactionsEnabled) {
      return;
    }
    _sock = designPosition;
    _onPositionsChanged();
  }

  void moveSoftToy(Offset designPosition) {
    if (!_interactionsEnabled) {
      return;
    }
    _softToy = designPosition;
    _onPositionsChanged();
  }

  void _onPositionsChanged() {
    if (!_interactionsEnabled || _prompt == NearFarPromptStep.complete) {
      return;
    }
    final relation = currentRelation;
    // Emit coarse relation changes only — never raw pointer streams (§14).
    if (relation != _lastEmittedRelation &&
        relation != NearFarRelation.neither) {
      _lastEmittedRelation = relation;
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: NearFarEventType.activityAttempted,
        payload: {
          'relation': relation.name,
          'prompt': _prompt.name,
        },
      );
    }

    if (_prompt == NearFarPromptStep.makeNear &&
        relation == NearFarRelation.near) {
      _achievedNear = true;
      // ignore: discarded_futures
      _speak(NearFarSpokenStem.near);
      _lastOutcome = const EncouragementOutcome(cueKey: 'near');
      _prompt = NearFarPromptStep.makeFar;
      _lastEmittedRelation = null;
    } else if (_prompt == NearFarPromptStep.makeFar &&
        relation == NearFarRelation.far) {
      _achievedFar = true;
      // ignore: discarded_futures
      _speak(NearFarSpokenStem.far);
      _prompt = NearFarPromptStep.complete;
      onOutcome(const ActivityCompletedOutcome());
      return;
    }
    _notify();
  }

  Future<bool> _speak(NearFarSpokenStem stem) {
    return spokenLabels.speak(
      stem,
      localeTag: localeTag,
      soundOff: soundOff,
    );
  }

  /// Starts the optional real-world mission guidance (Start / Try together).
  ///
  /// Emits [NearFarEventType.realWorldMissionOpened] once. Idempotent.
  NearFarMissionHandoff startMissionHandoff() {
    final before = missionHandoff.handoff.state;
    final opened = missionHandoff.start();
    if (before == NearFarMissionHandoffState.offered &&
        opened.state == NearFarMissionHandoffState.opened &&
        !_missionOpenedEmitted) {
      _missionOpenedEmitted = true;
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: NearFarEventType.realWorldMissionOpened,
        payload: {
          'mission_id': opened.missionId,
          // Parent mentor UI deferred to LMP-47/48 — metadata adjacency only.
          'mentor_adjacency': mentorAdjacency.toMetadataJson(),
        },
      );
      _notify();
    }
    return opened;
  }

  /// Alias for [startMissionHandoff] — LMP-45 call-site compatibility.
  NearFarMissionHandoff openMissionHandoff() => startMissionHandoff();

  /// Explicit skip — calm, optional, never penalized; no proof demanded.
  ///
  /// Emits local [NearFarEventType.missionFeedbackSubmitted] once with
  /// `status=skipped` / `source=caregiver_report` (Blueprint §5.2). Not
  /// production telemetry (LMP-50).
  NearFarMissionHandoff skipMissionHandoff() {
    final before = missionHandoff.handoff.state;
    final skipped = missionHandoff.skip();
    if ((before == NearFarMissionHandoffState.offered ||
            before == NearFarMissionHandoffState.opened) &&
        skipped.state == NearFarMissionHandoffState.skipped) {
      _emitMissionFeedbackOnce(status: 'skipped');
      _notify();
    }
    return skipped;
  }

  /// Optional calm "we're done" after starting guidance — never forced.
  NearFarMissionHandoff completeMissionOptionally() {
    final before = missionHandoff.handoff.state;
    final completed = missionHandoff.completeOptionally();
    if (before == NearFarMissionHandoffState.opened &&
        completed.state == NearFarMissionHandoffState.completed) {
      _emitMissionFeedbackOnce(status: 'tried_together');
      _notify();
    }
    return completed;
  }

  /// Calm dismiss / Back exit from any handoff surface.
  NearFarMissionHandoff dismissMissionHandoff() {
    final dismissed = missionHandoff.dismiss();
    _notify();
    return dismissed;
  }

  void _emitMissionFeedbackOnce({required String status}) {
    if (_missionFeedbackEmitted) {
      return;
    }
    _missionFeedbackEmitted = true;
    eventBuffer.emit(
      playSessionId: playSessionId,
      type: NearFarEventType.missionFeedbackSubmitted,
      payload: {
        'mission_id': NearFarConstants.missionId,
        'status': status,
        'source': 'caregiver_report',
        // Local offline fixture only — no photo / proof / permissions.
        'proof_required': false,
      },
    );
  }
}

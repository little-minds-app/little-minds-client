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

  /// Mentor adjacency metadata only — no parent UI (LMP-47/48).
  final NearFarMentorAdjacency mentorAdjacency = const NearFarMentorAdjacency();

  var _prompt = NearFarPromptStep.makeNear;
  var _achievedNear = false;
  var _achievedFar = false;
  var _spokenAssetsReady = false;
  var _startedEmitted = false;
  NearFarRelation? _lastEmittedRelation;
  Offset _sock = NearFarRelationLogic.initialFarPositions().sock;
  Offset _softToy = NearFarRelationLogic.initialFarPositions().softToy;
  ScoringNeutralOutcome? _lastOutcome;
  final _listeners = <void Function()>[];

  NearFarPromptStep get prompt => _prompt;
  bool get achievedNear => _achievedNear;
  bool get achievedFar => _achievedFar;
  bool get spokenAssetsReady => _spokenAssetsReady;
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
    // Offline gate: relation math + fixtures are local. Spoken WAV packs are
    // probed but missing packs do NOT fail prepare — they block spoken AC only.
    _spokenAssetsReady = await spokenLabels.areAssetsReady(localeTag);
    final initial = NearFarRelationLogic.initialFarPositions();
    _sock = initial.sock;
    _softToy = initial.softToy;
    _prompt = NearFarPromptStep.makeNear;
    _achievedNear = false;
    _achievedFar = false;
    missionHandoff.reset();
  }

  @override
  Future<void> onEnter() async {
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
        'spoken_assets_ready': _spokenAssetsReady,
      },
    );
  }

  @override
  Future<void> onRestart() async {
    final initial = NearFarRelationLogic.initialFarPositions();
    _sock = initial.sock;
    _softToy = initial.softToy;
    _prompt = NearFarPromptStep.makeNear;
    _achievedNear = false;
    _achievedFar = false;
    _lastOutcome = null;
    missionHandoff.reset();
    _notify();
  }

  @override
  Future<void> onExit() async {
    if (_lastOutcome is! ActivityCompletedOutcome &&
        _lastOutcome is! ActivityAbandonedOutcome) {
      eventBuffer.emit(
        playSessionId: playSessionId,
        type: NearFarEventType.activityAbandoned,
        payload: const {'completion_status': 'abandoned'},
      );
    }
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
    _sock = designPosition;
    _onPositionsChanged();
  }

  void moveSoftToy(Offset designPosition) {
    _softToy = designPosition;
    _onPositionsChanged();
  }

  void _onPositionsChanged() {
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

  /// Caregiver opens the safe handoff invitation (no skip/feedback UI).
  NearFarMissionHandoff openMissionHandoff() {
    final opened = missionHandoff.open();
    if (opened.state == NearFarMissionHandoffState.opened) {
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
}

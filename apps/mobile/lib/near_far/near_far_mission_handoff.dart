import 'near_far_constants.dart';

/// Optional real-world mission handoff lifecycle (LMP-46 / F-008 / LM-005).
///
/// Digital play → calm invitation → optional Start/Try → Skip or calm done →
/// Back/exit. Never requires photos, proof, permissions, timers, or scoring.
/// Parent mentor UI / caregiver reflection dashboards remain LMP-47/48.
enum NearFarMissionHandoffState {
  /// Digital play still in progress — handoff not yet available.
  unavailable,

  /// Calm real-world invitation is available after digital play.
  offered,

  /// Caregiver/child started the optional off-screen mission guidance.
  opened,

  /// Optional calm acknowledgment after exploring together (no proof).
  completed,

  /// Explicit skip — never penalized.
  skipped,

  /// Child / caregiver returned without starting, or exited after terminal state.
  dismissed,
}

/// Immutable safe handoff payload — materials + safety, no proof/photo.
class NearFarMissionHandoff {
  const NearFarMissionHandoff({
    this.missionId = NearFarConstants.missionId,
    this.state = NearFarMissionHandoffState.unavailable,
    this.materials = const ['one sock', 'one soft toy'],
    this.safetyNotes = const [
      'adult supervision',
      'no glass or choking hazards',
      'no cords, sharp, or hot items',
    ],
    this.linkedActivityId = NearFarConstants.activityId,
  });

  final String missionId;
  final NearFarMissionHandoffState state;
  final List<String> materials;
  final List<String> safetyNotes;
  final String linkedActivityId;

  /// Invitation or in-progress guidance is on screen.
  bool get isAvailable =>
      state == NearFarMissionHandoffState.offered ||
      state == NearFarMissionHandoffState.opened;

  /// Terminal calm states that still show an exit surface until dismiss.
  bool get isTerminalCalm =>
      state == NearFarMissionHandoffState.completed ||
      state == NearFarMissionHandoffState.skipped;

  /// Panel should remain visible (including calm done/skip until Back/dismiss).
  bool get showsPanel => isAvailable || isTerminalCalm;

  NearFarMissionHandoff copyWith({NearFarMissionHandoffState? state}) {
    return NearFarMissionHandoff(
      missionId: missionId,
      state: state ?? this.state,
      materials: materials,
      safetyNotes: safetyNotes,
      linkedActivityId: linkedActivityId,
    );
  }
}

/// Offers / starts / skips / completes / dismisses the optional mission.
///
/// All transitions are idempotent and never force completion.
class NearFarMissionHandoffController {
  NearFarMissionHandoff _handoff = const NearFarMissionHandoff();

  NearFarMissionHandoff get handoff => _handoff;

  /// Marks the calm invitation available after digital completion.
  NearFarMissionHandoff offer() {
    if (_handoff.state != NearFarMissionHandoffState.unavailable &&
        _handoff.state != NearFarMissionHandoffState.dismissed) {
      return _handoff;
    }
    _handoff = _handoff.copyWith(state: NearFarMissionHandoffState.offered);
    return _handoff;
  }

  /// Starts optional off-screen guidance (Start / Try together).
  ///
  /// Idempotent: only [NearFarMissionHandoffState.offered] → opened.
  NearFarMissionHandoff start() {
    if (_handoff.state != NearFarMissionHandoffState.offered) {
      return _handoff;
    }
    _handoff = _handoff.copyWith(state: NearFarMissionHandoffState.opened);
    return _handoff;
  }

  /// Alias for [start] — keeps LMP-45 call sites working.
  NearFarMissionHandoff open() => start();

  /// Explicit skip from invitation or active guidance — never penalized.
  ///
  /// Idempotent once already [skipped] / [completed] / [dismissed].
  NearFarMissionHandoff skip() {
    final state = _handoff.state;
    if (state == NearFarMissionHandoffState.skipped ||
        state == NearFarMissionHandoffState.completed ||
        state == NearFarMissionHandoffState.dismissed ||
        state == NearFarMissionHandoffState.unavailable) {
      return _handoff;
    }
    if (state != NearFarMissionHandoffState.offered &&
        state != NearFarMissionHandoffState.opened) {
      return _handoff;
    }
    _handoff = _handoff.copyWith(state: NearFarMissionHandoffState.skipped);
    return _handoff;
  }

  /// Optional calm "we're done" — no proof, timer, or score required.
  ///
  /// Only from [opened]; never forced.
  NearFarMissionHandoff completeOptionally() {
    if (_handoff.state != NearFarMissionHandoffState.opened) {
      return _handoff;
    }
    _handoff = _handoff.copyWith(state: NearFarMissionHandoffState.completed);
    return _handoff;
  }

  NearFarMissionHandoff dismiss() {
    _handoff = _handoff.copyWith(state: NearFarMissionHandoffState.dismissed);
    return _handoff;
  }

  void reset() {
    _handoff = const NearFarMissionHandoff();
  }
}

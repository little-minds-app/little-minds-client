import 'near_far_constants.dart';

/// Safe mission handoff contract for LMP-45 (F-008 adjacency).
///
/// Full skip / reflection / feedback UX is **LMP-46** — do not expand here.
enum NearFarMissionHandoffState {
  /// Digital play still in progress — handoff not yet available.
  unavailable,

  /// Calm real-world invitation is available after digital play.
  offered,

  /// Caregiver opened the handoff surface (still no skip/feedback UI).
  opened,

  /// Child / caregiver returned without starting the off-screen mission.
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

  bool get isAvailable =>
      state == NearFarMissionHandoffState.offered ||
      state == NearFarMissionHandoffState.opened;

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

/// Offers / opens / dismisses the safe handoff without LMP-46 skip flow.
class NearFarMissionHandoffController {
  NearFarMissionHandoff _handoff = const NearFarMissionHandoff();

  NearFarMissionHandoff get handoff => _handoff;

  /// Marks the calm invitation available after digital completion.
  NearFarMissionHandoff offer() {
    _handoff = _handoff.copyWith(state: NearFarMissionHandoffState.offered);
    return _handoff;
  }

  /// Caregiver opened the invitation (event stub only — no skip UI).
  ///
  /// Idempotent: only [NearFarMissionHandoffState.offered] → opened.
  NearFarMissionHandoff open() {
    if (_handoff.state != NearFarMissionHandoffState.offered) {
      return _handoff;
    }
    _handoff = _handoff.copyWith(state: NearFarMissionHandoffState.opened);
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

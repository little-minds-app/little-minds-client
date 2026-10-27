import 'near_far_constants.dart';

/// F-009 mentor **adjacency / metadata** only (LMP-45).
///
/// Parent-visible mentor card UI and schema landing = LMP-47 / LMP-48.
class NearFarMentorAdjacency {
  const NearFarMentorAdjacency({
    this.mentorCardId = NearFarConstants.mentorCardId,
    this.linkedActivityId = NearFarConstants.activityId,
    this.linkedMissionId = NearFarConstants.missionId,
    this.beforeCopyKey = 'mentor.near_far.before',
    this.duringCopyKeys = const [
      'mentor.near_far.during.closer',
      'mentor.near_far.during.what_changed',
      'mentor.near_far.during.farther',
    ],
    this.afterCopyKey = 'mentor.near_far.after',
    this.prohibitedClaims = const [
      'diagnosis',
      'IQ',
      'normative milestone pass/fail',
    ],
  });

  final String mentorCardId;
  final String linkedActivityId;
  final String linkedMissionId;
  final String beforeCopyKey;
  final List<String> duringCopyKeys;
  final String afterCopyKey;
  final List<String> prohibitedClaims;

  Map<String, Object?> toMetadataJson() => {
        'mentor_card_id': mentorCardId,
        'linked_activity_id': linkedActivityId,
        'linked_mission_id': linkedMissionId,
        'before_copy_key': beforeCopyKey,
        'during_copy_keys': duringCopyKeys,
        'after_copy_key': afterCopyKey,
        'prohibited_claims': prohibitedClaims,
        // Explicitly not a parent UI surface in LMP-45.
        'parent_ui': false,
      };
}

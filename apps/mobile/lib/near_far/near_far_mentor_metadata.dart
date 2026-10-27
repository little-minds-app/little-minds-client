import '../mentor/mentor_card.dart';
import '../mentor/mentor_card_pin.dart';
import 'near_far_constants.dart';

/// F-009 mentor **adjacency / metadata** (LMP-45) + thin LMP-47 card pin link.
///
/// Parent-visible mentor card UI remains **LMP-48** (`parent_ui: false`).
class NearFarMentorAdjacency {
  const NearFarMentorAdjacency({
    this.mentorCardId = NearFarConstants.mentorCardId,
    this.linkedActivityId = NearFarConstants.activityId,
    this.linkedMissionId = NearFarConstants.missionId,
    this.schemaVersion = mentorCardSchemaVersion,
    this.backendContentPinSha = MentorCardContentPin.backendCommitSha,
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
  final String schemaVersion;
  final String backendContentPinSha;
  final String beforeCopyKey;
  final List<String> duringCopyKeys;
  final String afterCopyKey;
  final List<String> prohibitedClaims;

  Map<String, Object?> toMetadataJson() => {
        'mentor_card_id': mentorCardId,
        'schema_version': schemaVersion,
        'backend_content_pin_sha': backendContentPinSha,
        'linked_activity_id': linkedActivityId,
        'linked_mission_id': linkedMissionId,
        'fixture_en_us': MentorCardContentPin.nearFarEnUsFixture,
        'fixture_tr_tr': MentorCardContentPin.nearFarTrTrFixture,
        'before_copy_key': beforeCopyKey,
        'during_copy_keys': duringCopyKeys,
        'after_copy_key': afterCopyKey,
        'prohibited_claims': prohibitedClaims,
        // Explicitly not a parent UI surface (LMP-48).
        'parent_ui': false,
      };
}

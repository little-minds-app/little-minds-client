import '../near_far/near_far_constants.dart';
import 'mentor_card.dart';

/// Resolves mentor-card content links to Near/Far runtime/event ids (LMP-47).
///
/// Canonical ids per `internal/lmp-47-mission-id-decision.md` /
/// `content/mentor-card/MISSION_ID_MAPPING.md`.
abstract final class MentorCardNearFarLinks {
  /// Deprecated backend draft mission id (@ dac60c57).
  static const String legacyContentMissionId = 'near_far_sock_soft_toy';

  /// Deprecated catalog activity stem (@ dac60c57).
  static const String legacyContentActivityStem = 'near_far';

  /// Deprecated mentor card id (@ dac60c57).
  static const String legacyMentorCardId = 'near_far_play_mentor';

  /// Returns [NearFarConstants.missionId] when the card links the Near/Far
  /// mission (exact or legacy content id); otherwise `null`.
  static String? resolveMissionId(MentorCardV1 card) {
    final ids = card.linkedMissionIds;
    if (ids.contains(NearFarConstants.missionId)) {
      return NearFarConstants.missionId;
    }
    if (ids.contains(legacyContentMissionId)) {
      return NearFarConstants.missionId;
    }
    return null;
  }

  /// Returns [NearFarConstants.activityId] when the card links Near/Far
  /// activity (exact or legacy stem); otherwise `null`.
  static String? resolveActivityId(MentorCardV1 card) {
    final ids = card.linkedActivityIds;
    if (ids.contains(NearFarConstants.activityId)) {
      return NearFarConstants.activityId;
    }
    if (ids.contains(legacyContentActivityStem)) {
      return NearFarConstants.activityId;
    }
    return null;
  }

  /// Canonical or legacy mentor card id for the Near/Far example.
  static bool isNearFarMentorCardId(String mentorCardId) {
    return mentorCardId == NearFarConstants.mentorCardId ||
        mentorCardId == nearFarMentorCardId ||
        mentorCardId == legacyMentorCardId;
  }

  /// True when this card is the Near/Far Slice B mentor example.
  static bool isNearFarMentorCard(MentorCardV1 card) {
    return isNearFarMentorCardId(card.mentorCardId) &&
        resolveMissionId(card) == NearFarConstants.missionId &&
        resolveActivityId(card) == NearFarConstants.activityId;
  }
}

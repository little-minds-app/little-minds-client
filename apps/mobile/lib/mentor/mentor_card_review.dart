import 'mentor_card.dart';

/// Caregiver-facing publication gate helpers (no LMP-48 UI).
///
/// Fixtures ship as `draft`. Draft is **not** approved for parent surfaces.
abstract final class MentorCardReviewGate {
  /// Statuses that may be shown as reviewed caregiver guidance later (LMP-48).
  static const Set<String> caregiverReadyStatuses = {
    'approved',
    'staged',
    'published',
  };

  static bool isDraft(MentorCardV1 card) => card.reviewStatus == 'draft';

  static bool isApprovedOrLater(MentorCardV1 card) =>
      caregiverReadyStatuses.contains(card.reviewStatus);

  /// Offline Slice B may load draft fixtures for schema tests only.
  /// Parent mentor UI must not treat draft as approved content.
  static bool mayRenderOnParentMentorSurface(MentorCardV1 card) =>
      isApprovedOrLater(card);
}

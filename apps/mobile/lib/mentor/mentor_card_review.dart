import 'mentor_card.dart';

/// Caregiver-facing publication gate helpers for Parent Mentor UI (LMP-48).
///
/// Fixtures ship as `draft`. Draft is **not** approved for parent surfaces.
abstract final class MentorCardReviewGate {
  /// Statuses that may be shown as reviewed caregiver guidance (LMP-48).
  static const Set<String> caregiverReadyStatuses = {
    'approved',
    'staged',
    'published',
  };

  static bool isDraft(MentorCardV1 card) => card.reviewStatus == 'draft';

  static bool isApprovedOrLater(MentorCardV1 card) =>
      caregiverReadyStatuses.contains(card.reviewStatus);

  /// Parent mentor UI must not treat draft as approved content.
  /// Dev/test may pass `allowDraftPreview` on [MentorCardView] for explicit
  /// draft preview with a banner — never a silent bypass.
  static bool mayRenderOnParentMentorSurface(MentorCardV1 card) =>
      isApprovedOrLater(card);
}

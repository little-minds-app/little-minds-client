/// Stable identifiers and design constants for Shape Matching (LMP-55 / F-005).
abstract final class ShapeMatchingConstants {
  static const String activityId = 'shape_matching';

  /// Local fixture content version — not a production UUID (LMP-50).
  static const String contentVersionId = 'shape_matching_v1.fixture.1';

  static const int eventSchemaVersion = 1;

  static const int productAgeMinMonths = 24;
  static const int productAgeMaxMonths = 71;

  /// Rounds per calm session before scoring-neutral completion.
  static const int roundsPerSession = 3;

  /// Design canvas aligned with [HitboxScaler.designCanvas].
  static const double designObjectSize = 96;
  static const double designSlotSize = 112;
  static const double designTargetSize = 120;

  static const String mentorCardId = 'shape_matching_v1';
}

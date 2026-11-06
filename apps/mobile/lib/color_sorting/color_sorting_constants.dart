/// Stable identifiers and design constants for Color Sorting (LMP-56 / F-005).
abstract final class ColorSortingConstants {
  static const String activityId = 'color_sorting';

  /// Local fixture content version — not a production UUID (fail-closed sync).
  /// Never invent a server-bound RFC-4122 id here (LMP-50 / LMP-134).
  static const String contentVersionId = 'color_sorting_v1.fixture.1';

  static const int eventSchemaVersion = 1;

  static const int productAgeMinMonths = 24;
  static const int productAgeMaxMonths = 71;

  /// Rounds per calm session before scoring-neutral completion.
  static const int roundsPerSession = 3;

  /// Design canvas aligned with [HitboxScaler.designCanvas].
  static const double designObjectSize = 96;
  static const double designBinSize = 112;
  static const double designObjectDropSize = 120;

  static const String mentorCardId = 'color_sorting_v1';
}

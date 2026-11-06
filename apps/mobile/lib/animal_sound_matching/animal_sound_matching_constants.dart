/// Stable identifiers and design constants for Animal Sound Matching (LMP-57 / F-005).
abstract final class AnimalSoundMatchingConstants {
  static const String activityId = 'animal_sound_matching';

  /// Local fixture content version — not a production UUID (fail-closed sync).
  /// Never invent a server-bound RFC-4122 id here (LMP-50 / LMP-134).
  static const String contentVersionId = 'animal_sound_matching_v1.fixture.1';

  static const int eventSchemaVersion = 1;

  static const int productAgeMinMonths = 24;
  static const int productAgeMaxMonths = 71;

  /// Rounds per calm session before scoring-neutral completion.
  static const int roundsPerSession = 3;

  /// Design canvas aligned with [HitboxScaler.designCanvas].
  static const double designChoiceSize = 108;
  static const double designPromptSize = 120;

  static const String mentorCardId = 'animal_sound_matching_v1';
}

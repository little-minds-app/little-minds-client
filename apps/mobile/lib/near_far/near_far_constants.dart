/// Developer-owned Near/Far Slice B demo constants (LMP-45 / ADR-015).
///
/// Not a Hub catalog engine id — keep out of [HubCatalogActivityId].
abstract final class NearFarConstants {
  /// Offline demo activity / content variant id (local fixtures only).
  static const String activityId = 'near_far_32m_v1';

  static const String contentVersionId = 'near_far_32m_v1.fixture.1';

  /// Canonical 32-month focus; generation brief band is 30–35.
  static const int focusAgeMonths = 32;
  static const int ageMinMonths = 30;
  static const int ageMaxMonths = 35;

  /// Blueprint §14 / §38.4 local fixture schema version (not LMP-50 production).
  static const int eventSchemaVersion = 1;

  /// Design-space object size before [HitboxScaler] (≥44 logical after scale).
  static const double designObjectSize = 96;

  /// Normalized distance thresholds on the design canvas diagonal fraction.
  static const double nearMaxNormalizedDistance = 0.22;
  static const double farMinNormalizedDistance = 0.48;

  static const String missionId = 'near_far_sock_soft_toy_v1';

  /// Canonical mentor card id (LMP-45 adjacency + LMP-47 / LMP-48).
  static const String mentorCardId = 'mentor_near_far_32m_adjacency_v1';
}

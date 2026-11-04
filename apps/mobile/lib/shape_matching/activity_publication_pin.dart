/// Pin metadata for backend-owned activity publication fixtures (LMP-134).
abstract final class ActivityPublicationPin {
  /// Verified commit on backend `feature/lmp-134-production-telemetry` (PR #37).
  /// Update only when the backend publication fixture changes.
  static const String backendCommitSha =
      'fe4fd8dd36d43aa695a489080ea8e7a02ff04b14';

  static const String backendPullRequestUrl =
      'https://github.com/little-minds-app/little-minds-backend/pull/37';

  static const String schemaVersion = '1.0.0';

  static const String assetDirectory = 'assets/content/activity_publications';

  static const String shapeMatchingFixture = 'shape-matching.v1.json';

  static String fixtureAssetPath(String fileName) => '$assetDirectory/$fileName';
}

/// Pin metadata for the backend-owned mentor card content contract (LMP-47).
///
/// Update [backendCommitSha] after backend PR
/// https://github.com/little-minds-app/little-minds-backend/pull/11 merges.
abstract final class MentorCardContentPin {
  /// Backend commit that authored the mirrored schema + fixtures.
  /// Pending merge of backend PR #11 — replace with `main` merge SHA later.
  static const String backendCommitSha =
      'dac60c575342b7cb8c86f2603bfc219e51d45ed5';

  static const String backendPullRequestUrl =
      'https://github.com/little-minds-app/little-minds-backend/pull/11';

  static const String schemaVersion = '1.0.0';

  /// Flutter asset directory for Near/Far fixture JSON (mirrors backend fixtures).
  static const String assetDirectory = 'assets/content/mentor_cards';

  static String fixtureAssetPath(String fileName) =>
      '$assetDirectory/$fileName';

  static const String nearFarEnUsFixture = 'near-far.en-US.v1.json';
  static const String nearFarTrTrFixture = 'near-far.tr-TR.v1.json';
}

/// Pin metadata for the backend-owned mentor card content contract (LMP-47).
///
/// Update [backendCommitSha] only when the backend content contract changes
/// (backend PR https://github.com/little-minds-app/little-minds-backend/pull/11).
abstract final class MentorCardContentPin {
  /// Verified merge commit on backend `main` from PR #11.
  /// Do not invent SHAs — update only when backend content contract changes.
  static const String backendCommitSha =
      '8678e61a673e82a5823875d8af4fc1bf6d700ac9';

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

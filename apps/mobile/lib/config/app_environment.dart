/// Deployable client environments (Blueprint §26.2 / LMP-28).
///
/// Wire names are fixed for cross-repo consistency with the backend:
/// `development` | `staging` | `production`.
enum AppEnvironment {
  development,
  staging,
  production;

  /// Canonical lowercase name used in dart-defines and docs.
  String get wireName => name;

  /// Parse a wire name; throws [FormatException] on unknown values.
  static AppEnvironment parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in AppEnvironment.values) {
      if (value.wireName == normalized) {
        return value;
      }
    }
    throw FormatException(
      'Invalid LM_ENV "$raw". Expected one of: '
      '${AppEnvironment.values.map((e) => e.wireName).join(', ')}.',
    );
  }
}

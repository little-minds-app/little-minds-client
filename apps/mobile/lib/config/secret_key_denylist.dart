/// Patterns that must never appear as client build-time config keys.
///
/// Mobile ships **public** configuration only (env name + API base URL).
/// Backend private tokens, DB credentials, and service-role keys belong in
/// server secret stores — never in the Flutter binary (LMP-28 / Blueprint §26).
abstract final class SecretKeyDenylist {
  /// Case-insensitive substrings that mark a key as secret-like.
  static const List<String> forbiddenSubstrings = [
    'SECRET',
    'PASSWORD',
    'PASSWD',
    'PRIVATE',
    'TOKEN',
    'SERVICE_ROLE',
    'DATABASE',
    'DB_',
    'API_KEY',
    'ACCESS_KEY',
    'CREDENTIAL',
    'JWT_SECRET',
    'SUPABASE_SERVICE',
  ];

  /// Public allowlist for Flutter `--dart-define` keys.
  static const Set<String> publicAllowlist = {
    'LM_ENV',
    'LM_API_BASE_URL',
  };

  /// Returns true when [key] looks like a secret or is outside the allowlist
  /// when [enforceAllowlist] is true.
  static bool isForbidden(
    String key, {
    bool enforceAllowlist = true,
  }) {
    final upper = key.trim().toUpperCase();
    if (upper.isEmpty) {
      return true;
    }
    for (final fragment in forbiddenSubstrings) {
      if (upper.contains(fragment)) {
        return true;
      }
    }
    if (enforceAllowlist && !publicAllowlist.contains(key.trim())) {
      return true;
    }
    return false;
  }

  /// Throws [FormatException] if any key in [defines] is forbidden.
  static void assertNoSecrets(
    Map<String, String> defines, {
    bool enforceAllowlist = true,
  }) {
    for (final key in defines.keys) {
      if (isForbidden(key, enforceAllowlist: enforceAllowlist)) {
        throw FormatException(
          'Rejected client config key "$key". '
          'Only public defines ${publicAllowlist.join(', ')} are allowed; '
          'never embed secrets in the mobile binary.',
        );
      }
    }
  }
}

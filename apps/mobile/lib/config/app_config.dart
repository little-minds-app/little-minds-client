import 'app_environment.dart';
import 'secret_key_denylist.dart';

/// Public build-time client configuration (LMP-28).
///
/// Contains **only** environment name + API base URL. Never store service-role
/// keys, DB credentials, or backend private tokens here.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
  });

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  /// Blueprint §27 default for iOS Simulator → host NestJS.
  static const String developmentDefaultApiBaseUrl = 'http://localhost:3000';

  /// Android emulator loopback to host (document; pass via LM_API_BASE_URL).
  static const String androidEmulatorApiBaseUrl = 'http://10.0.2.2:3000';

  /// Safe local default used by tests and `flutter run` without defines.
  static final AppConfig developmentLocal = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: Uri.parse(developmentDefaultApiBaseUrl),
  );

  /// Resolve from explicit values and optional define map (for validation).
  ///
  /// When [apiBaseUrl] is null/empty:
  /// - [AppEnvironment.development] → [developmentDefaultApiBaseUrl]
  /// - staging / production → fail-fast ([FormatException])
  factory AppConfig.resolve({
    String? envName,
    String? apiBaseUrl,
    Map<String, String>? defines,
  }) {
    if (defines != null) {
      SecretKeyDenylist.assertNoSecrets(defines);
    }

    final environment = AppEnvironment.parse(
      envName ?? defines?['LM_ENV'] ?? AppEnvironment.development.wireName,
    );

    final rawUrl = (apiBaseUrl ?? defines?['LM_API_BASE_URL'] ?? '').trim();
    final resolvedUrl = rawUrl.isEmpty
        ? _defaultUrlFor(environment)
        : rawUrl;

    final uri = _parseApiBaseUrl(resolvedUrl, environment);
    return AppConfig(environment: environment, apiBaseUrl: uri);
  }

  /// Load from `--dart-define=LM_ENV=…` and `--dart-define=LM_API_BASE_URL=…`.
  ///
  /// Defaults to [developmentLocal] when both defines are omitted.
  factory AppConfig.fromEnvironment() {
    const envDefine = String.fromEnvironment('LM_ENV');
    const urlDefine = String.fromEnvironment('LM_API_BASE_URL');
    return AppConfig.resolve(
      envName: envDefine.isEmpty ? null : envDefine,
      apiBaseUrl: urlDefine.isEmpty ? null : urlDefine,
      defines: {
        if (envDefine.isNotEmpty) 'LM_ENV': envDefine,
        if (urlDefine.isNotEmpty) 'LM_API_BASE_URL': urlDefine,
      },
    );
  }

  String get environmentWireName => environment.wireName;

  /// Origin string without a trailing slash (suitable for API client base).
  String get apiBaseUrlString {
    final text = apiBaseUrl.toString();
    if (text.endsWith('/') && text != '${apiBaseUrl.scheme}://') {
      return text.substring(0, text.length - 1);
    }
    return text;
  }

  static String _defaultUrlFor(AppEnvironment environment) {
    switch (environment) {
      case AppEnvironment.development:
        return developmentDefaultApiBaseUrl;
      case AppEnvironment.staging:
      case AppEnvironment.production:
        throw const FormatException(
          'LM_API_BASE_URL is required for staging and production builds. '
          'Public API base URL must be supplied at build time; '
          'do not embed secrets.',
        );
    }
  }

  static Uri _parseApiBaseUrl(String raw, AppEnvironment environment) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException(
        'LM_API_BASE_URL must be an absolute http(s) URL with a host. Got: "$raw".',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException(
        'LM_API_BASE_URL scheme must be http or https. Got: "${uri.scheme}".',
      );
    }

    final host = uri.host.toLowerCase();
    final isLocalDevHost = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host.endsWith('.local');

    if (environment == AppEnvironment.development) {
      if (uri.scheme == 'http' && !isLocalDevHost) {
        throw FormatException(
          'development LM_API_BASE_URL may use http only for local hosts '
          '(localhost, 127.0.0.1, 10.0.2.2, *.local). Got: "$raw".',
        );
      }
      return uri;
    }

    // staging + production: HTTPS only; never cleartext.
    if (uri.scheme != 'https') {
      throw FormatException(
        '${environment.wireName} LM_API_BASE_URL must use https. Got: "$raw".',
      );
    }
    if (isLocalDevHost) {
      throw FormatException(
        '${environment.wireName} LM_API_BASE_URL must not target a local '
        'development host. Got: "$raw".',
      );
    }
    return uri;
  }
}

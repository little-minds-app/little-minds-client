import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/config/app_environment.dart';
import 'package:little_minds_mobile/config/secret_key_denylist.dart';

void main() {
  group('TC-ENV-001 valid environments', () {
    test('parses development / staging / production wire names', () {
      expect(AppEnvironment.parse('development'), AppEnvironment.development);
      expect(AppEnvironment.parse('STAGING'), AppEnvironment.staging);
      expect(AppEnvironment.parse(' production '), AppEnvironment.production);
    });

    test('resolves development with default API URL', () {
      final config = AppConfig.resolve(envName: 'development');
      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUrlString, AppConfig.developmentDefaultApiBaseUrl);
    });

    test('resolves staging with https API URL', () {
      final config = AppConfig.resolve(
        envName: 'staging',
        apiBaseUrl: 'https://api.staging.example.test',
      );
      expect(config.environment, AppEnvironment.staging);
      expect(config.apiBaseUrlString, 'https://api.staging.example.test');
    });

    test('resolves production with https API URL', () {
      final config = AppConfig.resolve(
        envName: 'production',
        apiBaseUrl: 'https://api.example.test/',
      );
      expect(config.environment, AppEnvironment.production);
      expect(config.apiBaseUrlString, 'https://api.example.test');
    });

    test('allows Android emulator loopback in development', () {
      final config = AppConfig.resolve(
        envName: 'development',
        apiBaseUrl: AppConfig.androidEmulatorApiBaseUrl,
      );
      expect(config.apiBaseUrl.host, '10.0.2.2');
    });
  });

  group('TC-ENV-002 invalid env name', () {
    test('rejects unknown LM_ENV', () {
      expect(
        () => AppConfig.resolve(envName: 'dev'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid LM_ENV'),
          ),
        ),
      );
    });

    test('rejects empty LM_ENV', () {
      expect(
        () => AppEnvironment.parse(''),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TC-ENV-003 missing API URL', () {
    test('staging without API URL fails safely', () {
      expect(
        () => AppConfig.resolve(envName: 'staging'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('LM_API_BASE_URL is required'),
          ),
        ),
      );
    });

    test('production without API URL fails safely', () {
      expect(
        () => AppConfig.resolve(envName: 'production', apiBaseUrl: '  '),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-absolute URL', () {
      expect(
        () => AppConfig.resolve(
          envName: 'development',
          apiBaseUrl: 'not-a-url',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TC-ENV-004 secret-like keys rejected', () {
    test('denylist detects secret substrings', () {
      expect(SecretKeyDenylist.isForbidden('LM_API_SECRET'), isTrue);
      expect(SecretKeyDenylist.isForbidden('DATABASE_URL'), isTrue);
      expect(SecretKeyDenylist.isForbidden('SERVICE_ROLE_KEY'), isTrue);
      expect(SecretKeyDenylist.isForbidden('AUTH_TOKEN'), isTrue);
      expect(SecretKeyDenylist.isForbidden('LM_ENV'), isFalse);
      expect(SecretKeyDenylist.isForbidden('LM_API_BASE_URL'), isFalse);
    });

    test('resolve rejects secret keys in defines map', () {
      expect(
        () => AppConfig.resolve(
          defines: {
            'LM_ENV': 'development',
            'DATABASE_PASSWORD': 'should-never-ship',
          },
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Rejected client config key'),
          ),
        ),
      );
    });

    test('resolve rejects non-allowlisted public-looking keys', () {
      expect(
        () => AppConfig.resolve(
          defines: {
            'LM_ENV': 'development',
            'LM_EXTRA_FLAG': 'x',
          },
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TC-ENV-005 https enforcement', () {
    test('staging rejects cleartext http', () {
      expect(
        () => AppConfig.resolve(
          envName: 'staging',
          apiBaseUrl: 'http://api.staging.example.test',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('must use https'),
          ),
        ),
      );
    });

    test('production rejects localhost', () {
      expect(
        () => AppConfig.resolve(
          envName: 'production',
          apiBaseUrl: 'https://localhost:3000',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('development rejects remote cleartext http', () {
      expect(
        () => AppConfig.resolve(
          envName: 'development',
          apiBaseUrl: 'http://api.example.test',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

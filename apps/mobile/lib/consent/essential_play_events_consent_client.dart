import 'package:little_minds_api/api.dart';

import '../auth/auth_session.dart';
import '../config/app_config.dart';
import 'essential_play_events_consent.dart';

/// Reads/writes parent-level `essential_play_events` consent via pinned [PrivacyApi].
abstract class EssentialPlayEventsConsentClient {
  Future<EssentialPlayEventsConsentStatus?> fetchStatus(AuthSession session);

  Future<EssentialPlayEventsConsentStatus?> grant({
    required AuthSession session,
    required String policyVersion,
    required String consentTextVersion,
  });

  Future<EssentialPlayEventsConsentStatus?> withdraw({
    required AuthSession session,
    required String policyVersion,
  });
}

/// Fail closed until the consent routes are reachable (tests / staging without API).
final class FailClosedEssentialPlayEventsConsentClient
    implements EssentialPlayEventsConsentClient {
  @override
  Future<EssentialPlayEventsConsentStatus?> fetchStatus(AuthSession session) async =>
      null;

  @override
  Future<EssentialPlayEventsConsentStatus?> grant({
    required AuthSession session,
    required String policyVersion,
    required String consentTextVersion,
  }) async =>
      null;

  @override
  Future<EssentialPlayEventsConsentStatus?> withdraw({
    required AuthSession session,
    required String policyVersion,
  }) async =>
      null;
}

final class OpenApiEssentialPlayEventsConsentClient
    implements EssentialPlayEventsConsentClient {
  OpenApiEssentialPlayEventsConsentClient(AppConfig config)
      : _privacy = PrivacyApi(
          ApiClient(
            basePath: config.apiBaseUrlString,
            authentication: HttpBearerAuth(),
          ),
        );

  OpenApiEssentialPlayEventsConsentClient.fromPrivacyApi(this._privacy);

  final PrivacyApi _privacy;

  HttpBearerAuth get _bearer {
    final auth = _privacy.apiClient.authentication;
    if (auth is HttpBearerAuth) {
      return auth;
    }
    throw StateError('PrivacyApi must use HttpBearerAuth');
  }

  void _authorize(AuthSession session) {
    _bearer.accessToken = session.accessToken;
  }

  static const _playScope = ConsentScope.essentialPlayEvents;

  @override
  Future<EssentialPlayEventsConsentStatus?> fetchStatus(
    AuthSession session,
  ) async {
    _authorize(session);
    try {
      final response = await _privacy.getEffectiveConsentScopes([_playScope]);
      final scopes = response?.scopes ?? const <EffectiveConsentScope>[];
      for (final row in scopes) {
        if (row.consentScope == _playScope) {
          return EssentialPlayEventsConsentStatus.fromEffectiveScope(row);
        }
      }
      return const EssentialPlayEventsConsentStatus(
        authorized: false,
        effectiveStatus: 'not_granted',
      );
    } on ApiException catch (error) {
      if (error.code == 404) return null;
      rethrow;
    }
  }

  @override
  Future<EssentialPlayEventsConsentStatus?> grant({
    required AuthSession session,
    required String policyVersion,
    required String consentTextVersion,
  }) async {
    _authorize(session);
    try {
      final response = await _privacy.grantConsentScope(
        ConsentScopeMutationRequest(
          consentScope: _playScope,
          policyVersion: policyVersion,
        ),
      );
      if (response == null) return null;
      return EssentialPlayEventsConsentStatus.fromMutation(response);
    } on ApiException catch (error) {
      if (error.code == 404) return null;
      rethrow;
    }
  }

  @override
  Future<EssentialPlayEventsConsentStatus?> withdraw({
    required AuthSession session,
    required String policyVersion,
  }) async {
    _authorize(session);
    try {
      final response = await _privacy.withdrawConsentScope(
        ConsentScopeMutationRequest(
          consentScope: _playScope,
          policyVersion: policyVersion,
        ),
      );
      if (response == null) return null;
      return EssentialPlayEventsConsentStatus.fromMutation(response);
    } on ApiException catch (error) {
      if (error.code == 404) return null;
      rethrow;
    }
  }
}

EssentialPlayEventsConsentClient essentialPlayEventsConsentClientFor(
  AppConfig config,
) {
  return OpenApiEssentialPlayEventsConsentClient(config);
}

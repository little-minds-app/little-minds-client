import 'dart:convert';

import 'package:little_minds_api/api.dart';

import '../auth/auth_api_clients.dart';
import '../auth/auth_session.dart';
import '../config/app_config.dart';
import 'essential_play_events_consent.dart';

/// Reads/writes parent-level `essential_play_events` consent on the server.
///
/// Routes are coordinated with backend LMP-134 (OpenAPI to pin when published):
/// - `GET  /v1/consent/scopes/essential_play_events/status`
/// - `POST /v1/consent/scopes/essential_play_events/grant`
/// - `POST /v1/consent/scopes/essential_play_events/withdraw`
abstract class EssentialPlayEventsConsentClient {
  Future<EssentialPlayEventsConsentStatus?> fetchStatus(AuthSession session);

  Future<EssentialPlayEventsConsentStatus?> grant({
    required AuthSession session,
    required String policyVersion,
    required String consentTextVersion,
  });

  Future<EssentialPlayEventsConsentStatus?> withdraw({
    required AuthSession session,
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
  }) async =>
      null;
}

final class HttpEssentialPlayEventsConsentClient
    implements EssentialPlayEventsConsentClient {
  HttpEssentialPlayEventsConsentClient(AppConfig config)
      : _clients = AuthApiClients(basePath: config.apiBaseUrlString);

  HttpEssentialPlayEventsConsentClient.fromClients(this._clients);

  final AuthApiClients _clients;

  static const _scopePath = '/v1/consent/scopes/essential_play_events';

  Future<Map<String, dynamic>?> _request(
    AuthSession session,
    String method, {
    String subPath = '',
    Map<String, dynamic>? body,
  }) async {
    _clients.setAccessToken(session.accessToken);
    final response = await _clients.apiClient.invokeAPI(
      '$_scopePath$subPath',
      method,
      [],
      body,
      {},
      {},
      body != null ? 'application/json' : null,
    );
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Consent request failed');
    }
    if (response.body.isEmpty) {
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<EssentialPlayEventsConsentStatus?> fetchStatus(
    AuthSession session,
  ) async {
    final json = await _request(session, 'GET', subPath: '/status');
    if (json == null) return null;
    return EssentialPlayEventsConsentStatus.fromJson(json);
  }

  @override
  Future<EssentialPlayEventsConsentStatus?> grant({
    required AuthSession session,
    required String policyVersion,
    required String consentTextVersion,
  }) async {
    final json = await _request(
      session,
      'POST',
      subPath: '/grant',
      body: {
        'policy_version': policyVersion,
        'consent_text_version': consentTextVersion,
      },
    );
    if (json == null) return null;
    return EssentialPlayEventsConsentStatus.fromJson(json);
  }

  @override
  Future<EssentialPlayEventsConsentStatus?> withdraw({
    required AuthSession session,
  }) async {
    final json = await _request(session, 'POST', subPath: '/withdraw');
    if (json == null) return null;
    return EssentialPlayEventsConsentStatus.fromJson(json);
  }
}

EssentialPlayEventsConsentClient essentialPlayEventsConsentClientFor(
  AppConfig config,
) {
  return HttpEssentialPlayEventsConsentClient(config);
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:little_minds_api/api.dart';

import '../auth/auth_api_clients.dart';
import '../auth/auth_privacy_notice.dart';
import '../auth/auth_session.dart';
import '../config/app_config.dart';

/// Parent-mode PIN API. PINs and gate tokens are never persisted on device.
class ParentGateApi {
  ParentGateApi(AppConfig config)
      : _clients = AuthApiClients(basePath: config.apiBaseUrlString);

  final AuthApiClients _clients;

  String get _surface => defaultTargetPlatform == TargetPlatform.android
      ? 'android' : 'ios';

  void authorize(AuthSession session) {
    _clients.setAccessToken(session.accessToken);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String route, {
    Map<String, dynamic>? payload,
    String? gateToken,
  }) async {
    final headers = <String, String>{};
    if (gateToken != null) {
      headers['X-Parent-Gate-Token'] = gateToken;
    }
    final response = await _clients.apiClient.invokeAPI(
      '/v1/parent/gate/$route',
      method,
      [],
      payload,
      headers,
      {},
      payload != null ? 'application/json' : null,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Parent Gate request failed');
    }
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<bool> configured() async =>
      (await _request('GET', 'status'))['configured'] == true;

  Future<String> verify(String pin) async {
    final response = await _request('POST', 'verify', payload: {'pin': pin});
    final token = response['gate_token'];
    if (token is! String || token.isEmpty) throw StateError('Missing gate token');
    return token;
  }

  Future<void> lock() async {
    await _request('DELETE', 'grant');
  }

  Future<bool> check(String token) async =>
      (await _request('GET', 'grant', gateToken: token))['authorized'] == true;

  Future<String> beginIdentityProof(String channel, String identifier) async {
    if (channel == 'phone') {
      final result = await _clients.auth.startPhoneOtp(PhoneOtpStartRequest(
        phone: identifier,
        noticeVersion: AuthPrivacyNotice.version,
        noticeLocale: AuthPrivacyNotice.locale,
        clientSurface: _surface,
      ));
      if (result == null) throw StateError('OTP start failed');
      return result.challengeId;
    }
    final result = await _clients.auth.startEmailOtp(EmailOtpStartRequest(
      email: identifier,
      noticeVersion: AuthPrivacyNotice.version,
      noticeLocale: AuthPrivacyNotice.locale,
      clientSurface: 'ios',
    ));
    if (result == null) throw StateError('OTP start failed');
    return result.challengeId;
  }

  Future<String> confirmIdentityProof(
    String provider, String challengeId, String code,
  ) async {
    final result = await _request('POST', 'proof', payload: {
      'provider': provider,
      'challenge_id': challengeId,
      'code': code,
    });
    final token = result['step_up_token'];
    if (token is! String) throw StateError('Missing identity proof');
    return token;
  }

  Future<void> setPin(
    String pin, String confirmation, String proof, {required bool reset}
  ) async {
    await _request('POST', reset ? 'reset' : 'setup', payload: {
      'pin': pin,
      'confirmation': confirmation,
      'step_up_token': proof,
    });
  }
}

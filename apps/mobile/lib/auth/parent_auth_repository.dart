// ignore_for_file: prefer_initializing_formals

import 'package:little_minds_api/api.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import 'auth_api_clients.dart';
import 'auth_error.dart';
import 'auth_privacy_notice.dart';
import 'auth_session.dart';
import 'installation_id_store.dart';
import 'auth_token_store.dart';
import 'parent_auth_profile_result.dart';

/// Phone/email OTP + session lifecycle via generated OpenAPI client only.
class ParentAuthRepository {
  ParentAuthRepository({
    required AppConfig config,
    required AuthTokenStore tokenStore,
    AuthApiClients? clients,
    Uuid? uuid,
    InstallationIdStore? installationIdStore,
  })  : _config = config,
        _tokenStore = tokenStore,
        _clients = clients ?? AuthApiClients(basePath: config.apiBaseUrlString),
        _installationIdStore = installationIdStore ?? MemoryInstallationIdStore(uuid: uuid);

  final AppConfig _config;
  final AuthTokenStore _tokenStore;
  final AuthApiClients _clients;
  final InstallationIdStore _installationIdStore;

  Future<String>? _deviceIdInFlight;
  Future<AuthSession>? _refreshInFlight;

  Future<String> deviceId() =>
      _deviceIdInFlight ??= _installationIdStore.getOrCreate();

  Future<AuthSession?> loadPersistedSession() => _tokenStore.readSession();

  Future<PhoneOtpStartResponse> startPhoneOtp(String phone) async {
    try {
      final request = PhoneOtpStartRequest(
        phone: phone.trim(),
        noticeVersion: AuthPrivacyNotice.version,
        noticeLocale: AuthPrivacyNotice.locale,
        clientSurface: 'ios',
        deviceId: await deviceId(),
      );
      final response = await _clients.auth.startPhoneOtp(request);
      if (response == null) {
        throw const ParentAuthFailure(
          code: 'invalid_request',
          message: 'Could not start phone sign-in.',
        );
      }
      return response;
    } on ApiException catch (e) {
      throw ParentAuthFailure.fromApiException(e);
    }
  }

  Future<AuthSession> verifyPhoneOtp({
    required String challengeId,
    required String code,
  }) async {
    try {
      final request = PhoneOtpVerifyRequest(
        challengeId: challengeId,
        code: code.trim(),
        clientSurface: 'ios',
        deviceId: await deviceId(),
      );
      final pair = await _clients.auth.verifyPhoneOtp(request);
      if (pair == null) {
        throw const ParentAuthFailure(
          code: 'otp_invalid',
          message: 'Invalid verification code.',
        );
      }
      final session = AuthSession.fromTokenPair(pair);
      await _persist(session);
      return session;
    } on ApiException catch (e) {
      throw ParentAuthFailure.fromApiException(e);
    }
  }

  Future<EmailOtpStartResponse> startEmailOtp(String email) async {
    try {
      final request = EmailOtpStartRequest(
        email: email.trim(),
        noticeVersion: AuthPrivacyNotice.version,
        noticeLocale: AuthPrivacyNotice.locale,
        clientSurface: 'ios',
      );
      final response = await _clients.auth.startEmailOtp(request);
      if (response == null) {
        throw const ParentAuthFailure(
          code: 'invalid_request',
          message: 'Could not start email sign-in.',
        );
      }
      return response;
    } on ApiException catch (e) {
      throw ParentAuthFailure.fromApiException(e);
    }
  }

  Future<AuthSession> verifyEmailOtp({
    required String challengeId,
    required String code,
  }) async {
    try {
      final request = EmailOtpVerifyRequest(
        challengeId: challengeId,
        code: code.trim(),
        clientSurface: 'ios',
        deviceId: await deviceId(),
      );
      final pair = await _clients.auth.verifyEmailOtp(request);
      if (pair == null) {
        throw const ParentAuthFailure(
          code: 'otp_invalid',
          message: 'Invalid verification code.',
        );
      }
      final session = AuthSession.fromTokenPair(pair);
      await _persist(session);
      return session;
    } on ApiException catch (e) {
      throw ParentAuthFailure.fromApiException(e);
    }
  }

  Future<ParentAuthProfileResult> fetchParentProfile(AuthSession session) async {
    var active = session;
    _clients.setAccessToken(active.accessToken);
    try {
      final me = await _clients.parent.getParentMe();
      if (me == null) {
        throw const ParentAuthFailure(
          code: 'invalid_token',
          message: 'Session expired. Please sign in again.',
        );
      }
      return ParentAuthProfileResult(profile: me, session: active);
    } on ApiException catch (e) {
      if (e.code == 401) {
        active = await refreshSession(active);
        _clients.setAccessToken(active.accessToken);
        final me = await _clients.parent.getParentMe();
        if (me == null) {
          throw ParentAuthFailure.fromApiException(e);
        }
        return ParentAuthProfileResult(profile: me, session: active);
      }
      throw ParentAuthFailure.fromApiException(e);
    }
  }

  Future<AuthSession> refreshSession(AuthSession session) async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    final future = _refreshSessionOnce(session);
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<AuthSession> _refreshSessionOnce(AuthSession session) async {
    final persisted = await _tokenStore.readSession();
    final refreshToken = persisted?.refreshToken ?? session.refreshToken;
    try {
      final pair = await _clients.auth.refreshParentSession(
        RefreshTokenRequest(refreshToken: refreshToken),
      );
      if (pair == null) {
        throw const ParentAuthFailure(
          code: 'invalid_token',
          message: 'Session expired. Please sign in again.',
        );
      }
      final base = persisted ?? session;
      final updated = base.copyWithTokens(pair);
      await _persist(updated);
      return updated;
    } on ApiException catch (e) {
      throw ParentAuthFailure.fromApiException(e);
    }
  }

  Future<void> logout(AuthSession session) async {
    _clients.setAccessToken(session.accessToken);
    try {
      await _clients.auth.logoutParentSession(
        logoutRequest: LogoutRequest(refreshToken: session.refreshToken),
      );
    } on ApiException {
      // Fail closed locally even if network logout fails.
    } finally {
      await _tokenStore.clear();
      _clients.setAccessToken(null);
    }
  }

  Future<void> _persist(AuthSession session) async {
    await _tokenStore.writeSession(session);
    _clients.setAccessToken(session.accessToken);
  }

  AppConfig get config => _config;
}

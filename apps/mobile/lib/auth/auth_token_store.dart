import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session.dart';

/// Secure persistence for parent refresh/access tokens (LMP-37).
abstract class AuthTokenStore {
  Future<AuthSession?> readSession();

  Future<void> writeSession(AuthSession session);

  Future<void> clear();
}

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _sessionKey = 'little_minds_parent_session_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return AuthSession(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      sessionId: map['sessionId'] as String,
      parentId: map['parentId'] as String,
      expiresInSeconds: map['expiresInSeconds'] as int,
    );
  }

  @override
  Future<void> writeSession(AuthSession session) async {
    final payload = jsonEncode({
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'sessionId': session.sessionId,
      'parentId': session.parentId,
      'expiresInSeconds': session.expiresInSeconds,
    });
    await _storage.write(key: _sessionKey, value: payload);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}

/// In-memory store for widget/unit tests (never used in release bootstrap).
class InMemoryAuthTokenStore implements AuthTokenStore {
  AuthSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> writeSession(AuthSession session) async {
    _session = session;
  }
}

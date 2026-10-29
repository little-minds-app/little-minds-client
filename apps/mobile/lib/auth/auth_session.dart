import 'package:little_minds_api/api.dart';

import 'openapi_enum_int.dart';

/// Persisted parent session derived from [TokenPairResponse].
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.parentId,
    required this.expiresInSeconds,
  });

  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final String parentId;
  final int expiresInSeconds;

  factory AuthSession.fromTokenPair(TokenPairResponse pair) {
    return AuthSession(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      sessionId: pair.sessionId,
      parentId: pair.parentId,
      expiresInSeconds: openapiEnumInt(pair.expiresIn),
    );
  }

  AuthSession copyWithTokens(TokenPairResponse pair) {
    return AuthSession(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      sessionId: pair.sessionId,
      parentId: pair.parentId,
      expiresInSeconds: openapiEnumInt(pair.expiresIn),
    );
  }
}

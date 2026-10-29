import 'dart:convert';

import 'package:little_minds_api/api.dart';

import 'openapi_enum_int.dart';

/// User-visible auth failure mapped from OpenAPI [AuthError] when present.
class ParentAuthFailure implements Exception {
  const ParentAuthFailure({
    required this.code,
    required this.message,
    this.httpStatus,
  });

  final String code;
  final String message;
  final int? httpStatus;

  bool get isRetryable =>
      code == 'rate_limited' ||
      code == 'sms_unavailable' ||
      code == 'mail_unavailable' ||
      code == 'otp_cooldown';

  static ParentAuthFailure fromApiException(ApiException ex) {
    final parsed = _tryParseAuthError(ex.message);
    if (parsed != null) {
      return ParentAuthFailure(
        code: openapiAuthErrorCode(parsed.error),
        message: parsed.message,
        httpStatus: ex.code,
      );
    }
    return ParentAuthFailure(
      code: 'unknown',
      message: 'Something went wrong. Please try again.',
      httpStatus: ex.code,
    );
  }

  static AuthError? _tryParseAuthError(String? body) {
    if (body == null || body.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      return AuthError.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

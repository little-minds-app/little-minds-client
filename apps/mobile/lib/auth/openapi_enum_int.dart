import 'package:little_minds_api/api.dart';

/// Decode OpenAPI integer enums from generated Dart models.
int openapiEnumInt(Object value) {
  if (value is int) {
    return value;
  }
  if (value is PhoneOtpStartResponseResendAfterEnum) {
    return PhoneOtpStartResponseResendAfterEnumTypeTransformer().encode(value);
  }
  if (value is EmailOtpStartResponseResendAfterEnum) {
    return EmailOtpStartResponseResendAfterEnumTypeTransformer().encode(value);
  }
  if (value is TokenPairResponseExpiresInEnum) {
    return TokenPairResponseExpiresInEnumTypeTransformer().encode(value);
  }
  return int.tryParse(value.toString()) ?? 0;
}

String openapiAuthErrorCode(AuthErrorErrorEnum error) {
  return AuthErrorErrorEnumTypeTransformer().encode(error);
}

/// Apple/Google UI gates (LMP-37). Feature flags alone must not enable buttons.
class SocialSignInConfig {
  const SocialSignInConfig._();

  /// Flip to true only when native Sign in with Apple / Google SDK wiring ships.
  static const bool nativeSdkIntegrated = false;

  static bool get appleSignInEnabled =>
      nativeSdkIntegrated &&
      const bool.fromEnvironment('LM_APPLE_SIGNIN_ENABLED', defaultValue: false);

  static bool get googleSignInEnabled =>
      nativeSdkIntegrated &&
      const bool.fromEnvironment('LM_GOOGLE_SIGNIN_ENABLED', defaultValue: false);
}

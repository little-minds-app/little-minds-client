/// Build-time gates for Apple/Google SDK wiring (LMP-37 MVP).
///
/// When disabled, onboarding shows safe disabled provider buttons — no silent
/// no-ops and no placeholder tokens sent to the API.
class SocialSignInConfig {
  const SocialSignInConfig({
    required this.appleSignInEnabled,
    required this.googleSignInEnabled,
  });

  final bool appleSignInEnabled;
  final bool googleSignInEnabled;

  static SocialSignInConfig fromEnvironment() {
    return SocialSignInConfig(
      appleSignInEnabled: const bool.fromEnvironment(
        'LM_APPLE_SIGNIN_ENABLED',
        defaultValue: false,
      ),
      googleSignInEnabled: const bool.fromEnvironment(
        'LM_GOOGLE_SIGNIN_ENABLED',
        defaultValue: false,
      ),
    );
  }
}

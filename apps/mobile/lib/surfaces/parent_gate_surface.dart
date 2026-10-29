import 'package:flutter/material.dart';

import '../auth/auth_privacy_notice.dart';
import '../auth/parent_auth_controller.dart';
import '../auth/parent_auth_scope.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Parent Gate — onboarding, OTP sign-in, and authenticated handoff (LMP-37).
class ParentGateSurface extends StatefulWidget {
  const ParentGateSurface({
    super.key,
    this.onBackToHub,
    this.onOpenSettings,
  });

  final VoidCallback? onBackToHub;
  final VoidCallback? onOpenSettings;

  static const Key surfaceKey = Key('surface-parent-gate');
  static const Key onboardingKey = Key('parent-auth-onboarding');
  static const Key phoneFieldKey = Key('parent-auth-phone-field');
  static const Key emailFieldKey = Key('parent-auth-email-field');
  static const Key otpFieldKey = Key('parent-auth-otp-field');
  static const Key errorBannerKey = Key('parent-auth-error-banner');
  static const Key loadingKey = Key('parent-auth-loading');
  static const Key authenticatedKey = Key('parent-auth-authenticated');

  @override
  State<ParentGateSurface> createState() => ParentGateSurfaceState();
}

class ParentGateSurfaceState extends State<ParentGateSurface>
    with AutomaticKeepAliveClientMixin {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  String get phoneText => _phoneController.text;
  String get emailText => _emailController.text;
  String get otpText => _otpController.text;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = ParentAuthScope.of(context);
    return OrientationBinder(
      surface: AppSurface.parentGate,
      child: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          final settingsEnabled =
              auth.step == ParentAuthStep.authenticated && auth.isAuthenticated;
          return AdaptiveShell(
            title: 'Parent Gate',
            actions: [
              if (settingsEnabled)
                TextButton(
                  key: const Key('nav-parent-settings'),
                  onPressed: widget.onOpenSettings,
                  child: const Text('Settings'),
                ),
              TextButton(
                key: const Key('nav-back-hub-from-gate'),
                onPressed: widget.onBackToHub,
                child: const Text('Back to Hub'),
              ),
            ],
            body: KeyedSubtree(
              key: ParentGateSurface.surfaceKey,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildBody(context, auth),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ParentAuthController auth) {
    if (auth.busy) {
      return const Center(
        key: ParentGateSurface.loadingKey,
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.lastError != null)
            MaterialBanner(
              key: ParentGateSurface.errorBannerKey,
              content: Text(auth.lastError!.message),
              leading: const Icon(Icons.error_outline),
              actions: [
                if (auth.lastError!.isRetryable)
                  TextButton(
                    onPressed: auth.clearError,
                    child: const Text('Dismiss'),
                  ),
                TextButton(
                  onPressed: auth.clearError,
                  child: const Text('OK'),
                ),
              ],
            ),
          switch (auth.step) {
            ParentAuthStep.onboarding => _onboarding(context, auth),
            ParentAuthStep.phoneEntry ||
            ParentAuthStep.phoneVerify =>
              _phoneFlow(context, auth),
            ParentAuthStep.emailEntry ||
            ParentAuthStep.emailVerify =>
              _emailFlow(context, auth),
            ParentAuthStep.authenticated => _authenticated(context, auth),
          },
        ],
      ),
    );
  }

  Widget _onboarding(BuildContext context, ParentAuthController auth) {
    final social = auth.socialConfig;
    return Column(
      key: ParentGateSurface.onboardingKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Parent sign-in',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          AuthPrivacyNotice.engineeringSummary,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('parent-auth-phone-entry'),
          onPressed: auth.openPhoneFlow,
          child: const Text('Continue with phone'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('parent-auth-email-entry'),
          onPressed: auth.openEmailFlow,
          child: const Text('Continue with email'),
        ),
        const SizedBox(height: 24),
        _socialButton(
          label: 'Sign in with Apple',
          enabled: social.appleSignInEnabled,
          reason: 'Apple Sign In is not configured for this build.',
          key: const Key('parent-auth-apple'),
        ),
        const SizedBox(height: 8),
        _socialButton(
          label: 'Sign in with Google',
          enabled: social.googleSignInEnabled,
          reason: 'Google Sign In is not configured for this build.',
          key: const Key('parent-auth-google'),
        ),
      ],
    );
  }

  Widget _phoneFlow(BuildContext context, ParentAuthController auth) {
    final verifying = auth.step == ParentAuthStep.phoneVerify;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          verifying ? 'Enter SMS code' : 'Phone number',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (!verifying)
          TextField(
            key: ParentGateSurface.phoneFieldKey,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (TR)',
              hintText: '+905551112233',
              border: OutlineInputBorder(),
            ),
          )
        else
          TextField(
            key: ParentGateSurface.otpFieldKey,
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: '6-digit code',
              border: const OutlineInputBorder(),
              helperText: auth.resendAfterSeconds > 0
                  ? 'Resend available in ${auth.resendAfterSeconds}s'
                  : null,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('parent-auth-phone-submit'),
          onPressed: () {
            if (verifying) {
              auth.submitPhoneCode(_otpController.text);
            } else {
              auth.submitPhone(_phoneController.text);
            }
          },
          child: Text(verifying ? 'Verify' : 'Send code'),
        ),
        TextButton(
          onPressed: auth.showOnboarding,
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _emailFlow(BuildContext context, ParentAuthController auth) {
    final verifying = auth.step == ParentAuthStep.emailVerify;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          verifying ? 'Enter email code' : 'Email address',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (!verifying)
          TextField(
            key: ParentGateSurface.emailFieldKey,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          )
        else
          TextField(
            key: ParentGateSurface.otpFieldKey,
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-digit code',
              border: OutlineInputBorder(),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('parent-auth-email-submit'),
          onPressed: () {
            if (verifying) {
              auth.submitEmailCode(_otpController.text);
            } else {
              auth.submitEmail(_emailController.text);
            }
          },
          child: Text(verifying ? 'Verify' : 'Send code'),
        ),
        TextButton(
          onPressed: auth.showOnboarding,
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _authenticated(BuildContext context, ParentAuthController auth) {
    return Column(
      key: ParentGateSurface.authenticatedKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Signed in',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Parent ID: ${auth.session?.parentId ?? '—'}'),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('parent-auth-open-settings'),
          onPressed: widget.onOpenSettings,
          child: const Text('Open Parent Settings'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('parent-auth-logout'),
          onPressed: auth.logout,
          child: const Text('Log out'),
        ),
      ],
    );
  }

  Widget _socialButton({
    required Key key,
    required String label,
    required bool enabled,
    required String reason,
  }) {
    return Tooltip(
      message: enabled ? label : reason,
      child: OutlinedButton(
        key: key,
        onPressed: enabled ? null : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: enabled ? null : Colors.grey,
        ),
        child: Text(enabled ? label : '$label (unavailable)'),
      ),
    );
  }
}

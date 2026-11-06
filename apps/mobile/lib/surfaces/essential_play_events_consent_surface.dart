import 'package:flutter/material.dart';

import '../auth/parent_auth_scope.dart';
import '../consent/essential_play_events_consent.dart';
import '../consent/essential_play_events_consent_scope.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shape_matching/published_content_registry.dart';
import '../shape_matching/shape_matching_constants.dart';
import '../shell/adaptive_shell.dart';

/// Explicit opt-in for `essential_play_events` (F-033) — not OTP notice, not PG.
class EssentialPlayEventsConsentSurface extends StatefulWidget {
  const EssentialPlayEventsConsentSurface({
    super.key,
    this.onBack,
    this.onCompleted,
    this.publicationRegistry,
  });

  final VoidCallback? onBack;
  final VoidCallback? onCompleted;

  /// Injectable for widget tests; production uses pinned registry from config.
  final PublishedContentRegistry? publicationRegistry;

  static const Key surfaceKey = Key('surface-essential-play-consent');
  static const Key optInCheckboxKey = Key('essential-play-consent-checkbox');
  static const Key grantButtonKey = Key('essential-play-consent-grant');
  static const Key declineButtonKey = Key('essential-play-consent-decline');
  static const Key withdrawButtonKey = Key('essential-play-consent-withdraw');
  static const Key errorKey = Key('essential-play-consent-error');
  static const Key busyKey = Key('essential-play-consent-busy');

  @override
  State<EssentialPlayEventsConsentSurface> createState() =>
      _EssentialPlayEventsConsentSurfaceState();
}

class _EssentialPlayEventsConsentSurfaceState
    extends State<EssentialPlayEventsConsentSurface> {
  bool _optInChecked = false;
  bool _busy = false;
  String? _error;

  Future<String?> _policyVersion() async {
    final registry = widget.publicationRegistry;
    if (registry == null) return null;
    final publication = await registry.publicationForActivity(
      ShapeMatchingConstants.activityId,
    );
    return publication?.consentPolicyVersion;
  }

  Future<void> _grant() async {
    if (!_optInChecked || _busy) return;
    final auth = ParentAuthScope.of(context);
    final session = auth.session;
    final consent = EssentialPlayEventsConsentScope.of(context);
    if (session == null) return;
    final policy = await _policyVersion();
    if (policy == null || policy.isEmpty) {
      setState(() => _error = 'Publication policy is not available.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await consent.grant(
      session: session,
      policyVersion: policy,
    );
    if (!mounted) return;
    switch (result) {
      case EssentialPlayEventsConsentMutationOk():
        setState(() => _busy = false);
        widget.onCompleted?.call();
      case EssentialPlayEventsConsentMutationFailed(:final message):
        setState(() {
          _busy = false;
          _error = message;
        });
    }
  }

  Future<void> _withdraw() async {
    if (_busy) return;
    final auth = ParentAuthScope.of(context);
    final session = auth.session;
    final consent = EssentialPlayEventsConsentScope.of(context);
    if (session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await consent.withdraw(session);
    if (!mounted) return;
    switch (result) {
      case EssentialPlayEventsConsentMutationOk():
        setState(() => _busy = false);
        widget.onCompleted?.call();
      case EssentialPlayEventsConsentMutationFailed(:final message):
        setState(() {
          _busy = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = EssentialPlayEventsConsentScope.of(context);
    final granted = consent.hasEffectiveGrant;
    return OrientationBinder(
      surface: AppSurface.parentSettings,
      child: ListenableBuilder(
        listenable: consent,
        builder: (context, _) {
          return AdaptiveShell(
            title: EssentialPlayEventsConsentCopy.screenTitle,
            actions: [
              TextButton(
                key: const Key('nav-back-from-play-consent'),
                onPressed: widget.onBack,
                child: const Text('Back'),
              ),
            ],
            body: KeyedSubtree(
              key: EssentialPlayEventsConsentSurface.surfaceKey,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _busy
                    ? const Center(
                        key: EssentialPlayEventsConsentSurface.busyKey,
                        child: CircularProgressIndicator(),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              EssentialPlayEventsConsentCopy.screenTitle,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              EssentialPlayEventsConsentCopy.lead,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              MaterialBanner(
                                key: EssentialPlayEventsConsentSurface.errorKey,
                                content: Text(_error!),
                                leading: const Icon(Icons.error_outline),
                                actions: [
                                  TextButton(
                                    onPressed: () => setState(() => _error = null),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (granted) ...[
                              Text(
                                'Status: opted in'
                                '${consent.status?.policyVersion != null ? ' (${consent.status!.policyVersion})' : ''}.',
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                key: EssentialPlayEventsConsentSurface.withdrawButtonKey,
                                onPressed: _withdraw,
                                child: const Text(
                                  EssentialPlayEventsConsentCopy.withdrawLabel,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                EssentialPlayEventsConsentCopy.withdrawConfirm,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ] else ...[
                              CheckboxListTile(
                                key: EssentialPlayEventsConsentSurface.optInCheckboxKey,
                                value: _optInChecked,
                                onChanged: (value) => setState(
                                  () => _optInChecked = value ?? false,
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                title: const Text(
                                  EssentialPlayEventsConsentCopy.checkboxLabel,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                key: EssentialPlayEventsConsentSurface.grantButtonKey,
                                onPressed: _optInChecked ? _grant : null,
                                child: const Text(
                                  EssentialPlayEventsConsentCopy.grantLabel,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                key: EssentialPlayEventsConsentSurface.declineButtonKey,
                                onPressed: widget.onBack,
                                child: const Text(
                                  EssentialPlayEventsConsentCopy.declineLabel,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Native Parent Settings placeholder — portrait + landscape (ADR-018).
///
/// Grown-ups-only entry to the LMP-45 Near/Far demo (not child-facing Hub nav).
class ParentSettingsSurface extends StatelessWidget {
  const ParentSettingsSurface({
    super.key,
    this.onBack,
    this.onOpenNearFarDemo,
  });

  final VoidCallback? onBack;

  /// Opens the dedicated Near/Far Kids Mode demo route (LMP-45).
  final VoidCallback? onOpenNearFarDemo;

  static const Key surfaceKey = Key('surface-parent-settings');
  static const Key placeholderKey = Key('parent-settings-placeholder');
  static const Key nearFarDemoKey = Key('parent-settings-near-far-demo');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OrientationBinder(
      surface: AppSurface.parentSettings,
      child: AdaptiveShell(
        title: 'Parent Settings',
        actions: [
          TextButton(
            key: const Key('nav-back-from-settings'),
            onPressed: onBack,
            child: const Text('Back'),
          ),
        ],
        body: KeyedSubtree(
          key: surfaceKey,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    key: placeholderKey,
                    'Parent Settings placeholder. Flavors, analytics, and billing arrive later.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (onOpenNearFarDemo != null) ...[
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 200,
                      ),
                      child: OutlinedButton(
                        key: nearFarDemoKey,
                        onPressed: onOpenNearFarDemo,
                        child: Text(l10n.nearFarDemoEntry),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

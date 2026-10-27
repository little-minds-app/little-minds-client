import 'package:flutter/material.dart';

import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Native Parent Settings placeholder — portrait + landscape (ADR-018).
class ParentSettingsSurface extends StatelessWidget {
  const ParentSettingsSurface({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  static const Key surfaceKey = Key('surface-parent-settings');
  static const Key placeholderKey = Key('parent-settings-placeholder');

  @override
  Widget build(BuildContext context) {
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
              child: Text(
                key: placeholderKey,
                'Parent Settings placeholder. Flavors, analytics, and billing arrive later.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

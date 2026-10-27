import 'package:flutter/material.dart';

import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Child profile selection placeholder — landscape-only (ADR-018).
class ProfileSelectionSurface extends StatelessWidget {
  const ProfileSelectionSurface({
    super.key,
    this.onBackToHub,
  });

  final VoidCallback? onBackToHub;

  static const Key surfaceKey = Key('surface-profile-selection');
  static const Key placeholderKey = Key('profile-selection-placeholder');

  @override
  Widget build(BuildContext context) {
    return OrientationBinder(
      surface: AppSurface.profileSelection,
      child: AdaptiveShell(
        title: 'Profile selection',
        actions: [
          TextButton(
            key: const Key('nav-back-hub'),
            onPressed: onBackToHub,
            child: const Text('Back to Hub'),
          ),
        ],
        body: KeyedSubtree(
          key: surfaceKey,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                key: placeholderKey,
                'Child profile selection placeholder. No child PII in bootstrap.',
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

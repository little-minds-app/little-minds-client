import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Native Parent Settings placeholder — portrait + landscape (ADR-018).
///
/// Reached only via Parent Gate (Hub → Gate → Settings). Temporary developer
/// entries: LMP-48 Near/Far mentor card and LMP-45 Near/Far demo — never Kids
/// Hub tiles. Gate/Settings remain scaffolding until real auth lands.
///
/// Body is scrollable so short phone landscape (F-034) does not overflow when
/// both mentor and Near/Far demo entries are present.
class ParentSettingsSurface extends StatelessWidget {
  const ParentSettingsSurface({
    super.key,
    this.onBack,
    this.onOpenNearFarDemo,
    this.onOpenNearFarMentor,
  });

  final VoidCallback? onBack;

  /// Opens the dedicated Near/Far Kids Mode demo route (LMP-45).
  ///
  /// Temporary demo affordance only — not an authenticated caregiver control.
  final VoidCallback? onOpenNearFarDemo;

  /// Opens the Parent Near/Far mentor card surface (LMP-48). Parent path only.
  final VoidCallback? onOpenNearFarMentor;

  static const Key surfaceKey = Key('surface-parent-settings');
  static const Key placeholderKey = Key('parent-settings-placeholder');
  static const Key nearFarDemoKey = Key('parent-settings-near-far-demo');
  static const Key nearFarDemoHintKey = Key('parent-settings-near-far-demo-hint');
  static const Key nearFarMentorKey = Key('parent-settings-near-far-mentor');
  static const Key nearFarMentorHintKey =
      Key('parent-settings-near-far-mentor-hint');
  static const Key scrollKey = Key('parent-settings-scroll');

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
          child: SingleChildScrollView(
            key: scrollKey,
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      key: placeholderKey,
                      'Parent Settings placeholder. Flavors, analytics, and billing arrive later.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (onOpenNearFarMentor != null) ...[
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 200,
                        ),
                        child: FilledButton.tonal(
                          key: nearFarMentorKey,
                          onPressed: onOpenNearFarMentor,
                          child: Text(l10n.mentorCardSettingsEntry),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        key: nearFarMentorHintKey,
                        l10n.mentorCardSettingsEntryHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
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
                      const SizedBox(height: 8),
                      Text(
                        key: nearFarDemoHintKey,
                        l10n.nearFarDemoEntryHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

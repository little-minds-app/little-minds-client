import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../screen_time/screen_time_debug_qa.dart';
import '../shell/adaptive_shell.dart';

/// Native Parent Settings placeholder — portrait + landscape (ADR-018).
///
/// Reached only via Parent Gate (Hub → Gate → Settings). Temporary developer
/// entries: LMP-48 Near/Far mentor card and LMP-45 Near/Far demo — never Kids
/// Hub tiles. Gate/Settings remain scaffolding until real auth lands.
///
/// Debug-only: LMP-49 screen-time inspector entry when [kDebugMode] (or test
/// force). Never shown on Hub / Mentor / child surfaces.
///
/// Body is scrollable so short phone landscape (F-034) does not overflow when
/// both mentor and Near/Far demo entries are present.
class ParentSettingsSurface extends StatelessWidget {
  const ParentSettingsSurface({
    super.key,
    this.onBack,
    this.onOpenProfiles,
    this.onOpenOptionalParentProfile,
    this.onOpenNearFarDemo,
    this.onOpenNearFarMentor,
    this.onOpenScreenTimeDebug,
    this.forceShowScreenTimeDebugEntry = false,
  });

  final VoidCallback? onBack;

  /// Opens child profile management from the authenticated parent area.
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenOptionalParentProfile;

  /// Opens the dedicated Near/Far Kids Mode demo route (LMP-45).
  ///
  /// Temporary demo affordance only — not an authenticated caregiver control.
  final VoidCallback? onOpenNearFarDemo;

  /// Opens the Parent Near/Far mentor card surface (LMP-48). Parent path only.
  final VoidCallback? onOpenNearFarMentor;

  /// Opens the debug-only screen-time inspector (LMP-49 Step 3.2).
  final VoidCallback? onOpenScreenTimeDebug;

  /// Widget-test force for the debug entry without relying solely on [kDebugMode].
  final bool forceShowScreenTimeDebugEntry;

  static const Key surfaceKey = Key('surface-parent-settings');
  static const Key placeholderKey = Key('parent-settings-placeholder');
  static const Key nearFarDemoKey = Key('parent-settings-near-far-demo');
  static const Key nearFarDemoHintKey = Key('parent-settings-near-far-demo-hint');
  static const Key nearFarMentorKey = Key('parent-settings-near-far-mentor');
  static const Key nearFarMentorHintKey =
      Key('parent-settings-near-far-mentor-hint');
  static const Key screenTimeDebugKey = Key('parent-settings-screen-time-debug');
  static const Key screenTimeDebugHintKey =
      Key('parent-settings-screen-time-debug-hint');
  static const Key scrollKey = Key('parent-settings-scroll');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showScreenTimeDebug = onOpenScreenTimeDebug != null &&
        ScreenTimeDebugQa.showEntry(
          forceShowEntryForTest: forceShowScreenTimeDebugEntry,
        );
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
                    if (onOpenOptionalParentProfile != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        key: const Key('parent-settings-optional-profile'),
                        onPressed: onOpenOptionalParentProfile,
                        child: const Text('Ebeveyn profilimi düzenle'),
                      ),
                    ],
                    if (onOpenProfiles != null) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('parent-settings-child-profiles'),
                        onPressed: onOpenProfiles,
                        child: const Text('Çocuk profillerini yönet'),
                      ),
                    ],
                    if (showScreenTimeDebug) ...[
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 200,
                        ),
                        child: OutlinedButton(
                          key: screenTimeDebugKey,
                          onPressed: onOpenScreenTimeDebug,
                          child: Text(l10n.screenTimeDebugSettingsEntry),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        key: screenTimeDebugHintKey,
                        l10n.screenTimeDebugSettingsEntryHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
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

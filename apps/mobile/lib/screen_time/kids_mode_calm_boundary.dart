import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Minimal calm daily-limit boundary (K06-lite / LMP-49 Step 2).
///
/// Not F-011 Healthy Ending polish — no pressure copy, no "one more", no
/// dark patterns. Blocks child play; optional grown-ups exit.
class KidsModeCalmBoundary extends StatelessWidget {
  const KidsModeCalmBoundary({
    super.key,
    this.onOpenParentGate,
  });

  final VoidCallback? onOpenParentGate;

  static const Key surfaceKey = Key('screen-time-calm-boundary');
  static const Key grownUpsKey = Key('screen-time-calm-grown-ups');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      key: surfaceKey,
      color: const Color(0xE6E8F5E9),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.screenTimeCalmTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.screenTimeCalmBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF33691E),
                      height: 1.35,
                    ),
                  ),
                  if (onOpenParentGate != null) ...[
                    const SizedBox(height: 28),
                    TextButton(
                      key: grownUpsKey,
                      onPressed: onOpenParentGate,
                      child: Text(l10n.screenTimeCalmGrownUps),
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

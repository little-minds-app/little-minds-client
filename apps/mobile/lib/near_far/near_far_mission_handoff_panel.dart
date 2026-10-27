import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'near_far_activity.dart';
import 'near_far_mission_handoff.dart';

/// Calm safe mission invitation after digital play (LMP-45 handoff only).
///
/// No skip / feedback / photo proof — those belong to LMP-46.
class NearFarMissionHandoffPanel extends StatelessWidget {
  const NearFarMissionHandoffPanel({
    super.key,
    required this.activity,
    required this.onDismiss,
  });

  final NearFarActivity activity;
  final VoidCallback onDismiss;

  static const Key panelKey = Key('near-far-mission-handoff');
  static const Key openKey = Key('near-far-mission-open');
  static const Key dismissKey = Key('near-far-mission-dismiss');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final handoff = activity.missionHandoff.handoff;

    return Material(
      key: panelKey,
      color: const Color(0xCCFFF8E1),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.nearFarMissionTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.nearFarMissionBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.nearFarMissionMaterials,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (handoff.state == NearFarMissionHandoffState.offered ||
                        handoff.state == NearFarMissionHandoffState.opened)
                      ConstrainedBox(
                        constraints:
                            const BoxConstraints(minHeight: 48, minWidth: 160),
                        child: FilledButton(
                          key: openKey,
                          onPressed: () => activity.openMissionHandoff(),
                          child: Text(l10n.nearFarMissionOpen),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: 48, minWidth: 160),
                      child: TextButton(
                        key: dismissKey,
                        onPressed: () {
                          activity.missionHandoff.dismiss();
                          onDismiss();
                        },
                        child: Text(l10n.nearFarMissionLater),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'near_far_activity.dart';
import 'near_far_mission_handoff.dart';

/// Calm safe mission invitation after digital play (LMP-45 handoff only).
///
/// Full-bleed opaque scrim + constrained readable card so play-field chrome
/// cannot overlap ("Nice exploring!" vs "Try it in the room"). No skip /
/// feedback / photo proof — those belong to LMP-46.
class NearFarMissionHandoffPanel extends StatelessWidget {
  const NearFarMissionHandoffPanel({
    super.key,
    required this.activity,
    required this.onDismiss,
  });

  final NearFarActivity activity;
  final VoidCallback onDismiss;

  static const Key panelKey = Key('near-far-mission-handoff');
  static const Key cardKey = Key('near-far-mission-handoff-card');
  static const Key openKey = Key('near-far-mission-open');
  static const Key dismissKey = Key('near-far-mission-dismiss');

  /// Readable card width on phone landscape / tablet.
  static const double maxCardWidth = 520;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final handoff = activity.missionHandoff.handoff;
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1).clamp(1.0, 1.6);

    // Opaque scrim — play field is not shown underneath during handoff, but
    // keep a solid calm fill so no game chrome bleeds through.
    return ColoredBox(
      key: panelKey,
      color: const Color(0xFFFFF6E0),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = math.max(120.0, constraints.maxHeight - 8);
            final maxW = math.min(
              maxCardWidth,
              math.max(200.0, constraints.maxWidth - 24),
            );
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxW,
                  maxHeight: maxH,
                  minWidth: math.min(280, maxW),
                ),
                child: Material(
                  key: cardKey,
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20 * textScale.clamp(1.0, 1.2),
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.nearFarMissionTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.nearFarMissionBody,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.nearFarMissionMaterials,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black54,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (handoff.state ==
                                    NearFarMissionHandoffState.offered ||
                                handoff.state ==
                                    NearFarMissionHandoffState.opened)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                  minWidth: 148,
                                ),
                                child: FilledButton(
                                  key: openKey,
                                  onPressed: () =>
                                      activity.openMissionHandoff(),
                                  child: Text(l10n.nearFarMissionOpen),
                                ),
                              ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 48,
                                minWidth: 148,
                              ),
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
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

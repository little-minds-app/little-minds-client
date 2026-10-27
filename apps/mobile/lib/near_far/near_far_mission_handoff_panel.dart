import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'near_far_activity.dart';
import 'near_far_mission_handoff.dart';

/// Optional sock + soft-toy real-world mission surface (LMP-46 / K05 / F-008).
///
/// Full-bleed opaque scrim + constrained readable card. Start/Try, Skip, Back,
/// and calm completion/exit — never photos, proof, permissions, timers, or
/// scoring. Parent mentor card UI stays LMP-47/48. Spoken mission prompts are
/// deferred to LMP-120 (on-screen copy only here).
///
/// Action buttons stay in a pinned footer so short phone landscape never hides
/// Skip / Done / Back behind scrolled steps.
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
  static const Key skipKey = Key('near-far-mission-skip');
  static const Key doneKey = Key('near-far-mission-done');
  static const Key openedConfirmKey = Key('near-far-mission-opened-confirm');
  static const Key skippedKey = Key('near-far-mission-skipped');
  static const Key completedKey = Key('near-far-mission-completed');
  static const Key stepsKey = Key('near-far-mission-steps');
  static const Key dismissKey = Key('near-far-mission-dismiss');

  /// Readable card width on phone landscape / tablet.
  static const double maxCardWidth = 520;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final handoff = activity.missionHandoff.handoff;
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1).clamp(1.0, 1.6);
    final state = handoff.state;
    final isOffered = state == NearFarMissionHandoffState.offered;
    final isOpened = state == NearFarMissionHandoffState.opened;
    final isSkipped = state == NearFarMissionHandoffState.skipped;
    final isCompleted = state == NearFarMissionHandoffState.completed;

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
            final padH = 20 * textScale.clamp(1.0, 1.2);
            // Bound height so Expanded+scroll + pinned footer layout is valid
            // on short phone landscape (actions never off-screen).
            return Center(
              child: SizedBox(
                width: maxW,
                height: maxH,
                child: Material(
                  key: cardKey,
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padH, 14, padH, 12),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: _MissionBody(
                              l10n: l10n,
                              isOffered: isOffered,
                              isOpened: isOpened,
                              isSkipped: isSkipped,
                              isCompleted: isCompleted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (isOffered)
                              _ActionButton(
                                key: openKey,
                                filled: true,
                                label: l10n.nearFarMissionTry,
                                onPressed: () =>
                                    activity.startMissionHandoff(),
                              ),
                            if (isOpened)
                              _ActionButton(
                                key: doneKey,
                                filled: true,
                                label: l10n.nearFarMissionDone,
                                onPressed: () =>
                                    activity.completeMissionOptionally(),
                              ),
                            if (isOffered || isOpened)
                              _ActionButton(
                                key: skipKey,
                                filled: false,
                                label: l10n.nearFarMissionSkip,
                                onPressed: () =>
                                    activity.skipMissionHandoff(),
                              ),
                            _ActionButton(
                              key: dismissKey,
                              filled: false,
                              label: isOffered
                                  ? l10n.nearFarMissionLater
                                  : l10n.nearFarMissionBack,
                              onPressed: () {
                                activity.dismissMissionHandoff();
                                onDismiss();
                              },
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

class _MissionBody extends StatelessWidget {
  const _MissionBody({
    required this.l10n,
    required this.isOffered,
    required this.isOpened,
    required this.isSkipped,
    required this.isCompleted,
  });

  final AppLocalizations l10n;
  final bool isOffered;
  final bool isOpened;
  final bool isSkipped;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isOpened ? l10n.nearFarMissionStepsTitle : l10n.nearFarMissionTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (isOffered) ...[
          Text(
            l10n.nearFarMissionBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.nearFarMissionMaterials,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
        ],
        if (isOpened)
          Semantics(
            liveRegion: true,
            child: Column(
              key: NearFarMissionHandoffPanel.stepsKey,
              children: [
                Text(
                  key: NearFarMissionHandoffPanel.openedConfirmKey,
                  l10n.nearFarMissionOpenedConfirm,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _MissionStep(text: l10n.nearFarMissionStep1),
                _MissionStep(text: l10n.nearFarMissionStep2),
                _MissionStep(text: l10n.nearFarMissionStep3),
                _MissionStep(text: l10n.nearFarMissionStep4),
                const SizedBox(height: 6),
                Text(
                  l10n.nearFarMissionMaterials,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        if (isSkipped)
          Semantics(
            liveRegion: true,
            child: Text(
              key: NearFarMissionHandoffPanel.skippedKey,
              l10n.nearFarMissionSkipped,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF455A64),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        if (isCompleted)
          Semantics(
            liveRegion: true,
            child: Text(
              key: NearFarMissionHandoffPanel.completedKey,
              l10n.nearFarMissionCompleted,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
    );
  }
}

class _MissionStep extends StatelessWidget {
  const _MissionStep({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    const constraints = BoxConstraints(minHeight: 48, minWidth: 148);
    return ConstrainedBox(
      constraints: constraints,
      child: filled
          ? FilledButton(onPressed: onPressed, child: child)
          : TextButton(onPressed: onPressed, child: child),
    );
  }
}

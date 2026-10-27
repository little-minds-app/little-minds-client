import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'hub_activity_catalog.dart';

/// Large, calm activity tile for Child Hub (F-004 / F-034 / F-020).
///
/// Playable tiles are announced as buttons and may invoke [onPlay].
/// Passive tiles are **not** presented as game-launch buttons: they remain
/// focusable for "coming soon" information only and never open the Flame host.
class HubActivityCard extends StatelessWidget {
  const HubActivityCard({
    super.key,
    required this.tile,
    required this.onPassiveTap,
    this.onPlay,
    this.minSize = 72,
  });

  final HubActivityTile tile;
  final VoidCallback onPassiveTap;
  final VoidCallback? onPlay;

  /// Kids Mode minimum touch target edge (logical px). Prefer ≥64.
  final double minSize;

  static Key cardKey(String id) => Key('hub-activity-card-$id');
  static Key passiveBadgeKey(String id) => Key('hub-passive-badge-$id');
  static Key playableBadgeKey(String id) => Key('hub-playable-badge-$id');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final playable = tile.isPlayable;
    final colorScheme = theme.colorScheme;

    final background = playable
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final foreground = playable
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    final visual = ExcludeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            // Sighted tap: playable launches; passive only informs (never Flame).
            onTap: playable ? onPlay : onPassiveTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: playable
                        ? _StatusChip(
                            key: playableBadgeKey(tile.id),
                            label: l10n.hubPlayableHint,
                            foreground: foreground,
                            emphasized: true,
                          )
                        : _StatusChip(
                            key: passiveBadgeKey(tile.id),
                            label: l10n.hubPassiveBadge,
                            foreground: foreground,
                            emphasized: false,
                          ),
                  ),
                  const Spacer(),
                  Text(
                    tile.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (playable) {
      return Semantics(
        key: cardKey(tile.id),
        button: true,
        enabled: true,
        label: tile.title,
        hint: l10n.hubPlayableHint,
        onTap: onPlay,
        child: visual,
      );
    }

    // Passive / not ready: do NOT use the button role — screen readers must not
    // hear an active game control. Label states "Soon" / not ready; onTap only
    // informs (Parent/Hub handlers must not open Flame for these tiles).
    return Semantics(
      key: cardKey(tile.id),
      button: false,
      enabled: true,
      label: '${tile.title}. ${l10n.hubPassiveBadge}. ${l10n.hubPassiveHint}',
      onTap: onPassiveTap,
      child: visual,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    super.key,
    required this.label,
    required this.foreground,
    required this.emphasized,
  });

  final String label;
  final Color foreground;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? foreground.withValues(alpha: 0.16)
            : foreground.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

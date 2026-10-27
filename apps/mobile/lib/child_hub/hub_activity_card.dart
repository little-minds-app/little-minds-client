import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'hub_activity_catalog.dart';

/// Large, calm activity tile for Child Hub (F-004 / F-034 / F-020).
///
/// Playable tiles invoke [onPlay]. Passive tiles never launch a game —
/// they only invoke [onPassiveTap] for audio/a11y feedback.
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

    final VoidCallback? action = playable ? onPlay : onPassiveTap;

    return Semantics(
      key: cardKey(tile.id),
      button: true,
      enabled: true,
      label: tile.title,
      hint: playable ? l10n.hubPlayableHint : l10n.hubPassiveHint,
      onTap: action,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: action,
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
      ),
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

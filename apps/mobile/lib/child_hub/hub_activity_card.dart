import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'hub_activity_art.dart';
import 'hub_activity_catalog.dart';
import 'hub_theme.dart';

/// Illustrated Child Hub activity card (F-004 / F-034 / F-020).
///
/// Playable → button semantics + optional Flame launch.
/// Passive → **not** a game button; Coming Soon / Yakında; tap informs only.
class HubActivityCard extends StatelessWidget {
  const HubActivityCard({
    super.key,
    required this.tile,
    required this.onPassiveTap,
    this.onPlay,
    this.minSize = HubTheme.minTouch,
  });

  final HubActivityTile tile;
  final VoidCallback onPassiveTap;
  final VoidCallback? onPlay;
  final double minSize;

  static Key cardKey(String id) => Key('hub-activity-card-$id');
  static Key passiveBadgeKey(String id) => Key('hub-passive-badge-$id');
  static Key playableBadgeKey(String id) => Key('hub-playable-badge-$id');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playable = tile.isPlayable;
    final fill = HubTheme.cardFillFor(tile.catalogId, playable: playable);

    final visual = ExcludeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(HubTheme.cardRadius),
            onTap: playable ? onPlay : onPassiveTap,
            child: Ink(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(HubTheme.cardRadius),
                border: Border.all(
                  color: HubTheme.accentFor(tile.catalogId)
                      .withValues(alpha: playable ? 0.45 : 0.22),
                  width: 2,
                ),
                boxShadow: HubTheme.cardShadow(passive: !playable),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: playable
                          ? _StatusChip(
                              key: playableBadgeKey(tile.id),
                              label: l10n.hubPlayableHint,
                              emphasized: true,
                            )
                          : _StatusChip(
                              key: passiveBadgeKey(tile.id),
                              label: l10n.hubPassiveBadge,
                              emphasized: false,
                            ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: HubActivityArt(
                        catalogId: tile.catalogId,
                        playable: playable,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tile.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: HubTheme.ink,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
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
    required this.emphasized,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? HubTheme.brand.withValues(alpha: 0.14)
            : HubTheme.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: HubTheme.ink.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

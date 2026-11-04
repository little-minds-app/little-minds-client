import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'activity_registry.dart';

/// Shared Flame game shell. Production registry seeds Shape Matching (LMP-55);
/// other hub engines remain unregistered until later E03 tasks.
///
/// Session pause/resume is driven by [ActivitySessionController] (LMP-44).
class StubLearningGame extends FlameGame {
  StubLearningGame({ActivityRegistry? registry})
      : registry = registry ?? ActivityRegistry();

  final ActivityRegistry registry;

  @override
  Color backgroundColor() => const Color(0xFFE8F5E9);
}

/// Diagnostic overlay for bootstrap / empty registry. Playable sessions use
/// [ActivityPlayHost] instead.
class FlameHostPanel extends StatelessWidget {
  const FlameHostPanel({
    super.key,
    required this.game,
  });

  final StubLearningGame game;

  static const Key hostKey = Key('flame-host-panel');
  static const Key emptyRegistryKey = Key('flame-empty-registry');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      key: hostKey,
      fit: StackFit.expand,
      children: [
        GameWidget(game: game),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.flameHostReady,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                key: emptyRegistryKey,
                game.registry.isEmpty
                    ? l10n.flameRegistryEmpty
                    : l10n.flameRegistryCount(game.registry.length),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

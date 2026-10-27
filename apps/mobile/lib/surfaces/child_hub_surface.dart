import 'package:flutter/material.dart';

import '../game/flame_host.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Child Hub placeholder — landscape-only (ADR-018). F-004 stub only.
class ChildHubSurface extends StatelessWidget {
  const ChildHubSurface({
    super.key,
    required this.game,
    this.onOpenProfiles,
    this.onOpenParentGate,
  });

  final StubLearningGame game;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenParentGate;

  static const Key surfaceKey = Key('surface-child-hub');
  static const Key placeholderKey = Key('child-hub-placeholder');

  @override
  Widget build(BuildContext context) {
    return OrientationBinder(
      surface: AppSurface.childHub,
      child: AdaptiveShell(
        title: 'Child Hub',
        navigation: _HubNav(
          onOpenProfiles: onOpenProfiles,
          onOpenParentGate: onOpenParentGate,
        ),
        actions: [
          TextButton(
            key: const Key('nav-profile-selection'),
            onPressed: onOpenProfiles,
            child: const Text('Profiles'),
          ),
          TextButton(
            key: const Key('nav-parent-gate'),
            onPressed: onOpenParentGate,
            child: const Text('Parent Gate'),
          ),
        ],
        body: KeyedSubtree(
          key: surfaceKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  key: placeholderKey,
                  'Kids home placeholder — accessible navigation arrives in later tasks (F-004).',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Expanded(child: FlameHostPanel(game: game)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubNav extends StatelessWidget {
  const _HubNav({
    this.onOpenProfiles,
    this.onOpenParentGate,
  });

  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenParentGate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: const Text('Profiles'),
          onTap: onOpenProfiles,
        ),
        ListTile(
          title: const Text('Parent Gate'),
          onTap: onOpenParentGate,
        ),
      ],
    );
  }
}

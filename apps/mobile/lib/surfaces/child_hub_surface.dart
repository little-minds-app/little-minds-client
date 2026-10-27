import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../child_hub/hub_activity_card.dart';
import '../child_hub/hub_activity_catalog.dart';
import '../child_hub/hub_audio_guidance.dart';
import '../config/env_config_badge.dart';
import '../game/flame_host.dart';
import '../game/learning_activity.dart';
import '../l10n/app_localizations.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/window_size_class.dart';

/// Kids Mode Child Hub v1 — landscape-only home (F-004, F-020, F-034, ADR-018).
///
/// Offline-safe: no external navigation. Only [LearningActivity.isPlayable]
/// registry entries launch the Flame host. Unimplemented catalog engines stay
/// passive. Parent exit routes exclusively through Parent Gate.
class ChildHubSurface extends StatefulWidget {
  const ChildHubSurface({
    super.key,
    required this.game,
    this.onOpenProfiles,
    this.onOpenParentGate,
    this.forceShowEnvBadge = false,
    this.audioGuidance,
    this.soundOff = false,
  });

  final StubLearningGame game;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenParentGate;

  /// When true, always show the LMP-28 env badge (widget tests).
  final bool forceShowEnvBadge;

  /// Injectable audio guidance (defaults to local-asset graceful stub).
  final HubAudioGuidance? audioGuidance;

  /// Explicit sound-off (also respects MediaQuery accessibility / tests).
  final bool soundOff;

  static const Key surfaceKey = Key('surface-child-hub');
  static const Key homeKey = Key('child-hub-home');
  static const Key greetingKey = Key('child-hub-greeting');
  static const Key brandKey = Key('child-hub-brand');
  static const Key emptyPlayableKey = Key('child-hub-empty-playable');
  static const Key activityGridKey = Key('child-hub-activity-grid');
  static const Key compactLayoutKey = Key('child-hub-compact-layout');
  static const Key expandedLayoutKey = Key('child-hub-expanded-layout');
  static const Key parentExitKey = Key('nav-parent-gate');
  static const Key profilesKey = Key('nav-profile-selection');
  static const Key playHostKey = Key('child-hub-play-host');

  /// Legacy key kept so older tests fail loudly if placeholder regresses.
  @Deprecated('Use homeKey — placeholder removed in LMP-43')
  static const Key placeholderKey = Key('child-hub-placeholder');

  @override
  State<ChildHubSurface> createState() => _ChildHubSurfaceState();
}

class _ChildHubSurfaceState extends State<ChildHubSurface> {
  late final HubAudioGuidance _audio =
      widget.audioGuidance ?? LocalAssetHubAudioGuidance();
  LearningActivity? _activePlayable;
  var _didWelcome = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didWelcome) {
      return;
    }
    _didWelcome = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _playCue(HubAudioCue.welcome);
    });
  }

  bool get _effectiveSoundOff => widget.soundOff;

  Future<void> _playCue(HubAudioCue cue) {
    final locale = Localizations.localeOf(context);
    return _audio.play(
      cue,
      localeTag: hubLocaleTag(locale),
      soundOff: _effectiveSoundOff,
    );
  }

  void _announce(String message) {
    final view = View.maybeOf(context);
    if (view == null) {
      return;
    }
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    SemanticsService.sendAnnouncement(view, message, direction);
  }

  Future<void> _onPassiveTap(HubActivityTile tile) async {
    final l10n = AppLocalizations.of(context);
    await _playCue(HubAudioCue.passiveUnavailable);
    _announce('${tile.title}. ${l10n.hubPassiveHint}');
  }

  Future<void> _onPlay(HubActivityTile tile) async {
    final activity = tile.activity;
    if (activity == null || !activity.isPlayable) {
      await _onPassiveTap(tile);
      return;
    }
    await _playCue(HubAudioCue.playableSelect);
    setState(() => _activePlayable = activity);
  }

  Future<void> _onParentExit() async {
    await _playCue(HubAudioCue.parentExit);
    widget.onOpenParentGate?.call();
  }

  void _closePlayHost() {
    setState(() => _activePlayable = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return OrientationBinder(
      surface: AppSurface.childHub,
      child: KeyedSubtree(
        key: ChildHubSurface.surfaceKey,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE8F5E9),
                Color(0xFFFFF8E7),
                Color(0xFFE3F2FD),
              ],
            ),
          ),
          child: SafeArea(
            child: _activePlayable != null
                ? _PlayHost(
                    game: widget.game,
                    onClose: _closePlayHost,
                    forceShowEnvBadge: widget.forceShowEnvBadge,
                  )
                : _HubHome(
                    game: widget.game,
                    reduceMotion: reduceMotion,
                    forceShowEnvBadge: widget.forceShowEnvBadge,
                    onOpenProfiles: widget.onOpenProfiles,
                    onParentExit: _onParentExit,
                    onPassiveTap: _onPassiveTap,
                    onPlay: _onPlay,
                    l10n: l10n,
                  ),
          ),
        ),
      ),
    );
  }
}

class _HubHome extends StatelessWidget {
  const _HubHome({
    required this.game,
    required this.reduceMotion,
    required this.forceShowEnvBadge,
    required this.onOpenProfiles,
    required this.onParentExit,
    required this.onPassiveTap,
    required this.onPlay,
    required this.l10n,
  });

  final StubLearningGame game;
  final bool reduceMotion;
  final bool forceShowEnvBadge;
  final VoidCallback? onOpenProfiles;
  final VoidCallback onParentExit;
  final Future<void> Function(HubActivityTile tile) onPassiveTap;
  final Future<void> Function(HubActivityTile tile) onPlay;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tiles = HubActivityCatalog.resolve(
      l10n: l10n,
      registry: game.registry,
    );
    final hasPlayable = tiles.any((t) => t.isPlayable);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Landscape phones are often "wide" by width-only breakpoints but short
        // in height — keep single-pane Kids Mode until both axes have room
        // for a side rail (F-034 adaptive, not stretched phone chrome).
        final sizeClass = windowSizeClassForWidth(constraints.maxWidth);
        final expanded = sizeClass.isExpandedLike && constraints.maxHeight >= 560;
        final crossAxisCount = expanded ? 3 : 2;

        final header = _HubHeader(
          l10n: l10n,
          reduceMotion: reduceMotion,
          onOpenProfiles: onOpenProfiles,
          onParentExit: onParentExit,
        );

        // Six catalog tiles — build eagerly (not lazy) so offline/a11y tests and
        // Kids Mode always expose every passive/playable choice.
        final grid = KeyedSubtree(
          key: ChildHubSurface.activityGridKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: LayoutBuilder(
              builder: (context, gridConstraints) {
                const spacing = 16.0;
                final aspect = expanded ? 1.35 : 1.2;
                final tileWidth = (gridConstraints.maxWidth -
                        spacing * (crossAxisCount - 1)) /
                    crossAxisCount;
                final tileHeight = tileWidth / aspect;
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final tile in tiles)
                        SizedBox(
                          width: tileWidth,
                          height: tileHeight,
                          child: HubActivityCard(
                            tile: tile,
                            onPassiveTap: () => onPassiveTap(tile),
                            onPlay:
                                tile.isPlayable ? () => onPlay(tile) : null,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        final body = Column(
          key: ChildHubSurface.homeKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (!hasPlayable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  key: ChildHubSurface.emptyPlayableKey,
                  l10n.hubEmptyPlayable,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: EnvConfigBadge(forceVisible: forceShowEnvBadge),
            ),
            Expanded(child: grid),
          ],
        );

        if (!expanded) {
          return KeyedSubtree(
            key: ChildHubSurface.compactLayoutKey,
            child: body,
          );
        }

        return KeyedSubtree(
          key: ChildHubSurface.expandedLayoutKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 220,
                child: _HubSideRail(
                  l10n: l10n,
                  onOpenProfiles: onOpenProfiles,
                  onParentExit: onParentExit,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.l10n,
    required this.reduceMotion,
    required this.onOpenProfiles,
    required this.onParentExit,
  });

  final AppLocalizations l10n;
  final bool reduceMotion;
  final VoidCallback? onOpenProfiles;
  final VoidCallback onParentExit;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1B5E20),
        );

    final brand = Text(
      key: ChildHubSurface.brandKey,
      l10n.appTitle,
      style: titleStyle,
    );

    final greeting = Text(
      key: ChildHubSurface.greetingKey,
      l10n.hubGreeting,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );

    final brandBlock = reduceMotion
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              brand,
              const SizedBox(height: 4),
              greeting,
              const SizedBox(height: 4),
              Text(
                l10n.hubSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          )
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 12),
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                brand,
                const SizedBox(height: 4),
                greeting,
                const SizedBox(height: 4),
                Text(
                  l10n.hubSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: brandBlock),
          const SizedBox(width: 8),
          _HubIconButton(
            key: ChildHubSurface.profilesKey,
            tooltip: l10n.hubProfiles,
            semanticLabel: l10n.hubProfiles,
            semanticHint: l10n.hubProfilesHint,
            icon: Icons.face_rounded,
            onPressed: onOpenProfiles,
          ),
          const SizedBox(width: 8),
          _HubIconButton(
            key: ChildHubSurface.parentExitKey,
            tooltip: l10n.hubParentExit,
            semanticLabel: l10n.hubParentExit,
            semanticHint: l10n.hubAudioParentExitCue,
            icon: Icons.family_restroom_rounded,
            onPressed: onParentExit,
          ),
        ],
      ),
    );
  }
}

class _HubSideRail extends StatelessWidget {
  const _HubSideRail({
    required this.l10n,
    required this.onOpenProfiles,
    required this.onParentExit,
  });

  final AppLocalizations l10n;
  final VoidCallback? onOpenProfiles;
  final VoidCallback onParentExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.appTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.face_rounded),
            title: Text(l10n.hubProfiles),
            onTap: onOpenProfiles,
          ),
          ListTile(
            leading: const Icon(Icons.family_restroom_rounded),
            title: Text(l10n.hubParentExit),
            onTap: onParentExit,
          ),
        ],
      ),
    );
  }
}

class _HubIconButton extends StatelessWidget {
  const _HubIconButton({
    super.key,
    required this.tooltip,
    required this.semanticLabel,
    required this.semanticHint,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final String semanticLabel;
  final String semanticHint;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      hint: semanticHint,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            child: Material(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 28,
                onPressed: onPressed,
                icon: Icon(icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayHost extends StatelessWidget {
  const _PlayHost({
    required this.game,
    required this.onClose,
    required this.forceShowEnvBadge,
  });

  final StubLearningGame game;
  final VoidCallback onClose;
  final bool forceShowEnvBadge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: ChildHubSurface.playHostKey,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('hub-close-play-host'),
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(l10n.hubGreeting),
          ),
        ),
        EnvConfigBadge(forceVisible: forceShowEnvBadge),
        Expanded(child: FlameHostPanel(game: game)),
      ],
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../child_hub/hub_activity_card.dart';
import '../child_hub/hub_activity_carousel.dart';
import '../child_hub/hub_activity_catalog.dart';
import '../child_hub/hub_audio_guidance.dart';
import '../child_hub/hub_theme.dart';
import '../config/env_config_badge.dart';
import '../game/flame_host.dart';
import '../game/learning_activity.dart';
import '../l10n/app_localizations.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/window_size_class.dart';

/// Kids Mode Child Hub v1 — landscape preschool home (F-004, F-020, F-034, ADR-018).
///
/// Phone landscape: horizontal carousel (~3 visible).
/// Tablet landscape: responsive 3×2 grid.
/// Only [LearningActivity.isPlayable] launches Flame; Parent Gate is the safe exit.
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

  /// When true, show LMP-28 env badge (widget tests / developer reveal).
  final bool forceShowEnvBadge;

  final HubAudioGuidance? audioGuidance;
  final bool soundOff;

  static const Key surfaceKey = Key('surface-child-hub');
  static const Key homeKey = Key('child-hub-home');
  static const Key greetingKey = Key('child-hub-greeting');
  static const Key brandKey = Key('child-hub-brand');
  static const Key emptyPlayableKey = Key('child-hub-empty-playable');
  static const Key activityGridKey = Key('child-hub-activity-grid');
  static const Key activityCarouselKey = HubActivityCarousel.carouselKey;
  static const Key carouselIndicatorKey = HubActivityCarousel.indicatorKey;
  static const Key compactLayoutKey = Key('child-hub-compact-layout');
  static const Key expandedLayoutKey = Key('child-hub-expanded-layout');
  static const Key parentExitKey = Key('nav-parent-gate');
  static const Key profilesKey = Key('nav-profile-selection');
  static const Key playHostKey = Key('child-hub-play-host');
  static const Key worldBackdropKey = Key('child-hub-world-backdrop');

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
  var _developerBadgeVisible = false;

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

  bool get _showEnvBadge =>
      widget.forceShowEnvBadge || (kDebugMode && _developerBadgeVisible);

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

  void _onBrandLongPress() {
    if (!kDebugMode) {
      return;
    }
    setState(() => _developerBadgeVisible = !_developerBadgeVisible);
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
          key: ChildHubSurface.worldBackdropKey,
          decoration: const BoxDecoration(gradient: HubTheme.worldGradient),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _WorldDecor(),
              SafeArea(
                child: _activePlayable != null
                    ? _PlayHost(
                        game: widget.game,
                        onClose: _closePlayHost,
                        showEnvBadge: _showEnvBadge,
                      )
                    : _HubHome(
                        game: widget.game,
                        reduceMotion: reduceMotion,
                        showEnvBadge: _showEnvBadge,
                        onBrandLongPress: _onBrandLongPress,
                        onOpenProfiles: widget.onOpenProfiles,
                        onParentExit: _onParentExit,
                        onPassiveTap: _onPassiveTap,
                        onPlay: _onPlay,
                        l10n: l10n,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldDecor extends StatelessWidget {
  const _WorldDecor();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SoftHillsPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SoftHillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hill = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.68,
        size.width * 0.5,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.84,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hill,
      Paint()..color = HubTheme.meadow.withValues(alpha: 0.55),
    );

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.55);
    const spots = [
      Offset(0.12, 0.18),
      Offset(0.28, 0.12),
      Offset(0.72, 0.16),
      Offset(0.88, 0.22),
      Offset(0.55, 0.1),
    ];
    for (final o in spots) {
      canvas.drawCircle(
        Offset(size.width * o.dx, size.height * o.dy),
        3.5,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HubHome extends StatelessWidget {
  const _HubHome({
    required this.game,
    required this.reduceMotion,
    required this.showEnvBadge,
    required this.onBrandLongPress,
    required this.onOpenProfiles,
    required this.onParentExit,
    required this.onPassiveTap,
    required this.onPlay,
    required this.l10n,
  });

  final StubLearningGame game;
  final bool reduceMotion;
  final bool showEnvBadge;
  final VoidCallback onBrandLongPress;
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
        final sizeClass = windowSizeClassForWidth(constraints.maxWidth);
        final useTabletGrid =
            sizeClass.isExpandedLike && constraints.maxHeight >= 560;

        final header = _HubHeader(
          l10n: l10n,
          reduceMotion: reduceMotion,
          onBrandLongPress: onBrandLongPress,
          onOpenProfiles: onOpenProfiles,
          onParentExit: onParentExit,
        );

        final board = useTabletGrid
            ? _TabletGrid(
                tiles: tiles,
                onPassiveTap: onPassiveTap,
                onPlay: onPlay,
              )
            : HubActivityCarousel(
                tiles: tiles,
                onPassiveTap: onPassiveTap,
                onPlay: onPlay,
              );

        return KeyedSubtree(
          key: useTabletGrid
              ? ChildHubSurface.expandedLayoutKey
              : ChildHubSurface.compactLayoutKey,
          child: Column(
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HubTheme.ink.withValues(alpha: 0.7),
                        ),
                  ),
                ),
              if (showEnvBadge)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  child: EnvConfigBadge(forceVisible: true),
                ),
              Expanded(child: board),
            ],
          ),
        );
      },
    );
  }
}

class _TabletGrid extends StatelessWidget {
  const _TabletGrid({
    required this.tiles,
    required this.onPassiveTap,
    required this.onPlay,
  });

  final List<HubActivityTile> tiles;
  final Future<void> Function(HubActivityTile tile) onPassiveTap;
  final Future<void> Function(HubActivityTile tile) onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ChildHubSurface.activityGridKey,
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const cols = 3;
          const rows = 2;
          const spacing = 18.0;
          final tileWidth =
              (constraints.maxWidth - spacing * (cols - 1)) / cols;
          final tileHeight =
              (constraints.maxHeight - spacing * (rows - 1)) / rows;
          return Wrap(
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
                    onPlay: tile.isPlayable ? () => onPlay(tile) : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.l10n,
    required this.reduceMotion,
    required this.onBrandLongPress,
    required this.onOpenProfiles,
    required this.onParentExit,
  });

  final AppLocalizations l10n;
  final bool reduceMotion;
  final VoidCallback onBrandLongPress;
  final VoidCallback? onOpenProfiles;
  final VoidCallback onParentExit;

  @override
  Widget build(BuildContext context) {
    final brand = GestureDetector(
      onLongPress: onBrandLongPress,
      child: Text(
        key: ChildHubSurface.brandKey,
        l10n.appTitle,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HubTheme.brand,
              letterSpacing: -0.3,
            ),
      ),
    );

    final greeting = Text(
      key: ChildHubSurface.greetingKey,
      l10n.hubGreeting,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: HubTheme.ink.withValues(alpha: 0.9),
          ),
    );

    final titles = reduceMotion
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [brand, const SizedBox(height: 2), greeting],
          )
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 10),
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [brand, const SizedBox(height: 2), greeting],
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: [
          Expanded(child: titles),
          _HubBubbleButton(
            key: ChildHubSurface.profilesKey,
            tooltip: l10n.hubProfiles,
            semanticLabel: l10n.hubProfiles,
            semanticHint: l10n.hubProfilesHint,
            icon: Icons.face_rounded,
            color: const Color(0xFF64B5F6),
            onPressed: onOpenProfiles,
          ),
          const SizedBox(width: 10),
          _HubBubbleButton(
            key: ChildHubSurface.parentExitKey,
            tooltip: l10n.hubParentExit,
            semanticLabel: l10n.hubParentExit,
            semanticHint: l10n.hubAudioParentExitCue,
            icon: Icons.family_restroom_rounded,
            color: const Color(0xFFFF8A65),
            onPressed: onParentExit,
          ),
        ],
      ),
    );
  }
}

class _HubBubbleButton extends StatelessWidget {
  const _HubBubbleButton({
    super.key,
    required this.tooltip,
    required this.semanticLabel,
    required this.semanticHint,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final String semanticLabel;
  final String semanticHint;
  final IconData icon;
  final Color color;
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
          child: Material(
            color: color.withValues(alpha: 0.22),
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(icon, color: HubTheme.ink.withValues(alpha: 0.85)),
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
    required this.showEnvBadge,
  });

  final StubLearningGame game;
  final VoidCallback onClose;
  final bool showEnvBadge;

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
        if (showEnvBadge) EnvConfigBadge(forceVisible: true),
        Expanded(child: FlameHostPanel(game: game)),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'hub_activity_card.dart';
import 'hub_activity_catalog.dart';
import 'hub_theme.dart';

/// Phone-landscape snapped activity carousel with page dots (F-004 / F-034).
///
/// Layout/usability only — does not change approved card art or palette.
/// Tablet keeps the 3×2 grid. [padEnds] + viewport fraction keep first/last
/// cards fully reachable while peeking a neighbor as intentional affordance.
class HubActivityCarousel extends StatelessWidget {
  const HubActivityCarousel({
    super.key,
    required this.tiles,
    required this.onPassiveTap,
    required this.onPlay,
  });

  final List<HubActivityTile> tiles;
  final Future<void> Function(HubActivityTile tile) onPassiveTap;
  final Future<void> Function(HubActivityTile tile) onPlay;

  static const Key carouselKey = Key('child-hub-activity-carousel');
  static const Key indicatorKey = Key('child-hub-carousel-indicator');
  static Key pageKey(int index) => Key('child-hub-carousel-page-$index');
  static Key dotKey(int index) => Key('child-hub-carousel-dot-$index');

  /// Fraction of viewport per page — ~2–3 cards + peek of the next.
  /// Narrower phones get a slightly larger card so titles stay readable.
  @visibleForTesting
  static double viewportFractionForWidth(double width) =>
      width < 700 ? 0.42 : 0.34;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fraction =
            HubActivityCarousel.viewportFractionForWidth(constraints.maxWidth);
        return _SnappingCarousel(
          key: ValueKey<double>(fraction),
          tiles: tiles,
          viewportFraction: fraction,
          onPassiveTap: onPassiveTap,
          onPlay: onPlay,
        );
      },
    );
  }
}

class _SnappingCarousel extends StatefulWidget {
  const _SnappingCarousel({
    super.key,
    required this.tiles,
    required this.viewportFraction,
    required this.onPassiveTap,
    required this.onPlay,
  });

  final List<HubActivityTile> tiles;
  final double viewportFraction;
  final Future<void> Function(HubActivityTile tile) onPassiveTap;
  final Future<void> Function(HubActivityTile tile) onPlay;

  @override
  State<_SnappingCarousel> createState() => _SnappingCarouselState();
}

class _SnappingCarouselState extends State<_SnappingCarousel> {
  late final PageController _controller;
  var _index = 0;

  /// Current snapped page index (tests via [HubActivityCarouselState] finder).
  int get pageIndex => _index;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewportFraction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goTo(int index, {required bool reduceMotion}) async {
    if (!_controller.hasClients) {
      return;
    }
    final clamped = index.clamp(0, widget.tiles.length - 1);
    if (reduceMotion) {
      _controller.jumpToPage(clamped);
    } else {
      await _controller.animateToPage(
        clamped,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final count = widget.tiles.length;

    return Column(
      key: HubActivityCarousel.carouselKey,
      children: [
            Expanded(
              child: PageView(
                controller: _controller,
                padEnds: true,
                allowImplicitScrolling: true,
                physics: const PageScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                onPageChanged: (i) {
                  if (_index != i) {
                    setState(() => _index = i);
                  }
                },
                children: [
                  for (var index = 0; index < count; index++)
                    Padding(
                      key: HubActivityCarousel.pageKey(index),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      child: HubActivityCard(
                        tile: widget.tiles[index],
                        onPassiveTap: () =>
                            widget.onPassiveTap(widget.tiles[index]),
                        onPlay: widget.tiles[index].isPlayable
                            ? () => widget.onPlay(widget.tiles[index])
                            : null,
                      ),
                    ),
                ],
              ),
            ),
        const SizedBox(height: 6),
        _CarouselDots(
          count: count,
          index: _index,
          reduceMotion: reduceMotion,
          semanticLabel: l10n.hubCarouselPageLabel(_index + 1, count),
          onSelect: (i) => _goTo(i, reduceMotion: reduceMotion),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({
    required this.count,
    required this.index,
    required this.reduceMotion,
    required this.semanticLabel,
    required this.onSelect,
  });

  final int count;
  final int index;
  final bool reduceMotion;
  final String semanticLabel;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: HubActivityCarousel.indicatorKey,
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                button: true,
                selected: i == index,
                label: l10n.hubCarouselDotLabel(i + 1),
                child: GestureDetector(
                  key: HubActivityCarousel.dotKey(i),
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    width: i == index ? 12 : 8,
                    height: i == index ? 12 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == index
                          ? HubTheme.brand
                          : HubTheme.ink.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

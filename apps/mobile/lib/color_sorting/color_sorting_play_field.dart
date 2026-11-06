import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/activity_session_controller.dart';
import '../game/hitbox_scaler.dart';
import '../game/scoring_neutral_outcome.dart';
import '../l10n/app_localizations.dart';
import '../shape_matching/shape_matching_bunny_mascot.dart';
import 'color_sorting_activity.dart';
import 'color_sorting_characters.dart';
import 'color_sorting_constants.dart';
import 'color_sorting_logic.dart';
import 'color_sorting_orchard_scene.dart';
import 'color_sorting_visual_profile.dart';

/// Landscape Color Sorting play surface — Colorful Orchard (F-034).
class ColorSortingPlayField extends StatefulWidget {
  const ColorSortingPlayField({
    super.key,
    required this.activity,
    required this.controller,
    this.reduceMotion = false,
  });

  final ColorSortingActivity activity;
  final ActivitySessionController controller;
  final bool reduceMotion;

  static const Key fieldKey = Key('color-sorting-play-field');
  static const Key instructionZoneKey = Key('color-sorting-instruction-zone');
  static const Key objectZoneKey = Key('color-sorting-object-zone');
  static const Key binsZoneKey = Key('color-sorting-bins-zone');
  static const Key feedbackZoneKey = Key('color-sorting-feedback-zone');
  static const Key objectKey = Key('color-sorting-object');
  static const Key promptKey = Key('color-sorting-prompt');
  static const Key completionKey = Key('color-sorting-completion');
  static const Key replayKey = Key('color-sorting-replay');
  static const Key hintKey = Key('color-sorting-hint');
  static const Key tryAgainKey = Key('color-sorting-try-again');
  static const Key praiseKey = Key('color-sorting-praise');

  static Key binKey(ColorToken token) =>
      Key('color-sorting-bin-${token.name}');

  @override
  State<ColorSortingPlayField> createState() => _ColorSortingPlayFieldState();
}

class _ColorSortingPlayFieldState extends State<ColorSortingPlayField> {
  ColorSortingActivity get activity => widget.activity;
  ActivitySessionController get controller => widget.controller;
  bool get reduceMotion => widget.reduceMotion;

  BunnyMascotMood _mascotMood = BunnyMascotMood.idle;
  Timer? _moodTimer;
  var _moodEpoch = 0;
  var _praiseVisible = false;
  var _praiseIndex = 0;
  var _celebratedSortSerial = 0;

  @override
  void initState() {
    super.initState();
    _celebratedSortSerial = activity.correctSortSerial;
    activity.addListener(_onActivityChanged);
  }

  @override
  void didUpdateWidget(covariant ColorSortingPlayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != activity) {
      oldWidget.activity.removeListener(_onActivityChanged);
      _resetVisualFeedback();
      activity.addListener(_onActivityChanged);
      _syncMoodFromOutcome(notify: false);
    }
  }

  @override
  void dispose() {
    _cancelMoodTimer();
    _moodEpoch++;
    activity.removeListener(_onActivityChanged);
    super.dispose();
  }

  void _cancelMoodTimer() {
    _moodTimer?.cancel();
    _moodTimer = null;
  }

  void _resetVisualFeedback() {
    _cancelMoodTimer();
    _moodEpoch++;
    _mascotMood = BunnyMascotMood.idle;
    _praiseVisible = false;
    _praiseIndex = 0;
    _celebratedSortSerial = activity.correctSortSerial;
  }

  void _onActivityChanged() {
    if (!mounted) return;
    _syncMoodFromOutcome(notify: true);
  }

  void _syncMoodFromOutcome({required bool notify}) {
    final outcome = activity.lastOutcome;

    if (outcome == null) {
      _resetVisualFeedback();
      if (notify) setState(() {});
      return;
    }

    if (outcome is ActivityCompletedOutcome) {
      _setMood(
        BunnyMascotMood.complete,
        hold: const Duration(seconds: 4),
        notify: notify,
      );
      _praiseVisible = true;
      if (notify) setState(() {});
      return;
    }
    if (outcome is EncouragementOutcome) {
      if (outcome.cueKey == 'color_sort') {
        final serial = activity.correctSortSerial;
        if (serial > _celebratedSortSerial) {
          _celebratedSortSerial = serial;
          _praiseIndex++;
          _praiseVisible = true;
          _setMood(
            BunnyMascotMood.celebrate,
            hold: const Duration(milliseconds: 1200),
            notify: notify,
          );
        }
        return;
      }
      if (outcome.cueKey == 'try_again') {
        _praiseVisible = false;
        _setMood(
          BunnyMascotMood.encourage,
          hold: const Duration(milliseconds: 900),
          notify: notify,
        );
        return;
      }
    }
    if (notify) setState(() {});
  }

  void _setMood(
    BunnyMascotMood mood, {
    required Duration hold,
    bool notify = true,
  }) {
    _cancelMoodTimer();
    final epoch = _moodEpoch;
    _mascotMood = mood;
    if (notify) setState(() {});
    if (mood == BunnyMascotMood.complete) return;
    _moodTimer = Timer(hold, () {
      if (!mounted || epoch != _moodEpoch) return;
      setState(() {
        _mascotMood = BunnyMascotMood.idle;
        if (_praiseVisible &&
            activity.lastOutcome is! ActivityCompletedOutcome) {
          _praiseVisible = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final round = activity.round;
    final completed = activity.lastOutcome is ActivityCompletedOutcome;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;
    final profile = ColorSortingVisualProfile.forAgeMonths(
      activity.ageMonths > 0 ? activity.ageMonths : 36,
    );

    return LayoutBuilder(
      key: ColorSortingPlayField.fieldKey,
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            ColorSortingOrchardScene(profile: profile),
            if (completed)
              _CompletionPanel(
                l10n: l10n,
                viewport: viewport,
                reduceMotion: reduceMotion,
                profile: profile,
                onReplay: () {
                  // ignore: discarded_futures
                  controller.restart();
                },
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 8 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(
                      key: ColorSortingPlayField.instructionZoneKey,
                      child: _InstructionZone(l10n: l10n, profile: profile),
                    ),
                    Expanded(
                      flex: 38,
                      child: KeyedSubtree(
                        key: ColorSortingPlayField.objectZoneKey,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: _ObjectZone(
                                round: round,
                                activity: activity,
                                l10n: l10n,
                                viewport: viewport,
                                reduceMotion: reduceMotion,
                                profile: profile,
                                onDragStart: _handleDragStart,
                                onTapObject: _handleObjectTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IgnorePointer(
                                child: ShapeMatchingBunnyMascot(
                                  profile: profile.asBunnyProfile,
                                  mood: _mascotMood,
                                  reduceMotion: reduceMotion,
                                  size: math.min(
                                        viewport.shortestSide * 0.22,
                                        110,
                                      ) *
                                      profile.mascotScale,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 42,
                      child: KeyedSubtree(
                        key: ColorSortingPlayField.binsZoneKey,
                        child: _BinsZone(
                          round: round,
                          activity: activity,
                          l10n: l10n,
                          viewport: viewport,
                          reduceMotion: reduceMotion,
                          profile: profile,
                          onAccept: _handleSort,
                          onTapBin: _handleBinTap,
                        ),
                      ),
                    ),
                    KeyedSubtree(
                      key: ColorSortingPlayField.feedbackZoneKey,
                      child: _FeedbackZone(
                        l10n: l10n,
                        hintLevel: activity.hintLevel,
                        showTryAgain:
                            activity.lastOutcome is EncouragementOutcome &&
                                (activity.lastOutcome as EncouragementOutcome)
                                        .cueKey ==
                                    'try_again',
                        showPraise: _praiseVisible,
                        praiseIndex: _praiseIndex,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  void _handleObjectTap() {
    activity.notifyObjectTap();
  }

  void _handleDragStart() {
    activity.notifyObjectDragStart();
  }

  void _handleBinTap(ColorToken bin) {
    activity.notifyObjectTap();
    _handleSort(bin);
  }

  void _handleSort(ColorToken bin) {
    activity.sortIntoBin(bin);
    final outcome = activity.lastOutcome;
    if (outcome is ActivityCompletedOutcome ||
        outcome is HintOfferedOutcome ||
        outcome is EncouragementOutcome) {
      controller.reportOutcome(outcome!);
    }
  }
}

class _InstructionZone extends StatelessWidget {
  const _InstructionZone({required this.l10n, required this.profile});

  final AppLocalizations l10n;
  final ColorSortingVisualProfile profile;

  @override
  Widget build(BuildContext context) {
    final toddler = profile.band == ColorSortingVisualBand.toddler;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(
            key: ColorSortingPlayField.promptKey,
            l10n.colorSortingPromptSort,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: toddler ? 26 : 22,
                  color: const Color(0xFF1B5E20),
                  shadows: const [
                    Shadow(
                      color: Color(0x66FFFFFF),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.colorSortingTapOrDragHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF455A64),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ObjectZone extends StatelessWidget {
  const _ObjectZone({
    required this.round,
    required this.activity,
    required this.l10n,
    required this.viewport,
    required this.reduceMotion,
    required this.profile,
    required this.onDragStart,
    required this.onTapObject,
  });

  final ColorSortingRound? round;
  final ColorSortingActivity activity;
  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
  final ColorSortingVisualProfile profile;
  final VoidCallback onDragStart;
  final VoidCallback onTapObject;

  @override
  Widget build(BuildContext context) {
    if (round == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaled = HitboxScaler.scaleLength(
          ColorSortingConstants.designObjectDropSize,
          viewport: viewport,
          minLogical: 72,
        );
        final maxByHeight = constraints.maxHeight - 8;
        final side = math.min(scaled, maxByHeight).clamp(72.0, 128.0);
        final label = _colorLabel(l10n, round!.objectColor);

        final character = ColorSortingObjectCharacter(
          key: ColorSortingPlayField.objectKey,
          color: round!.objectColor,
          form: round!.objectForm,
          size: side,
          profile: profile,
          highlighted: activity.hintLevel >= 1,
        );

        return Center(
          child: Semantics(
            label: '${l10n.colorSortingObjectLabel}: $label',
            child: Draggable<ColorToken>(
              data: round!.objectColor,
              maxSimultaneousDrags: activity.interactionsEnabled ? 1 : 0,
              onDragStarted:
                  activity.interactionsEnabled ? onDragStart : null,
              feedback: Material(
                color: Colors.transparent,
                child: ColorSortingObjectCharacter(
                  color: round!.objectColor,
                  form: round!.objectForm,
                  size: side,
                  profile: profile,
                  highlighted: true,
                  lifted: true,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.28,
                child: ColorSortingObjectCharacter(
                  color: round!.objectColor,
                  form: round!.objectForm,
                  size: side,
                  profile: profile,
                ),
              ),
              child: GestureDetector(
                onTap: activity.interactionsEnabled ? onTapObject : null,
                behavior: HitTestBehavior.opaque,
                child: character,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BinsZone extends StatelessWidget {
  const _BinsZone({
    required this.round,
    required this.activity,
    required this.l10n,
    required this.viewport,
    required this.reduceMotion,
    required this.profile,
    required this.onAccept,
    required this.onTapBin,
  });

  final ColorSortingRound? round;
  final ColorSortingActivity activity;
  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
  final ColorSortingVisualProfile profile;
  final void Function(ColorToken) onAccept;
  final void Function(ColorToken) onTapBin;

  @override
  Widget build(BuildContext context) {
    if (round == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaled = HitboxScaler.scaleLength(
          ColorSortingConstants.designBinSize + 8,
          viewport: viewport,
          minLogical: HitboxScaler.minLogicalSize + 8,
        );
        final count = round!.bins.length;
        final widthBudget = (constraints.maxWidth - 8 * (count + 1)) / count;
        const zoneCaption = 24.0;
        final binCaption = profile.showBinLabels ? 18.0 : 0.0;
        final availableHeight =
            (constraints.maxHeight - zoneCaption).clamp(0.0, 400.0);
        final heightBudget =
            (availableHeight - binCaption).clamp(32.0, 200.0);
        final binSide = math
            .min(scaled, math.min(widthBudget, heightBudget))
            .clamp(32.0, 120.0);

        return Column(
          children: [
            Text(
              l10n.colorSortingBinsLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0277BD),
                  ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final bin in round!.bins)
                    _BinTarget(
                      key: ColorSortingPlayField.binKey(bin),
                      color: bin,
                      label: _colorLabel(l10n, bin),
                      size: binSide,
                      reduceMotion: reduceMotion,
                      profile: profile,
                      enabled: activity.interactionsEnabled,
                      highlighted: activity.hintLevel >= 2 &&
                          bin == round!.objectColor,
                      showLabel: profile.showBinLabels,
                      onAccept: onAccept,
                      onTap: () => onTapBin(bin),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BinTarget extends StatelessWidget {
  const _BinTarget({
    super.key,
    required this.color,
    required this.label,
    required this.size,
    required this.reduceMotion,
    required this.profile,
    required this.enabled,
    required this.highlighted,
    required this.showLabel,
    required this.onAccept,
    required this.onTap,
  });

  final ColorToken color;
  final String label;
  final double size;
  final bool reduceMotion;
  final ColorSortingVisualProfile profile;
  final bool enabled;
  final bool highlighted;
  final bool showLabel;
  final void Function(ColorToken) onAccept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${l10nBin(context)} $label. ${AppLocalizations.of(context).colorSortingTapOrDragHint}',
      child: DragTarget<ColorToken>(
        onWillAcceptWithDetails: (_) => enabled,
        onAcceptWithDetails: (details) => onAccept(color),
        builder: (context, candidate, rejected) {
          final glow = highlighted || candidate.isNotEmpty;
          Widget character = ColorSortingBinCharacter(
            color: color,
            size: size,
            profile: profile,
            highlighted: glow,
          );
          if (!reduceMotion && glow) {
            character = TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.97, end: 1.05),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: character,
            );
          }
          return GestureDetector(
            onTap: enabled ? onTap : null,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: size,
                  height: size * 0.92,
                  child: character,
                ),
                if (showLabel) ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 16,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF37474F),
                          ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String l10nBin(BuildContext context) =>
      AppLocalizations.of(context).colorSortingBinLabel;
}

class _FeedbackZone extends StatelessWidget {
  const _FeedbackZone({
    required this.l10n,
    required this.hintLevel,
    required this.showTryAgain,
    required this.showPraise,
    required this.praiseIndex,
  });

  final AppLocalizations l10n;
  final int hintLevel;
  final bool showTryAgain;
  final bool showPraise;
  final int praiseIndex;

  String get _praise {
    switch (praiseIndex % 3) {
      case 1:
        return l10n.colorSortingPraiseGreat;
      case 2:
        return l10n.colorSortingPraiseNice;
      default:
        return l10n.colorSortingPraiseAwesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: hintLevel > 0
              ? Text(
                  key: ColorSortingPlayField.hintKey,
                  l10n.colorSortingHintLevel(hintLevel),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF1565C0),
                        fontWeight: FontWeight.w700,
                      ),
                )
              : showTryAgain
                  ? Text(
                      key: ColorSortingPlayField.tryAgainKey,
                      l10n.colorSortingTryAgain,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFFEF6C00),
                            fontWeight: FontWeight.w700,
                          ),
                    )
                  : showPraise
                      ? Text(
                          key: ColorSortingPlayField.praiseKey,
                          _praise,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w800,
                                  ),
                        )
                      : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({
    required this.l10n,
    required this.viewport,
    required this.reduceMotion,
    required this.profile,
    required this.onReplay,
  });

  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
  final ColorSortingVisualProfile profile;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final mascotSize =
        HitboxScaler.scaleLength(120, viewport: viewport, minLogical: 88);
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              key: ColorSortingPlayField.completionKey,
              label: l10n.colorSortingPromptDone,
              child: ShapeMatchingBunnyMascot(
                profile: profile.asBunnyProfile,
                mood: BunnyMascotMood.complete,
                reduceMotion: reduceMotion,
                size: mascotSize,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.colorSortingPromptDone,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2E7D32),
                    shadows: const [
                      Shadow(color: Color(0x99FFFFFF), blurRadius: 8),
                    ],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.colorSortingPraiseAwesome,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF6A1B9A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: ColorSortingPlayField.replayKey,
              onPressed: onReplay,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: Text(l10n.colorSortingPlayAgain),
            ),
          ],
        ),
      ),
    );
  }
}

String _colorLabel(AppLocalizations l10n, ColorToken token) {
  switch (token) {
    case ColorToken.red:
      return l10n.colorSortingColorRed;
    case ColorToken.yellow:
      return l10n.colorSortingColorYellow;
    case ColorToken.blue:
      return l10n.colorSortingColorBlue;
    case ColorToken.green:
      return l10n.colorSortingColorGreen;
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/activity_session_controller.dart';
import '../game/hitbox_scaler.dart';
import '../game/scoring_neutral_outcome.dart';
import '../l10n/app_localizations.dart';
import 'shape_matching_activity.dart';
import 'shape_matching_bunny_mascot.dart';
import 'shape_matching_constants.dart';
import 'shape_matching_garden_scene.dart';
import 'shape_matching_logic.dart';
import 'shape_matching_shape_character.dart';
import 'shape_matching_visual_profile.dart';

/// Landscape play surface — Playful Learning Garden with drag-drop + tap (F-034).
class ShapeMatchingPlayField extends StatefulWidget {
  const ShapeMatchingPlayField({
    super.key,
    required this.activity,
    required this.controller,
    this.reduceMotion = false,
  });

  final ShapeMatchingActivity activity;
  final ActivitySessionController controller;
  final bool reduceMotion;

  static const Key fieldKey = Key('shape-matching-play-field');
  static const Key instructionZoneKey = Key('shape-matching-instruction-zone');
  static const Key targetZoneKey = Key('shape-matching-target-zone');
  static const Key choicesZoneKey = Key('shape-matching-choices-zone');
  static const Key feedbackZoneKey = Key('shape-matching-feedback-zone');
  static const Key targetKey = Key('shape-matching-target');
  static const Key promptKey = Key('shape-matching-prompt');
  static const Key completionKey = Key('shape-matching-completion');
  static const Key replayKey = Key('shape-matching-replay');
  static const Key hintKey = Key('shape-matching-hint');
  static const Key tryAgainKey = Key('shape-matching-try-again');
  static const Key praiseKey = Key('shape-matching-praise');

  static Key choiceKey(ShapeToken token) =>
      Key('shape-matching-choice-${token.name}');

  @override
  State<ShapeMatchingPlayField> createState() => _ShapeMatchingPlayFieldState();
}

class _ShapeMatchingPlayFieldState extends State<ShapeMatchingPlayField> {
  ShapeMatchingActivity get activity => widget.activity;
  ActivitySessionController get controller => widget.controller;
  bool get reduceMotion => widget.reduceMotion;

  BunnyMascotMood _mascotMood = BunnyMascotMood.idle;
  Timer? _moodTimer;
  /// Bumped on reset / activity replace so stale timers never mutate UI.
  var _moodEpoch = 0;
  var _praiseVisible = false;
  var _praiseIndex = 0;
  /// Last [ShapeMatchingActivity.correctMatchSerial] that triggered celebrate.
  var _celebratedMatchSerial = 0;

  @override
  void initState() {
    super.initState();
    _celebratedMatchSerial = activity.correctMatchSerial;
    activity.addListener(_onActivityChanged);
  }

  @override
  void didUpdateWidget(covariant ShapeMatchingPlayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != activity) {
      oldWidget.activity.removeListener(_onActivityChanged);
      _resetVisualFeedback();
      activity.addListener(_onActivityChanged);
      // Sync fields without setState — parent rebuild already schedules paint.
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

  /// Clears praise / mood / timers (replay, activity replace, child switch).
  void _resetVisualFeedback() {
    _cancelMoodTimer();
    _moodEpoch++;
    _mascotMood = BunnyMascotMood.idle;
    _praiseVisible = false;
    _praiseIndex = 0;
    _celebratedMatchSerial = activity.correctMatchSerial;
  }

  void _onActivityChanged() {
    if (!mounted) return;
    _syncMoodFromOutcome(notify: true);
  }

  void _syncMoodFromOutcome({required bool notify}) {
    final outcome = activity.lastOutcome;

    // Replay / progress reset — drop stale celebration before next round.
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
      if (outcome.cueKey == 'shape_match') {
        // Deterministic: one celebration per correctMatchSerial, not UI mood.
        // Survives rapid next-round picks and the duplicate notify from advance.
        final serial = activity.correctMatchSerial;
        if (serial > _celebratedMatchSerial) {
          _celebratedMatchSerial = serial;
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
    final profile = ShapeMatchingVisualProfile.forAgeMonths(
      activity.ageMonths > 0 ? activity.ageMonths : 36,
    );

    return LayoutBuilder(
      key: ShapeMatchingPlayField.fieldKey,
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            ShapeMatchingGardenScene(profile: profile),
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
                      key: ShapeMatchingPlayField.instructionZoneKey,
                      child: _InstructionZone(l10n: l10n, profile: profile),
                    ),
                    Expanded(
                      flex: 38,
                      child: KeyedSubtree(
                        key: ShapeMatchingPlayField.targetZoneKey,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ShapeMatchingBunnyMascot(
                              profile: profile,
                              mood: _mascotMood,
                              reduceMotion: reduceMotion,
                              size: math.min(viewport.shortestSide * 0.22, 110) *
                                  profile.mascotScale,
                            ),
                            Expanded(
                              child: _TargetZone(
                                round: round,
                                activity: activity,
                                l10n: l10n,
                                viewport: viewport,
                                reduceMotion: reduceMotion,
                                profile: profile,
                                onAccept: _handlePick,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 42,
                      child: KeyedSubtree(
                        key: ShapeMatchingPlayField.choicesZoneKey,
                        child: _ChoicesZone(
                          round: round,
                          activity: activity,
                          l10n: l10n,
                          viewport: viewport,
                          reduceMotion: reduceMotion,
                          profile: profile,
                          onPick: _handlePick,
                        ),
                      ),
                    ),
                    KeyedSubtree(
                      key: ShapeMatchingPlayField.feedbackZoneKey,
                      child: _FeedbackZone(
                        l10n: l10n,
                        hintLevel: activity.hintLevel,
                        showTryAgain: activity.lastOutcome is EncouragementOutcome &&
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

  void _handlePick(ShapeToken token) {
    activity.pickShape(token);
    final outcome = activity.lastOutcome;
    if (outcome is ActivityCompletedOutcome) {
      controller.reportOutcome(outcome);
    } else if (outcome is HintOfferedOutcome) {
      controller.reportOutcome(outcome);
    } else if (outcome is EncouragementOutcome) {
      controller.reportOutcome(outcome);
    }
  }
}

class _InstructionZone extends StatelessWidget {
  const _InstructionZone({required this.l10n, required this.profile});

  final AppLocalizations l10n;
  final ShapeMatchingVisualProfile profile;

  @override
  Widget build(BuildContext context) {
    final toddler = profile.band == ShapeMatchingVisualBand.toddler;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(
            key: ShapeMatchingPlayField.promptKey,
            l10n.shapeMatchingPromptMatch,
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
            l10n.shapeMatchingTapOrDragHint,
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

class _TargetZone extends StatelessWidget {
  const _TargetZone({
    required this.round,
    required this.activity,
    required this.l10n,
    required this.viewport,
    required this.reduceMotion,
    required this.profile,
    required this.onAccept,
  });

  final ShapeMatchingRound? round;
  final ShapeMatchingActivity activity;
  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
  final ShapeMatchingVisualProfile profile;
  final void Function(ShapeToken) onAccept;

  @override
  Widget build(BuildContext context) {
    if (round == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaled = HitboxScaler.scaleLength(
          ShapeMatchingConstants.designTargetSize + 8,
          viewport: viewport,
          minLogical: 72,
        );
        final maxByHeight = constraints.maxHeight - 28;
        final side = math.min(scaled, maxByHeight).clamp(72.0, 128.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.shapeMatchingTargetLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6A1B9A),
                  ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: DragTarget<ShapeToken>(
                    onWillAcceptWithDetails: (_) => activity.interactionsEnabled,
                    onAcceptWithDetails: (details) => onAccept(details.data),
                    builder: (context, candidate, rejected) {
                      final highlighted =
                          activity.hintLevel >= 1 || candidate.isNotEmpty;
                      return _TargetSilhouette(
                        key: ShapeMatchingPlayField.targetKey,
                        token: round!.target,
                        label: _shapeLabel(l10n, round!.target),
                        size: side,
                        highlighted: highlighted,
                        reduceMotion: reduceMotion,
                        profile: profile,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TargetSilhouette extends StatelessWidget {
  const _TargetSilhouette({
    super.key,
    required this.token,
    required this.label,
    required this.size,
    required this.highlighted,
    required this.reduceMotion,
    required this.profile,
  });

  final ShapeToken token;
  final String label;
  final double size;
  final bool highlighted;
  final bool reduceMotion;
  final ShapeMatchingVisualProfile profile;

  @override
  Widget build(BuildContext context) {
    Widget child = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.55 + profile.targetGlow * 0.15),
        boxShadow: [
          BoxShadow(
            color: (highlighted ? const Color(0xFFFFB300) : const Color(0xFF90CAF9))
                .withValues(alpha: 0.35 + profile.targetGlow * 0.2),
            blurRadius: highlighted ? 16 : 10,
            spreadRadius: highlighted ? 2 : 0,
          ),
        ],
      ),
      child: ShapeMatchingShapeCharacter(
        token: token,
        size: size,
        profile: profile,
        mood: ShapeCharacterMood.silhouette,
        highlighted: highlighted,
        showFace: profile.band != ShapeMatchingVisualBand.toddler,
      ),
    );

    if (!reduceMotion && highlighted) {
      child = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.97, end: 1.04),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, scale, c) => Transform.scale(scale: scale, child: c),
        child: child,
      );
    }

    return Semantics(
      label: label,
      button: false,
      child: child,
    );
  }
}

class _ChoicesZone extends StatelessWidget {
  const _ChoicesZone({
    required this.round,
    required this.activity,
    required this.l10n,
    required this.viewport,
    required this.reduceMotion,
    required this.profile,
    required this.onPick,
  });

  final ShapeMatchingRound? round;
  final ShapeMatchingActivity activity;
  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
  final ShapeMatchingVisualProfile profile;
  final void Function(ShapeToken) onPick;

  @override
  Widget build(BuildContext context) {
    if (round == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaled = HitboxScaler.scaleLength(
          ShapeMatchingConstants.designSlotSize + 8,
          viewport: viewport,
          minLogical: HitboxScaler.minLogicalSize + 8,
        );
        final count = round!.choices.length;
        final widthBudget = (constraints.maxWidth - 8 * (count + 1)) / count;
        // Reserve vertical room for the zone caption and optional per-choice labels
        // so the character tile never overflows the Row (F-034 short landscape).
        const zoneCaption = 24.0;
        final choiceCaption = profile.showChoiceLabels ? 18.0 : 0.0;
        final availableHeight =
            (constraints.maxHeight - zoneCaption).clamp(0.0, 400.0);
        final heightBudget =
            (availableHeight - choiceCaption).clamp(32.0, 200.0);
        final choiceSide = math
            .min(scaled, math.min(widthBudget, heightBudget))
            .clamp(32.0, 120.0);
        return Column(
          children: [
            Text(
              l10n.shapeMatchingChoicesLabel,
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
                  for (final token in round!.choices)
                    _DraggableShapeChoice(
                      key: ShapeMatchingPlayField.choiceKey(token),
                      token: token,
                      label: _shapeLabel(l10n, token),
                      size: choiceSide,
                      reduceMotion: reduceMotion,
                      profile: profile,
                      enabled: activity.interactionsEnabled,
                      highlighted:
                          activity.hintLevel >= 2 && token == round!.target,
                      showLabel: profile.showChoiceLabels,
                      onPick: () => onPick(token),
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
        return l10n.shapeMatchingPraiseGreat;
      case 2:
        return l10n.shapeMatchingPraiseNice;
      default:
        return l10n.shapeMatchingPraiseAwesome;
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
                  key: ShapeMatchingPlayField.hintKey,
                  l10n.shapeMatchingHintLevel(hintLevel),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF1565C0),
                        fontWeight: FontWeight.w700,
                      ),
                )
              : showTryAgain
                  ? Text(
                      key: ShapeMatchingPlayField.tryAgainKey,
                      l10n.shapeMatchingTryAgain,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFFEF6C00),
                            fontWeight: FontWeight.w700,
                          ),
                    )
                  : showPraise
                      ? Text(
                          key: ShapeMatchingPlayField.praiseKey,
                          _praise,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
  final ShapeMatchingVisualProfile profile;
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
              key: ShapeMatchingPlayField.completionKey,
              label: l10n.shapeMatchingPromptDone,
              child: ShapeMatchingBunnyMascot(
                profile: profile,
                mood: BunnyMascotMood.complete,
                reduceMotion: reduceMotion,
                size: mascotSize,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.shapeMatchingPromptDone,
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
              l10n.shapeMatchingPraiseAwesome,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF6A1B9A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: ShapeMatchingPlayField.replayKey,
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
              label: Text(l10n.shapeMatchingPlayAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableShapeChoice extends StatelessWidget {
  const _DraggableShapeChoice({
    super.key,
    required this.token,
    required this.label,
    required this.size,
    required this.onPick,
    required this.enabled,
    required this.highlighted,
    required this.reduceMotion,
    required this.profile,
    required this.showLabel,
  });

  final ShapeToken token;
  final String label;
  final double size;
  final VoidCallback onPick;
  final bool enabled;
  final bool highlighted;
  final bool reduceMotion;
  final ShapeMatchingVisualProfile profile;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final card = _ChoiceCard(
      token: token,
      label: label,
      size: size,
      highlighted: highlighted,
      reduceMotion: reduceMotion,
      profile: profile,
      enabled: enabled,
      showLabel: showLabel,
      lifted: false,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label:
          '$label. ${AppLocalizations.of(context).shapeMatchingTapOrDragHint}',
      child: Draggable<ShapeToken>(
        data: token,
        maxSimultaneousDrags: enabled ? 1 : 0,
        feedback: Material(
          color: Colors.transparent,
          child: ShapeMatchingShapeCharacter(
            token: token,
            size: size,
            profile: profile,
            mood: ShapeCharacterMood.excited,
            highlighted: true,
            lifted: true,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.28,
          child: ShapeMatchingShapeCharacter(
            token: token,
            size: size,
            profile: profile,
            mood: ShapeCharacterMood.silhouette,
            showFace: false,
          ),
        ),
        child: GestureDetector(
          onTap: enabled ? onPick : null,
          behavior: HitTestBehavior.opaque,
          child: card,
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.token,
    required this.label,
    required this.size,
    required this.highlighted,
    required this.reduceMotion,
    required this.profile,
    required this.enabled,
    required this.showLabel,
    required this.lifted,
  });

  final ShapeToken token;
  final String label;
  final double size;
  final bool highlighted;
  final bool reduceMotion;
  final ShapeMatchingVisualProfile profile;
  final bool enabled;
  final bool showLabel;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelReserve = showLabel ? 18.0 : 0.0;
        final side = math
            .min(size, math.max(24.0, constraints.maxHeight - labelReserve))
            .clamp(24.0, size);
        Widget character = ShapeMatchingShapeCharacter(
          token: token,
          size: side,
          profile: profile,
          mood: highlighted ? ShapeCharacterMood.happy : ShapeCharacterMood.idle,
          highlighted: highlighted,
          lifted: lifted,
        );

        if (!reduceMotion && highlighted) {
          character = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.97, end: 1.05),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: character,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: side, height: side, child: character),
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
        );
      },
    );
  }
}

String _shapeLabel(AppLocalizations l10n, ShapeToken token) {
  switch (token) {
    case ShapeToken.circle:
      return l10n.shapeMatchingShapeCircle;
    case ShapeToken.square:
      return l10n.shapeMatchingShapeSquare;
    case ShapeToken.triangle:
      return l10n.shapeMatchingShapeTriangle;
    case ShapeToken.star:
      return l10n.shapeMatchingShapeStar;
    case ShapeToken.hexagon:
      return l10n.shapeMatchingShapeHexagon;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/activity_session_controller.dart';
import '../game/hitbox_scaler.dart';
import '../game/scoring_neutral_outcome.dart';
import '../l10n/app_localizations.dart';
import 'shape_matching_activity.dart';
import 'shape_matching_constants.dart';
import 'shape_matching_logic.dart';

/// Landscape play surface — drag-drop plus tap alternative (F-034 / ≥44dp).
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

  static Key choiceKey(ShapeToken token) =>
      Key('shape-matching-choice-${token.name}');

  @override
  State<ShapeMatchingPlayField> createState() => _ShapeMatchingPlayFieldState();
}

class _ShapeMatchingPlayFieldState extends State<ShapeMatchingPlayField> {
  ShapeMatchingActivity get activity => widget.activity;
  ActivitySessionController get controller => widget.controller;
  bool get reduceMotion => widget.reduceMotion;

  @override
  void initState() {
    super.initState();
    activity.addListener(_onActivityChanged);
  }

  @override
  void didUpdateWidget(covariant ShapeMatchingPlayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != activity) {
      oldWidget.activity.removeListener(_onActivityChanged);
      activity.addListener(_onActivityChanged);
    }
  }

  @override
  void dispose() {
    activity.removeListener(_onActivityChanged);
    super.dispose();
  }

  void _onActivityChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final round = activity.round;
    final completed = activity.lastOutcome is ActivityCompletedOutcome;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;

    return LayoutBuilder(
      key: ShapeMatchingPlayField.fieldKey,
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);

        if (completed) {
          return _CompletionPanel(
            l10n: l10n,
            viewport: viewport,
            reduceMotion: reduceMotion,
            onReplay: () {
              // ignore: discarded_futures
              controller.restart();
            },
          );
        }

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF9C4),
                Color(0xFFE1F5FE),
                Color(0xFFC8E6C9),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 8 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: ShapeMatchingPlayField.instructionZoneKey,
                  child: _InstructionZone(l10n: l10n),
                ),
                Expanded(
                  flex: 38,
                  child: KeyedSubtree(
                    key: ShapeMatchingPlayField.targetZoneKey,
                    child: _TargetZone(
                      round: round,
                      activity: activity,
                      l10n: l10n,
                      viewport: viewport,
                      reduceMotion: reduceMotion,
                      onAccept: _handlePick,
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
                        (activity.lastOutcome as EncouragementOutcome).cueKey ==
                            'try_again',
                  ),
                ),
              ],
            ),
          ),
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
  const _InstructionZone({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.shapeMatchingTapOrDragHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF455A64),
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
    required this.onAccept,
  });

  final ShapeMatchingRound? round;
  final ShapeMatchingActivity activity;
  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
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
                    fontWeight: FontWeight.w600,
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
                      return _ShapeCard(
                        key: ShapeMatchingPlayField.targetKey,
                        token: round!.target,
                        label: _shapeLabel(l10n, round!.target),
                        size: side,
                        isTarget: true,
                        highlighted:
                            activity.hintLevel >= 1 || candidate.isNotEmpty,
                        reduceMotion: reduceMotion,
                        enabled: false,
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

class _ChoicesZone extends StatelessWidget {
  const _ChoicesZone({
    required this.round,
    required this.activity,
    required this.l10n,
    required this.viewport,
    required this.reduceMotion,
    required this.onPick,
  });

  final ShapeMatchingRound? round;
  final ShapeMatchingActivity activity;
  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
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
        final heightBudget = constraints.maxHeight - 28;
        final choiceSide = math
            .min(scaled, math.min(widthBudget, heightBudget))
            .clamp(52.0, 120.0);
        return Column(
          children: [
            Text(
              l10n.shapeMatchingChoicesLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
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
                      enabled: activity.interactionsEnabled,
                      highlighted:
                          activity.hintLevel >= 2 && token == round!.target,
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
  });

  final AppLocalizations l10n;
  final int hintLevel;
  final bool showTryAgain;

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
                        fontWeight: FontWeight.w600,
                      ),
                )
              : showTryAgain
                  ? Text(
                      key: ShapeMatchingPlayField.tryAgainKey,
                      l10n.shapeMatchingTryAgain,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFFEF6C00),
                            fontWeight: FontWeight.w600,
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
    required this.onReplay,
  });

  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final iconSize = HitboxScaler.scaleLength(88, viewport: viewport, minLogical: 64);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFFFFDE7)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              key: ShapeMatchingPlayField.completionKey,
              label: l10n.shapeMatchingPromptDone,
              child: Icon(
                Icons.emoji_events_rounded,
                size: iconSize,
                color: const Color(0xFFFFB300),
                shadows: const [
                  Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.shapeMatchingPromptDone,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2E7D32),
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: ShapeMatchingPlayField.replayKey,
              onPressed: onReplay,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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

class _ShapeCard extends StatelessWidget {
  const _ShapeCard({
    super.key,
    required this.token,
    required this.label,
    required this.size,
    required this.isTarget,
    required this.highlighted,
    required this.reduceMotion,
    required this.enabled,
  });

  final ShapeToken token;
  final String label;
  final double size;
  final bool isTarget;
  final bool highlighted;
  final bool reduceMotion;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: isTarget
              ? const Color(0xFFFFB300)
              : highlighted
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFF90CAF9),
          width: isTarget ? 4 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isTarget ? 0.18 : 0.12),
            blurRadius: isTarget ? 14 : 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _ShapePainterDelegate(
          token: token,
          highlighted: highlighted || isTarget,
        ),
        child: Semantics(
          label: label,
          button: enabled,
          enabled: enabled,
          child: const SizedBox.expand(),
        ),
      ),
    );

    if (!reduceMotion && (highlighted || isTarget)) {
      card = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.97, end: 1.03),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: card,
      );
    }
    return card;
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
  });

  final ShapeToken token;
  final String label;
  final double size;
  final VoidCallback onPick;
  final bool enabled;
  final bool highlighted;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final card = _ShapeCard(
      token: token,
      label: label,
      size: size,
      isTarget: false,
      highlighted: highlighted,
      reduceMotion: reduceMotion,
      enabled: enabled,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. ${AppLocalizations.of(context).shapeMatchingTapOrDragHint}',
      child: Draggable<ShapeToken>(
        data: token,
        maxSimultaneousDrags: enabled ? 1 : 0,
        feedback: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _ShapePainterDelegate(token: token, highlighted: true),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: GestureDetector(
          onTap: enabled ? onPick : null,
          behavior: HitTestBehavior.opaque,
          child: card,
        ),
      ),
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

class _ShapePainterDelegate extends CustomPainter {
  _ShapePainterDelegate({required this.token, required this.highlighted});

  final ShapeToken token;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = highlighted ? const Color(0xFF81C784) : const Color(0xFF64B5F6)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF1A237E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final center = rect.center;
    switch (token) {
      case ShapeToken.circle:
        canvas.drawOval(rect.deflate(4), fill);
        canvas.drawOval(rect.deflate(4), stroke);
      case ShapeToken.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(10)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(10)),
          stroke,
        );
      case ShapeToken.triangle:
        final path = Path()
          ..moveTo(center.dx, rect.top + 4)
          ..lineTo(rect.right - 4, rect.bottom - 4)
          ..lineTo(rect.left + 4, rect.bottom - 4)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case ShapeToken.star:
        _drawStar(canvas, center, rect.shortestSide / 2 - 4, fill, stroke);
      case ShapeToken.hexagon:
        _drawHex(canvas, center, rect.shortestSide / 2 - 4, fill, stroke);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint fill, Paint stroke) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = (i * math.pi / points) - math.pi / 2;
      final pt = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawHex(Canvas canvas, Offset center, double radius, Paint fill, Paint stroke) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final pt = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _ShapePainterDelegate oldDelegate) {
    return oldDelegate.token != token || oldDelegate.highlighted != highlighted;
  }
}

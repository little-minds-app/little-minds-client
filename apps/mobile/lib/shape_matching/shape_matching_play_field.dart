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
class ShapeMatchingPlayField extends StatelessWidget {
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
  static const Key targetKey = Key('shape-matching-target');
  static const Key promptKey = Key('shape-matching-prompt');
  static const Key completionKey = Key('shape-matching-completion');
  static const Key hintKey = Key('shape-matching-hint');
  static const Key audioNoticeKey = Key('shape-matching-audio-notice');

  static Key choiceKey(ShapeToken token) => Key('shape-matching-choice-${token.name}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final round = activity.round;
    final completed = activity.lastOutcome is ActivityCompletedOutcome;

    return LayoutBuilder(
      key: fieldKey,
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final targetRect = HitboxScaler.scaleRect(
          const Rect.fromLTWH(340, 40, 120, 120),
          viewport: viewport,
        );

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8F5E9), Color(0xFFE3F2FD)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Text(
                      key: promptKey,
                      completed
                          ? l10n.shapeMatchingPromptDone
                          : l10n.shapeMatchingPromptMatch,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (!activity.audioReady && !completed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          key: audioNoticeKey,
                          l10n.shapeMatchingVisualOnlyAudio,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.black54,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              if (round != null && !completed)
                Positioned.fromRect(
                  rect: targetRect,
                  child: DragTarget<ShapeToken>(
                    onWillAcceptWithDetails: (_) => activity.interactionsEnabled,
                    onAcceptWithDetails: (details) => _handlePick(details.data),
                    builder: (context, candidate, rejected) {
                      return _ShapeTile(
                        key: targetKey,
                        token: round.target,
                        label: _shapeLabel(l10n, round.target),
                        highlighted: activity.hintLevel >= 1 ||
                            candidate.isNotEmpty,
                        reduceMotion: reduceMotion,
                        enabled: false,
                      );
                    },
                  ),
                ),
              if (completed)
                Center(
                  child: Semantics(
                    key: completionKey,
                    label: l10n.shapeMatchingPromptDone,
                    child: Icon(
                      Icons.check_circle_outline,
                      size: HitboxScaler.scaleLength(
                        ShapeMatchingConstants.designTargetSize,
                        viewport: viewport,
                      ),
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              if (round != null && !completed)
                ..._choicePositions(round.choices.length).asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final designCenter = entry.value;
                    final token = round.choices[index];
                    final rect = HitboxScaler.scaleRect(
                      Rect.fromCenter(
                        center: designCenter,
                        width: ShapeMatchingConstants.designSlotSize,
                        height: ShapeMatchingConstants.designSlotSize,
                      ),
                      viewport: viewport,
                    );
                    return Positioned.fromRect(
                      rect: rect,
                      child: _DraggableShapeChoice(
                        key: choiceKey(token),
                        token: token,
                        label: _shapeLabel(l10n, token),
                        viewport: viewport,
                        reduceMotion: reduceMotion,
                        enabled: activity.interactionsEnabled,
                        highlighted: activity.hintLevel >= 2 &&
                            token == round.target,
                        onPick: () => _handlePick(token),
                      ),
                    );
                  },
                ),
              if (activity.hintLevel > 0 && !completed)
                Positioned(
                  bottom: 8,
                  left: 16,
                  right: 16,
                  child: Text(
                    key: hintKey,
                    l10n.shapeMatchingHintLevel(activity.hintLevel),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF1565C0),
                        ),
                  ),
                ),
            ],
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

  static List<Offset> _choicePositions(int count) {
    const y = 320.0;
    if (count <= 2) {
      return const [Offset(220, y), Offset(580, y)];
    }
    if (count == 3) {
      return const [Offset(160, y), Offset(400, y), Offset(640, y)];
    }
    if (count == 4) {
      return const [
        Offset(120, y),
        Offset(320, y),
        Offset(520, y),
        Offset(720, y),
      ];
    }
    return const [
      Offset(80, y),
      Offset(240, y),
      Offset(400, y),
      Offset(560, y),
      Offset(720, y),
    ];
  }

  static String _shapeLabel(AppLocalizations l10n, ShapeToken token) {
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
}

class _ShapeTile extends StatelessWidget {
  const _ShapeTile({
    super.key,
    required this.token,
    required this.label,
    required this.highlighted,
    required this.reduceMotion,
    required this.enabled,
  });

  final ShapeToken token;
  final String label;
  final bool highlighted;
  final bool reduceMotion;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final child = CustomPaint(
      painter: _ShapePainterDelegate(token: token, highlighted: highlighted),
      child: Semantics(
        label: label,
        button: enabled,
        enabled: enabled,
        child: const SizedBox.expand(),
      ),
    );
    if (reduceMotion || !highlighted) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.05),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      onEnd: () {},
      child: child,
    );
  }
}

class _DraggableShapeChoice extends StatelessWidget {
  const _DraggableShapeChoice({
    super.key,
    required this.token,
    required this.label,
    required this.viewport,
    required this.onPick,
    required this.enabled,
    required this.highlighted,
    required this.reduceMotion,
  });

  final ShapeToken token;
  final String label;
  final Size viewport;
  final VoidCallback onPick;
  final bool enabled;
  final bool highlighted;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tile = _ShapeTile(
      token: token,
      label: label,
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
          child: SizedBox(
            width: HitboxScaler.scaleLength(
              ShapeMatchingConstants.designObjectSize,
              viewport: viewport,
            ),
            height: HitboxScaler.scaleLength(
              ShapeMatchingConstants.designObjectSize,
              viewport: viewport,
            ),
            child: CustomPaint(
              painter: _ShapePainterDelegate(token: token, highlighted: true),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: tile),
        child: GestureDetector(
          onTap: enabled ? onPick : null,
          behavior: HitTestBehavior.opaque,
          child: tile,
        ),
      ),
    );
  }
}

class _ShapePainterDelegate extends CustomPainter {
  _ShapePainterDelegate({required this.token, required this.highlighted});

  final ShapeToken token;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = highlighted ? const Color(0xFF66BB6A) : const Color(0xFF90CAF9)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final center = rect.center;
    switch (token) {
      case ShapeToken.circle:
        canvas.drawOval(rect.deflate(4), fill);
        canvas.drawOval(rect.deflate(4), stroke);
      case ShapeToken.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(8)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(8)),
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
      final angle = (i * 3.141592653589793 / points) - 1.5707963267948966;
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
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
      final angle = i * 3.141592653589793 / 3;
      final pt = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
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

  double cos(double v) => math.cos(v);
  double sin(double v) => math.sin(v);

  @override
  bool shouldRepaint(covariant _ShapePainterDelegate oldDelegate) {
    return oldDelegate.token != token || oldDelegate.highlighted != highlighted;
  }
}

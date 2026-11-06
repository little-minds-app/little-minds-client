import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shape_matching_logic.dart';
import 'shape_matching_visual_profile.dart';

/// Friendly geometric character with a simple face — original Little Minds art.
enum ShapeCharacterMood {
  idle,
  happy,
  excited,
  silhouette,
}

class ShapeMatchingShapeCharacter extends StatelessWidget {
  const ShapeMatchingShapeCharacter({
    super.key,
    required this.token,
    required this.size,
    required this.profile,
    this.mood = ShapeCharacterMood.idle,
    this.highlighted = false,
    this.lifted = false,
    this.showFace = true,
  });

  final ShapeToken token;
  final double size;
  final ShapeMatchingVisualProfile profile;
  final ShapeCharacterMood mood;
  final bool highlighted;
  final bool lifted;
  final bool showFace;

  static Key characterKey(ShapeToken token) =>
      Key('shape-matching-character-${token.name}');

  static Color fillFor(ShapeToken token) {
    switch (token) {
      case ShapeToken.circle:
        return const Color(0xFF4FC3F7);
      case ShapeToken.square:
        return const Color(0xFFFFB74D);
      case ShapeToken.triangle:
        return const Color(0xFF81C784);
      case ShapeToken.star:
        return const Color(0xFFFF8A65);
      case ShapeToken.hexagon:
        return const Color(0xFFBA68C8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = lifted ? profile.dragLiftScale : 1.0;
    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: lifted ? -0.06 : 0,
        child: CustomPaint(
          key: characterKey(token),
          size: Size.square(size),
          painter: ShapeCharacterPainter(
            token: token,
            mood: mood,
            highlighted: highlighted,
            faceScale: profile.faceScale,
            showFace: showFace,
            elevated: lifted,
          ),
        ),
      ),
    );
  }
}

class ShapeCharacterPainter extends CustomPainter {
  ShapeCharacterPainter({
    required this.token,
    required this.mood,
    required this.highlighted,
    required this.faceScale,
    required this.showFace,
    required this.elevated,
  });

  final ShapeToken token;
  final ShapeCharacterMood mood;
  final bool highlighted;
  final double faceScale;
  final bool showFace;
  final bool elevated;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.shortestSide * 0.08;
    final bounds = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);

    if (elevated) {
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bounds.center.dx + 2, bounds.bottom + 4),
          width: bounds.width * 0.7,
          height: bounds.height * 0.18,
        ),
        shadow,
      );
    }

    final path = _shapePath(bounds);
    if (mood == ShapeCharacterMood.silhouette) {
      final dashFill = Paint()
        ..color = const Color(0xFF90CAF9).withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, dashFill);
      final outline = Paint()
        ..color = highlighted ? const Color(0xFFFFB300) : const Color(0xFF546E7A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 4.5 : 3.2
        ..strokeCap = StrokeCap.round;
      _drawDashedPath(canvas, path, outline);
      if (showFace) {
        _paintFace(canvas, bounds, subtle: true);
      }
      return;
    }

    final fillColor = ShapeMatchingShapeCharacter.fillFor(token);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(fillColor, Colors.white, 0.22)!,
          fillColor,
          Color.lerp(fillColor, const Color(0xFF37474F), 0.12)!,
        ],
      ).createShader(bounds);
    canvas.drawPath(path, fill);

    final stroke = Paint()
      ..color = highlighted ? const Color(0xFF2E7D32) : const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 4 : 3;
    canvas.drawPath(path, stroke);

    // Soft inner highlight
    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(
      Offset(bounds.left + bounds.width * 0.32, bounds.top + bounds.height * 0.3),
      bounds.shortestSide * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.restore();

    if (showFace) {
      _paintFace(canvas, bounds, subtle: false);
    }
  }

  Path _shapePath(Rect bounds) {
    final center = bounds.center;
    switch (token) {
      case ShapeToken.circle:
        return Path()..addOval(bounds.deflate(2));
      case ShapeToken.square:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(bounds.deflate(2), Radius.circular(bounds.width * 0.16)),
          );
      case ShapeToken.triangle:
        return Path()
          ..moveTo(center.dx, bounds.top + 4)
          ..lineTo(bounds.right - 4, bounds.bottom - 4)
          ..lineTo(bounds.left + 4, bounds.bottom - 4)
          ..close();
      case ShapeToken.star:
        return _starPath(center, bounds.shortestSide / 2 - 3);
      case ShapeToken.hexagon:
        return _hexPath(center, bounds.shortestSide / 2 - 3);
    }
  }

  Path _starPath(Offset center, double radius) {
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
    return path;
  }

  Path _hexPath(Offset center, double radius) {
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
    return path;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 7.0;
      const gap = 5.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  void _paintFace(Canvas canvas, Rect bounds, {required bool subtle}) {
    final cx = bounds.center.dx;
    final cy = bounds.center.dy + bounds.height * 0.02;
    final eyeR = bounds.shortestSide * 0.065 * faceScale;
    final eyeY = cy - bounds.height * 0.06;
    final eyeDx = bounds.width * 0.14 * faceScale;
    final alpha = subtle ? 0.35 : 1.0;

    final eyeWhite = Paint()..color = Colors.white.withValues(alpha: alpha);
    final pupil = Paint()..color = const Color(0xFF263238).withValues(alpha: alpha);
    final cheek = Paint()
      ..color = const Color(0xFFFFAB91).withValues(alpha: subtle ? 0.25 : 0.55);

    canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, eyeWhite);
    canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, eyeWhite);

    final look = mood == ShapeCharacterMood.excited ? -eyeR * 0.15 : 0.0;
    canvas.drawCircle(Offset(cx - eyeDx + look, eyeY + eyeR * 0.1), eyeR * 0.45, pupil);
    canvas.drawCircle(Offset(cx + eyeDx + look, eyeY + eyeR * 0.1), eyeR * 0.45, pupil);

    canvas.drawCircle(Offset(cx - eyeDx * 1.55, cy + eyeR * 0.8), eyeR * 0.55, cheek);
    canvas.drawCircle(Offset(cx + eyeDx * 1.55, cy + eyeR * 0.8), eyeR * 0.55, cheek);

    final mouthPaint = Paint()
      ..color = const Color(0xFF37474F).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, eyeR * 0.35)
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();
    final mouthY = cy + bounds.height * 0.14;
    if (mood == ShapeCharacterMood.happy || mood == ShapeCharacterMood.excited) {
      mouthPath
        ..moveTo(cx - eyeDx * 0.7, mouthY)
        ..quadraticBezierTo(cx, mouthY + eyeR * 1.4, cx + eyeDx * 0.7, mouthY);
    } else {
      mouthPath
        ..moveTo(cx - eyeDx * 0.55, mouthY + eyeR * 0.2)
        ..quadraticBezierTo(cx, mouthY + eyeR * 0.85, cx + eyeDx * 0.55, mouthY + eyeR * 0.2);
    }
    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant ShapeCharacterPainter oldDelegate) {
    return oldDelegate.token != token ||
        oldDelegate.mood != mood ||
        oldDelegate.highlighted != highlighted ||
        oldDelegate.faceScale != faceScale ||
        oldDelegate.showFace != showFace ||
        oldDelegate.elevated != elevated;
  }
}

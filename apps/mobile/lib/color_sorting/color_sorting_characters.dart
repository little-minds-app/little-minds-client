import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'color_sorting_logic.dart';
import 'color_sorting_visual_profile.dart';

/// Palette + pattern for accessibility (never color-only correctness).
abstract final class ColorSortingPalette {
  static Color fill(ColorToken token) => switch (token) {
        ColorToken.red => const Color(0xFFE53935),
        ColorToken.yellow => const Color(0xFFFDD835),
        ColorToken.blue => const Color(0xFF1E88E5),
        ColorToken.green => const Color(0xFF43A047),
      };

  static Color deep(ColorToken token) => switch (token) {
        ColorToken.red => const Color(0xFFB71C1C),
        ColorToken.yellow => const Color(0xFFF9A825),
        ColorToken.blue => const Color(0xFF0D47A1),
        ColorToken.green => const Color(0xFF1B5E20),
      };

  /// Distinct hatch / motif so correctness is not color-only.
  static ColorSortingPattern pattern(ColorToken token) => switch (token) {
        ColorToken.red => ColorSortingPattern.stripes,
        ColorToken.yellow => ColorSortingPattern.dots,
        ColorToken.blue => ColorSortingPattern.waves,
        ColorToken.green => ColorSortingPattern.leaves,
      };
}

enum ColorSortingPattern { stripes, dots, waves, leaves }

/// Friendly colored object with face + pattern.
class ColorSortingObjectCharacter extends StatelessWidget {
  const ColorSortingObjectCharacter({
    super.key,
    required this.color,
    required this.form,
    required this.size,
    required this.profile,
    this.highlighted = false,
    this.lifted = false,
  });

  final ColorToken color;
  final SortObjectForm form;
  final double size;
  final ColorSortingVisualProfile profile;
  final bool highlighted;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final scale = lifted ? profile.dragLiftScale : 1.0;
    return Transform.scale(
      scale: scale,
      child: CustomPaint(
        size: Size.square(size),
        painter: _ObjectPainter(
          color: color,
          form: form,
          faceScale: profile.faceScale,
          highlighted: highlighted,
        ),
      ),
    );
  }
}

class _ObjectPainter extends CustomPainter {
  _ObjectPainter({
    required this.color,
    required this.form,
    required this.faceScale,
    required this.highlighted,
  });

  final ColorToken color;
  final SortObjectForm form;
  final double faceScale;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = ColorSortingPalette.fill(color);
    final outline = Paint()
      ..color = ColorSortingPalette.deep(color).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.045;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.42;

    switch (form) {
      case SortObjectForm.ball:
        canvas.drawCircle(center, r, fill);
        canvas.drawCircle(center, r, outline);
      case SortObjectForm.block:
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: r * 1.7, height: r * 1.7),
          Radius.circular(r * 0.28),
        );
        canvas.drawRRect(rect, fill);
        canvas.drawRRect(rect, outline);
      case SortObjectForm.flower:
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5 - math.pi / 2;
          final petal = Offset(
            center.dx + math.cos(a) * r * 0.55,
            center.dy + math.sin(a) * r * 0.55,
          );
          canvas.drawCircle(petal, r * 0.38, fill);
          canvas.drawCircle(petal, r * 0.38, outline);
        }
        canvas.drawCircle(center, r * 0.32, Paint()..color = Colors.white);
        canvas.drawCircle(center, r * 0.32, outline);
      case SortObjectForm.apple:
        final path = Path()
          ..moveTo(center.dx, center.dy + r * 0.85)
          ..cubicTo(
            center.dx + r * 1.05,
            center.dy + r * 0.35,
            center.dx + r * 0.95,
            center.dy - r * 0.55,
            center.dx,
            center.dy - r * 0.35,
          )
          ..cubicTo(
            center.dx - r * 0.95,
            center.dy - r * 0.55,
            center.dx - r * 1.05,
            center.dy + r * 0.35,
            center.dx,
            center.dy + r * 0.85,
          );
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
        canvas.drawLine(
          Offset(center.dx, center.dy - r * 0.2),
          Offset(center.dx + r * 0.15, center.dy - r * 0.75),
          outline..strokeWidth = size.shortestSide * 0.05,
        );
    }

    _paintPattern(canvas, size, center, r * 0.9);
    _paintFace(canvas, size, center, r);

    if (highlighted) {
      canvas.drawCircle(
        center,
        r * 1.15,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.05,
      );
    }
  }

  void _paintPattern(Canvas canvas, Size size, Offset center, double r) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = size.shortestSide * 0.035
      ..style = PaintingStyle.stroke;
    switch (ColorSortingPalette.pattern(color)) {
      case ColorSortingPattern.stripes:
        for (var i = -2; i <= 2; i++) {
          final x = center.dx + i * r * 0.28;
          canvas.drawLine(
            Offset(x, center.dy - r * 0.55),
            Offset(x, center.dy + r * 0.55),
            paint,
          );
        }
      case ColorSortingPattern.dots:
        for (final o in [
          Offset(-0.35, -0.25),
          Offset(0.3, -0.2),
          Offset(-0.2, 0.3),
          Offset(0.25, 0.28),
        ]) {
          canvas.drawCircle(
            center + Offset(o.dx * r, o.dy * r),
            r * 0.08,
            Paint()..color = Colors.white.withValues(alpha: 0.55),
          );
        }
      case ColorSortingPattern.waves:
        final path = Path();
        for (var i = 0; i < 3; i++) {
          final y = center.dy - r * 0.35 + i * r * 0.3;
          path.moveTo(center.dx - r * 0.55, y);
          path.quadraticBezierTo(
            center.dx,
            y - r * 0.12,
            center.dx + r * 0.55,
            y,
          );
        }
        canvas.drawPath(path, paint);
      case ColorSortingPattern.leaves:
        for (var i = 0; i < 3; i++) {
          final a = -0.6 + i * 0.6;
          final tip = Offset(
            center.dx + math.cos(a) * r * 0.5,
            center.dy + math.sin(a) * r * 0.5 - r * 0.1,
          );
          canvas.drawOval(
            Rect.fromCenter(center: tip, width: r * 0.28, height: r * 0.14),
            Paint()..color = Colors.white.withValues(alpha: 0.5),
          );
        }
    }
  }

  void _paintFace(Canvas canvas, Size size, Offset center, double r) {
    final eyeR = r * 0.09 * faceScale;
    final eyeY = center.dy - r * 0.08;
    final eyePaint = Paint()..color = const Color(0xFF263238);
    canvas.drawCircle(Offset(center.dx - r * 0.22, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(center.dx + r * 0.22, eyeY), eyeR, eyePaint);
    canvas.drawCircle(
      Offset(center.dx - r * 0.22 + eyeR * 0.35, eyeY - eyeR * 0.35),
      eyeR * 0.35,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(center.dx + r * 0.22 + eyeR * 0.35, eyeY - eyeR * 0.35),
      eyeR * 0.35,
      Paint()..color = Colors.white,
    );
    final smile = Path()
      ..moveTo(center.dx - r * 0.2, center.dy + r * 0.22)
      ..quadraticBezierTo(
        center.dx,
        center.dy + r * 0.38 * faceScale,
        center.dx + r * 0.2,
        center.dy + r * 0.22,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xFF263238)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.035
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ObjectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.form != form ||
        oldDelegate.faceScale != faceScale ||
        oldDelegate.highlighted != highlighted;
  }
}

/// Destination basket/bin with matching color + pattern.
class ColorSortingBinCharacter extends StatelessWidget {
  const ColorSortingBinCharacter({
    super.key,
    required this.color,
    required this.size,
    required this.profile,
    this.highlighted = false,
    this.silhouette = false,
  });

  final ColorToken color;
  final double size;
  final ColorSortingVisualProfile profile;
  final bool highlighted;
  final bool silhouette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.92),
      painter: _BinPainter(
        color: color,
        highlighted: highlighted,
        silhouette: silhouette,
        glow: profile.binGlow,
      ),
    );
  }
}

class _BinPainter extends CustomPainter {
  _BinPainter({
    required this.color,
    required this.highlighted,
    required this.silhouette,
    required this.glow,
  });

  final ColorToken color;
  final bool highlighted;
  final bool silhouette;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fillColor = silhouette
        ? ColorSortingPalette.fill(color).withValues(alpha: 0.35)
        : ColorSortingPalette.fill(color);
    final deep = ColorSortingPalette.deep(color);

    final rim = Path()
      ..moveTo(w * 0.08, h * 0.28)
      ..lineTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.82, h * 0.92)
      ..lineTo(w * 0.18, h * 0.92)
      ..close();
    canvas.drawPath(rim, Paint()..color = fillColor);
    canvas.drawPath(
      rim,
      Paint()
        ..color = deep.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045,
    );

    // Basket rim oval
    final oval = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.28),
      width: w * 0.88,
      height: h * 0.18,
    );
    canvas.drawOval(oval, Paint()..color = fillColor.withValues(alpha: 0.9));
    canvas.drawOval(
      oval,
      Paint()
        ..color = deep
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04,
    );

    // Pattern badge (accessibility — not color-only).
    final badgeCenter = Offset(w * 0.5, h * 0.58);
    final badgeR = w * 0.16;
    canvas.drawCircle(
      badgeCenter,
      badgeR,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    final patternPaint = Paint()
      ..color = deep.withValues(alpha: 0.85)
      ..strokeWidth = w * 0.03
      ..style = PaintingStyle.stroke;
    switch (ColorSortingPalette.pattern(color)) {
      case ColorSortingPattern.stripes:
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            badgeCenter + Offset(i * badgeR * 0.45, -badgeR * 0.55),
            badgeCenter + Offset(i * badgeR * 0.45, badgeR * 0.55),
            patternPaint,
          );
        }
      case ColorSortingPattern.dots:
        for (final o in [Offset(-0.35, -0.2), Offset(0.35, -0.15), Offset(0, 0.35)]) {
          canvas.drawCircle(
            badgeCenter + Offset(o.dx * badgeR, o.dy * badgeR),
            badgeR * 0.18,
            Paint()..color = deep.withValues(alpha: 0.85),
          );
        }
      case ColorSortingPattern.waves:
        final path = Path()
          ..moveTo(badgeCenter.dx - badgeR * 0.6, badgeCenter.dy)
          ..quadraticBezierTo(
            badgeCenter.dx,
            badgeCenter.dy - badgeR * 0.35,
            badgeCenter.dx + badgeR * 0.6,
            badgeCenter.dy,
          );
        canvas.drawPath(path, patternPaint);
      case ColorSortingPattern.leaves:
        canvas.drawOval(
          Rect.fromCenter(
            center: badgeCenter,
            width: badgeR * 1.1,
            height: badgeR * 0.55,
          ),
          Paint()..color = deep.withValues(alpha: 0.8),
        );
    }

    if (highlighted) {
      canvas.drawPath(
        rim,
        Paint()
          ..color = const Color(0xFFFFF176).withValues(alpha: 0.45 + glow * 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.07,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BinPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.highlighted != highlighted ||
        oldDelegate.silhouette != silhouette ||
        oldDelegate.glow != glow;
  }
}

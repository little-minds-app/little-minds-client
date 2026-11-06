import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shape_matching_visual_profile.dart';

/// Original "Playful Learning Garden" backdrop — CustomPainter only (no shipped
/// third-party reference art). Soft sky, hills, path, and sparse props.
class ShapeMatchingGardenScene extends StatelessWidget {
  const ShapeMatchingGardenScene({
    super.key,
    required this.profile,
  });

  final ShapeMatchingVisualProfile profile;

  static const Key sceneKey = Key('shape-matching-garden-scene');

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: sceneKey,
      painter: _GardenScenePainter(detail: profile.gardenDetail),
      child: const SizedBox.expand(),
    );
  }
}

class _GardenScenePainter extends CustomPainter {
  _GardenScenePainter({required this.detail});

  final double detail;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFB3E5FC),
          Color(0xFFE1F5FE),
          Color(0xFFFFF8E1),
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    _paintSun(canvas, size);
    _paintHills(canvas, size);
    _paintPath(canvas, size);
    if (detail > 0.3) {
      _paintTree(canvas, size, left: true);
    }
    if (detail > 0.6) {
      _paintTree(canvas, size, left: false);
      _paintFlowers(canvas, size, count: (4 + detail * 4).round());
    } else if (detail > 0.4) {
      _paintFlowers(canvas, size, count: 3);
    }
    _paintGroundBand(canvas, size);
  }

  void _paintSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.88, size.height * 0.14);
    final r = size.shortestSide * 0.08;
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      center,
      r * 0.72,
      Paint()..color = const Color(0xFFFFEE58),
    );
  }

  void _paintHills(Canvas canvas, Size size) {
    final far = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.42,
        size.width * 0.5,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.62,
        size.width,
        size.height * 0.48,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFFA5D6A7));

    final near = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.58,
        size.width * 0.55,
        size.height * 0.66,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.74,
        size.width,
        size.height * 0.64,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF81C784));
  }

  void _paintPath(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.28, size.height)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.78,
        size.width * 0.5,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.78,
        size.width * 0.72,
        size.height,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFE0B2).withValues(alpha: 0.85));
  }

  void _paintTree(Canvas canvas, Size size, {required bool left}) {
    final baseX = left ? size.width * 0.12 : size.width * 0.9;
    final baseY = size.height * (left ? 0.58 : 0.56);
    final trunk = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(baseX, baseY + size.height * 0.06),
          width: size.shortestSide * 0.03,
          height: size.height * 0.12,
        ),
        const Radius.circular(4),
      ),
      trunk,
    );
    final canopy = Paint()..color = left ? const Color(0xFF66BB6A) : const Color(0xFF43A047);
    canvas.drawCircle(Offset(baseX, baseY), size.shortestSide * 0.09, canopy);
    canvas.drawCircle(
      Offset(baseX - size.shortestSide * 0.05, baseY + size.shortestSide * 0.02),
      size.shortestSide * 0.07,
      canopy,
    );
    canvas.drawCircle(
      Offset(baseX + size.shortestSide * 0.05, baseY + size.shortestSide * 0.015),
      size.shortestSide * 0.065,
      canopy,
    );
  }

  void _paintFlowers(Canvas canvas, Size size, {required int count}) {
    final colors = const [
      Color(0xFFEF9A9A),
      Color(0xFFFFF59D),
      Color(0xFFCE93D8),
      Color(0xFF80CBC4),
    ];
    for (var i = 0; i < count; i++) {
      final t = (i + 1) / (count + 1);
      final x = size.width * (0.15 + t * 0.7);
      final y = size.height * (0.72 + (i.isEven ? 0.04 : 0.08));
      final petal = Paint()..color = colors[i % colors.length];
      for (var p = 0; p < 5; p++) {
        final a = p * math.pi * 2 / 5;
        canvas.drawCircle(
          Offset(x + math.cos(a) * 4.5, y + math.sin(a) * 4.5),
          3.2,
          petal,
        );
      }
      canvas.drawCircle(Offset(x, y), 2.4, Paint()..color = const Color(0xFFFFF176));
    }
  }

  void _paintGroundBand(Canvas canvas, Size size) {
    final band = Rect.fromLTWH(0, size.height * 0.86, size.width, size.height * 0.14);
    canvas.drawRect(
      band,
      Paint()..color = const Color(0xFFC5E1A5).withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _GardenScenePainter oldDelegate) {
    return oldDelegate.detail != detail;
  }
}

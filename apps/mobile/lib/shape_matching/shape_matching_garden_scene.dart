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
          Color(0xFF81D4FA),
          Color(0xFFB3E5FC),
          Color(0xFFE1F5FE),
          Color(0xFFFFF8E1),
        ],
        stops: [0.0, 0.28, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    _paintSun(canvas, size);
    if (detail > 0.35) {
      _paintClouds(canvas, size, sparse: detail < 0.7);
    }
    _paintHills(canvas, size);
    _paintPath(canvas, size);
    if (detail > 0.3) {
      _paintTree(canvas, size, left: true);
    }
    if (detail > 0.6) {
      _paintTree(canvas, size, left: false);
      _paintFlowers(canvas, size, count: (5 + detail * 5).round());
      _paintGrassTufts(canvas, size, count: 8);
    } else if (detail > 0.4) {
      _paintFlowers(canvas, size, count: 3);
      _paintGrassTufts(canvas, size, count: 4);
    }
    _paintGroundBand(canvas, size);
  }

  void _paintSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.88, size.height * 0.13);
    final r = size.shortestSide * 0.085;
    // Soft glow halo
    canvas.drawCircle(
      center,
      r * 1.55,
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      center,
      r * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFFFFFDE7), Color(0xFFFFEE58)],
        ).createShader(Rect.fromCircle(center: center, radius: r * 0.7)),
    );
  }

  void _paintClouds(Canvas canvas, Size size, {required bool sparse}) {
    void cloud(Offset c, double s) {
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.78);
      canvas.drawCircle(c, s, paint);
      canvas.drawCircle(c + Offset(s * 0.7, s * 0.1), s * 0.75, paint);
      canvas.drawCircle(c + Offset(-s * 0.65, s * 0.15), s * 0.65, paint);
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(0, s * 0.35),
          width: s * 2.4,
          height: s * 0.9,
        ),
        paint,
      );
    }

    cloud(Offset(size.width * 0.18, size.height * 0.16), size.shortestSide * 0.045);
    if (!sparse) {
      cloud(Offset(size.width * 0.48, size.height * 0.1), size.shortestSide * 0.038);
      cloud(Offset(size.width * 0.68, size.height * 0.2), size.shortestSide * 0.032);
    }
  }

  void _paintHills(Canvas canvas, Size size) {
    final far = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.4,
        size.width * 0.48,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.62,
        size.width,
        size.height * 0.46,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      far,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
        ).createShader(Offset.zero & size),
    );

    final mid = Path()
      ..moveTo(0, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.52,
        size.width * 0.6,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.68,
        size.width,
        size.height * 0.58,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mid, Paint()..color = const Color(0xFF81C784));

    final near = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.6,
        size.width * 0.55,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.76,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      near,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF66BB6A), Color(0xFF4CAF50)],
        ).createShader(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4)),
    );
  }

  void _paintPath(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.26, size.height)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.78,
        size.width * 0.5,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.78,
        size.width * 0.74,
        size.height,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFFFE0B2).withValues(alpha: 0.9),
    );
    // Soft edge
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFCC80).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Stepping stones
    final stone = Paint()..color = const Color(0xFFFFCC80).withValues(alpha: 0.75);
    for (var i = 0; i < 5; i++) {
      final t = (i + 1) / 6;
      final y = size.height * (1.0 - t * 0.38);
      final x = size.width * (0.5 + math.sin(i * 1.1) * 0.03);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: size.width * 0.055,
          height: size.height * 0.022,
        ),
        stone,
      );
    }
  }

  void _paintTree(Canvas canvas, Size size, {required bool left}) {
    final baseX = left ? size.width * 0.11 : size.width * 0.9;
    final baseY = size.height * (left ? 0.56 : 0.54);
    final trunk = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [Color(0xFFA1887F), Color(0xFF6D4C41)],
      ).createShader(
        Rect.fromCenter(
          center: Offset(baseX, baseY + size.height * 0.06),
          width: size.shortestSide * 0.04,
          height: size.height * 0.14,
        ),
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(baseX, baseY + size.height * 0.06),
          width: size.shortestSide * 0.035,
          height: size.height * 0.13,
        ),
        const Radius.circular(4),
      ),
      trunk,
    );
    final canopyColor =
        left ? const Color(0xFF66BB6A) : const Color(0xFF43A047);
    final canopyDeep =
        left ? const Color(0xFF43A047) : const Color(0xFF2E7D32);
    void canopyBlob(Offset c, double r) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [Color.lerp(canopyColor, Colors.white, 0.2)!, canopyDeep],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    canopyBlob(Offset(baseX, baseY), size.shortestSide * 0.095);
    canopyBlob(
      Offset(baseX - size.shortestSide * 0.055, baseY + size.shortestSide * 0.02),
      size.shortestSide * 0.075,
    );
    canopyBlob(
      Offset(baseX + size.shortestSide * 0.055, baseY + size.shortestSide * 0.015),
      size.shortestSide * 0.07,
    );
    canopyBlob(
      Offset(baseX, baseY - size.shortestSide * 0.04),
      size.shortestSide * 0.06,
    );
  }

  void _paintFlowers(Canvas canvas, Size size, {required int count}) {
    final colors = const [
      Color(0xFFEF9A9A),
      Color(0xFFFFF59D),
      Color(0xFFCE93D8),
      Color(0xFF80CBC4),
      Color(0xFFFFCC80),
    ];
    for (var i = 0; i < count; i++) {
      final t = (i + 1) / (count + 1);
      final x = size.width * (0.14 + t * 0.72);
      final y = size.height * (0.74 + (i.isEven ? 0.035 : 0.075));
      // Stem
      canvas.drawLine(
        Offset(x, y + 6),
        Offset(x, y + 14),
        Paint()
          ..color = const Color(0xFF558B2F)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      final petal = Paint()..color = colors[i % colors.length];
      for (var p = 0; p < 6; p++) {
        final a = p * math.pi * 2 / 6;
        canvas.drawCircle(
          Offset(x + math.cos(a) * 4.8, y + math.sin(a) * 4.8),
          3.4,
          petal,
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        2.6,
        Paint()..color = const Color(0xFFFFF176),
      );
    }
  }

  void _paintGrassTufts(Canvas canvas, Size size, {required int count}) {
    final paint = Paint()
      ..color = const Color(0xFF33691E).withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < count; i++) {
      final x = size.width * (0.08 + (i / count) * 0.84);
      final y = size.height * (0.82 + (i.isEven ? 0.02 : 0.05));
      for (final dx in [-3.0, 0.0, 3.0]) {
        canvas.drawLine(
          Offset(x + dx, y),
          Offset(x + dx * 0.4, y - 7 - (dx == 0 ? 2 : 0)),
          paint,
        );
      }
    }
  }

  void _paintGroundBand(Canvas canvas, Size size) {
    final band =
        Rect.fromLTWH(0, size.height * 0.86, size.width, size.height * 0.14);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFC5E1A5).withValues(alpha: 0.35),
            const Color(0xFFAED581).withValues(alpha: 0.65),
          ],
        ).createShader(band),
    );
  }

  @override
  bool shouldRepaint(covariant _GardenScenePainter oldDelegate) {
    return oldDelegate.detail != detail;
  }
}

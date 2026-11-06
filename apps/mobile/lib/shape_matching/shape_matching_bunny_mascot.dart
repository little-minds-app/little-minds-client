import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shape_matching_visual_profile.dart';

/// Cute bunny coach for praise / celebration — original CustomPainter mascot.
enum BunnyMascotMood {
  idle,
  celebrate,
  encourage,
  complete,
}

class ShapeMatchingBunnyMascot extends StatefulWidget {
  const ShapeMatchingBunnyMascot({
    super.key,
    required this.profile,
    required this.mood,
    this.reduceMotion = false,
    this.size,
  });

  final ShapeMatchingVisualProfile profile;
  final BunnyMascotMood mood;
  final bool reduceMotion;
  final double? size;

  static const Key mascotKey = Key('shape-matching-bunny-mascot');

  @override
  State<ShapeMatchingBunnyMascot> createState() =>
      _ShapeMatchingBunnyMascotState();
}

class _ShapeMatchingBunnyMascotState extends State<ShapeMatchingBunnyMascot>
    with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _celebrate;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _celebrate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant ShapeMatchingBunnyMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    if (widget.reduceMotion) {
      _bob.stop();
      _celebrate.stop();
      _bob.value = 0;
      _celebrate.value = widget.mood == BunnyMascotMood.idle ? 0 : 1;
      return;
    }
    switch (widget.mood) {
      case BunnyMascotMood.idle:
        _celebrate.stop();
        _celebrate.value = 0;
        if (!_bob.isAnimating) {
          _bob.repeat(reverse: true);
        }
      case BunnyMascotMood.encourage:
        _bob.stop();
        _celebrate
          ..reset()
          ..forward();
      case BunnyMascotMood.celebrate:
      case BunnyMascotMood.complete:
        _bob.stop();
        _celebrate
          ..reset()
          ..forward();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    _celebrate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.size ?? 96.0 * widget.profile.mascotScale;
    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _celebrate]),
      builder: (context, _) {
        final bobY = widget.reduceMotion ? 0.0 : (1 - _bob.value) * 4;
        final jump = switch (widget.mood) {
          BunnyMascotMood.celebrate || BunnyMascotMood.complete =>
            math.sin(_celebrate.value * math.pi) * (widget.mood == BunnyMascotMood.complete ? 14 : 10),
          BunnyMascotMood.encourage => math.sin(_celebrate.value * math.pi) * 4,
          BunnyMascotMood.idle => 0.0,
        };
        final scale = switch (widget.mood) {
          BunnyMascotMood.complete => 1.0 + 0.08 * math.sin(_celebrate.value * math.pi),
          BunnyMascotMood.celebrate => 1.0 + 0.05 * math.sin(_celebrate.value * math.pi),
          _ => 1.0,
        };
        return Transform.translate(
          offset: Offset(0, -bobY - jump),
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              key: ShapeMatchingBunnyMascot.mascotKey,
              size: Size(base * 0.85, base),
              painter: _BunnyPainter(
                mood: widget.mood,
                celebrateT: _celebrate.value,
                showSparkles: widget.mood == BunnyMascotMood.celebrate ||
                    widget.mood == BunnyMascotMood.complete,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BunnyPainter extends CustomPainter {
  _BunnyPainter({
    required this.mood,
    required this.celebrateT,
    required this.showSparkles,
  });

  final BunnyMascotMood mood;
  final double celebrateT;
  final bool showSparkles;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyCenter = Offset(w * 0.5, h * 0.62);
    final bodyR = Size(w * 0.72, h * 0.48);

    // Ears
    final earTilt = mood == BunnyMascotMood.encourage
        ? -0.18
        : (showSparkles ? math.sin(celebrateT * math.pi * 2) * 0.12 : 0.0);
    _ear(canvas, Offset(w * 0.32, h * 0.22), tilt: -0.25 + earTilt, length: h * 0.34);
    _ear(canvas, Offset(w * 0.68, h * 0.22), tilt: 0.25 - earTilt, length: h * 0.34);

    // Body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: bodyCenter, width: bodyR.width, height: bodyR.height),
      Radius.circular(w * 0.36),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFFF3E0));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Belly
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyCenter.dx, bodyCenter.dy + h * 0.04),
        width: w * 0.42,
        height: h * 0.28,
      ),
      Paint()..color = const Color(0xFFFFECB3),
    );

    // Face
    final faceY = h * 0.48;
    final eyePaint = Paint()..color = const Color(0xFF4E342E);
    canvas.drawCircle(Offset(w * 0.38, faceY), w * 0.055, eyePaint);
    canvas.drawCircle(Offset(w * 0.62, faceY), w * 0.055, eyePaint);
    canvas.drawCircle(
      Offset(w * 0.39, faceY - w * 0.015),
      w * 0.018,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w * 0.63, faceY - w * 0.015),
      w * 0.018,
      Paint()..color = Colors.white,
    );

    // Nose + cheeks
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, faceY + h * 0.05), width: w * 0.08, height: h * 0.035),
      Paint()..color = const Color(0xFFFFAB91),
    );
    canvas.drawCircle(
      Offset(w * 0.28, faceY + h * 0.06),
      w * 0.05,
      Paint()..color = const Color(0xFFFFCCBC).withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      Offset(w * 0.72, faceY + h * 0.06),
      w * 0.05,
      Paint()..color = const Color(0xFFFFCCBC).withValues(alpha: 0.7),
    );

    // Mouth
    final mouth = Path();
    final mouthY = faceY + h * 0.1;
    if (mood == BunnyMascotMood.encourage) {
      mouth
        ..moveTo(w * 0.42, mouthY)
        ..quadraticBezierTo(w * 0.5, mouthY + h * 0.01, w * 0.58, mouthY);
    } else {
      mouth
        ..moveTo(w * 0.4, mouthY)
        ..quadraticBezierTo(w * 0.5, mouthY + h * 0.06, w * 0.6, mouthY);
    }
    canvas.drawPath(
      mouth,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    if (showSparkles) {
      _sparkles(canvas, size, celebrateT);
    }
  }

  void _ear(Canvas canvas, Offset base, {required double tilt, required double length}) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(-length * 0.16, -length * 0.85, length * 0.32, length),
      Radius.circular(length * 0.16),
    );
    canvas.drawRRect(outer, Paint()..color = const Color(0xFFFFF3E0));
    canvas.drawRRect(
      outer,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(-length * 0.08, -length * 0.7, length * 0.16, length * 0.55),
      Radius.circular(length * 0.1),
    );
    canvas.drawRRect(inner, Paint()..color = const Color(0xFFFFAB91));
    canvas.restore();
  }

  void _sparkles(Canvas canvas, Size size, double t) {
    final paint = Paint()..color = const Color(0xFFFFF176);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + t * math.pi;
      final r = size.shortestSide * (0.42 + 0.08 * math.sin(t * math.pi + i));
      final c = Offset(
        size.width * 0.5 + math.cos(a) * r,
        size.height * 0.45 + math.sin(a) * r * 0.7,
      );
      final s = 3.0 + 2.5 * math.sin(t * math.pi + i);
      canvas.drawCircle(c, s, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BunnyPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.celebrateT != celebrateT ||
        oldDelegate.showSparkles != showSparkles;
  }
}

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

  /// Mood-tagged key for regression assertions (celebrate vs complete).
  static Key moodKey(BunnyMascotMood mood) =>
      Key('shape-matching-bunny-mood-${mood.name}');

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
      duration: const Duration(milliseconds: 1100),
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
      // Static joyful pose for celebrate/complete; calm for idle/encourage.
      _celebrate.value = switch (widget.mood) {
        BunnyMascotMood.idle => 0.0,
        BunnyMascotMood.encourage => 0.35,
        BunnyMascotMood.celebrate || BunnyMascotMood.complete => 0.55,
      };
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
        _bob.stop();
        _celebrate.duration = const Duration(milliseconds: 1100);
        _celebrate
          ..reset()
          ..forward();
      case BunnyMascotMood.complete:
        _bob.stop();
        _celebrate.duration = const Duration(milliseconds: 1400);
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
          BunnyMascotMood.complete =>
            math.sin(_celebrate.value * math.pi) * 18,
          BunnyMascotMood.celebrate =>
            math.sin(_celebrate.value * math.pi) * 12,
          BunnyMascotMood.encourage =>
            math.sin(_celebrate.value * math.pi) * 4,
          BunnyMascotMood.idle => 0.0,
        };
        final scale = switch (widget.mood) {
          BunnyMascotMood.complete =>
            1.0 + 0.12 * math.sin(_celebrate.value * math.pi),
          BunnyMascotMood.celebrate =>
            1.0 + 0.07 * math.sin(_celebrate.value * math.pi),
          _ => 1.0,
        };
        return Transform.translate(
          offset: Offset(0, -bobY - jump),
          child: Transform.scale(
            scale: scale,
            child: KeyedSubtree(
              key: ShapeMatchingBunnyMascot.moodKey(widget.mood),
              child: CustomPaint(
                key: ShapeMatchingBunnyMascot.mascotKey,
                size: Size(base * 0.92, base),
                painter: _BunnyPainter(
                  mood: widget.mood,
                  celebrateT: _celebrate.value,
                  showSparkles: widget.mood == BunnyMascotMood.celebrate ||
                      widget.mood == BunnyMascotMood.complete,
                  reduceMotion: widget.reduceMotion,
                ),
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
    required this.reduceMotion,
  });

  final BunnyMascotMood mood;
  final double celebrateT;
  final bool showSparkles;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyCenter = Offset(w * 0.5, h * 0.64);
    final bodyR = Size(w * 0.7, h * 0.46);

    // Soft ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.94),
        width: w * 0.55,
        height: h * 0.08,
      ),
      Paint()..color = const Color(0x33000000),
    );

    // Ears (tilt with mood)
    final earTilt = mood == BunnyMascotMood.encourage
        ? -0.2
        : (showSparkles ? math.sin(celebrateT * math.pi * 2) * 0.14 : 0.0);
    _ear(canvas, Offset(w * 0.32, h * 0.24), tilt: -0.28 + earTilt, length: h * 0.36);
    _ear(canvas, Offset(w * 0.68, h * 0.24), tilt: 0.28 - earTilt, length: h * 0.36);

    // Body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: bodyCenter,
        width: bodyR.width,
        height: bodyR.height,
      ),
      Radius.circular(w * 0.34),
    );
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFFFF8E7),
          Color(0xFFFFE0B2),
        ],
      ).createShader(body.outerRect);
    canvas.drawRRect(body, bodyPaint);
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
        width: w * 0.4,
        height: h * 0.26,
      ),
      Paint()..color = const Color(0xFFFFF3E0),
    );

    // Articulated paws — clap on celebrate / complete
    _paws(canvas, size, bodyCenter);

    // Face
    _face(canvas, size);

    // Feet
    final footPaint = Paint()..color = const Color(0xFFFFE0B2);
    final footStroke = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final dx in [-0.16, 0.16]) {
      final foot = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * (0.5 + dx), h * 0.88),
          width: w * 0.2,
          height: h * 0.09,
        ),
        Radius.circular(w * 0.08),
      );
      canvas.drawRRect(foot, footPaint);
      canvas.drawRRect(foot, footStroke);
    }

    if (showSparkles) {
      _sparkles(canvas, size, celebrateT, intense: mood == BunnyMascotMood.complete);
    }
  }

  void _paws(Canvas canvas, Size size, Offset bodyCenter) {
    final w = size.width;
    final h = size.height;
    final clapping = mood == BunnyMascotMood.celebrate ||
        mood == BunnyMascotMood.complete;
    // Clap phase: paws swing toward midline then apart.
    final clap = clapping
        ? (reduceMotion
            ? 0.7
            : (0.5 + 0.5 * math.sin(celebrateT * math.pi * 4)))
        : 0.0;
    final encourageLift = mood == BunnyMascotMood.encourage ? 0.35 : 0.0;

    void paw({required bool left}) {
      final side = left ? -1.0 : 1.0;
      final shoulder = Offset(
        bodyCenter.dx + side * w * 0.34,
        bodyCenter.dy - h * 0.02,
      );
      // Idle hang down; clap swings up and inward.
      final swingIn = clap * 0.85;
      final swingUp = clap * 1.1 + encourageLift * 0.6;
      final elbow = Offset(
        shoulder.dx + side * w * (0.08 - swingIn * 0.22),
        shoulder.dy + h * (0.12 - swingUp * 0.16),
      );
      final hand = Offset(
        elbow.dx + side * w * (0.05 - swingIn * 0.18),
        elbow.dy + h * (0.1 - swingUp * 0.14),
      );

      final armPaint = Paint()
        ..color = const Color(0xFFFFE0B2)
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(shoulder, elbow, armPaint);
      canvas.drawLine(elbow, hand, armPaint);

      // Paw pad
      final padR = w * 0.085;
      canvas.drawCircle(hand, padR, Paint()..color = const Color(0xFFFFCC80));
      canvas.drawCircle(
        hand,
        padR,
        Paint()
          ..color = const Color(0xFF8D6E63)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Toe beans
      final bean = Paint()..color = const Color(0xFFFFAB91);
      canvas.drawCircle(
        hand + Offset(-padR * 0.35 * side, -padR * 0.25),
        padR * 0.22,
        bean,
      );
      canvas.drawCircle(
        hand + Offset(padR * 0.15 * side, -padR * 0.4),
        padR * 0.2,
        bean,
      );
      canvas.drawCircle(
        hand + Offset(padR * 0.4 * side, -padR * 0.1),
        padR * 0.18,
        bean,
      );
    }

    paw(left: true);
    paw(left: false);

    // Motion arcs / clap spark at contact
    if (clapping && clap > 0.85 && !reduceMotion) {
      final contact = Offset(bodyCenter.dx, bodyCenter.dy - h * 0.08);
      canvas.drawCircle(
        contact,
        w * 0.04 * clap,
        Paint()..color = const Color(0xFFFFF176).withValues(alpha: 0.7),
      );
    }
  }

  void _face(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final faceY = h * 0.48;
    final joyful = mood == BunnyMascotMood.celebrate ||
        mood == BunnyMascotMood.complete;

    // Eyes — happy crescents when celebrating
    if (joyful) {
      final eyePaint = Paint()
        ..color = const Color(0xFF4E342E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round;
      for (final dx in [0.38, 0.62]) {
        final path = Path()
          ..moveTo(w * dx - w * 0.045, faceY)
          ..quadraticBezierTo(
            w * dx,
            faceY - h * 0.035,
            w * dx + w * 0.045,
            faceY,
          );
        canvas.drawPath(path, eyePaint);
      }
    } else {
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
    }

    // Blush cheeks — stronger when joyful
    final cheekAlpha = joyful ? 0.85 : 0.7;
    canvas.drawCircle(
      Offset(w * 0.27, faceY + h * 0.055),
      w * (joyful ? 0.06 : 0.05),
      Paint()..color = const Color(0xFFFFCCBC).withValues(alpha: cheekAlpha),
    );
    canvas.drawCircle(
      Offset(w * 0.73, faceY + h * 0.055),
      w * (joyful ? 0.06 : 0.05),
      Paint()..color = const Color(0xFFFFCCBC).withValues(alpha: cheekAlpha),
    );

    // Nose
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, faceY + h * 0.05),
        width: w * 0.085,
        height: h * 0.038,
      ),
      Paint()..color = const Color(0xFFFFAB91),
    );

    // Mouth
    final mouth = Path();
    final mouthY = faceY + h * 0.1;
    if (mood == BunnyMascotMood.encourage) {
      mouth
        ..moveTo(w * 0.42, mouthY)
        ..quadraticBezierTo(w * 0.5, mouthY + h * 0.01, w * 0.58, mouthY);
    } else if (joyful) {
      // Open joyful smile
      mouth
        ..moveTo(w * 0.38, mouthY)
        ..quadraticBezierTo(w * 0.5, mouthY + h * 0.09, w * 0.62, mouthY);
      canvas.drawPath(
        mouth,
        Paint()
          ..color = const Color(0xFFE57373).withValues(alpha: 0.55)
          ..style = PaintingStyle.fill,
      );
      mouth
        ..reset()
        ..moveTo(w * 0.38, mouthY)
        ..quadraticBezierTo(w * 0.5, mouthY + h * 0.09, w * 0.62, mouthY);
    } else {
      mouth
        ..moveTo(w * 0.4, mouthY)
        ..quadraticBezierTo(w * 0.5, mouthY + h * 0.055, w * 0.6, mouthY);
    }
    canvas.drawPath(
      mouth,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round,
    );
  }

  void _ear(
    Canvas canvas,
    Offset base, {
    required double tilt,
    required double length,
  }) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(-length * 0.16, -length * 0.85, length * 0.32, length),
      Radius.circular(length * 0.16),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFFFF8E7), Color(0xFFFFE0B2)],
        ).createShader(outer.outerRect),
    );
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

  void _sparkles(
    Canvas canvas,
    Size size,
    double t, {
    required bool intense,
  }) {
    final count = intense ? 10 : 7;
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count + t * math.pi * (intense ? 1.4 : 1.0);
      final r = size.shortestSide *
          (0.4 + 0.1 * math.sin(t * math.pi + i) + (intense ? 0.06 : 0));
      final c = Offset(
        size.width * 0.5 + math.cos(a) * r,
        size.height * 0.42 + math.sin(a) * r * 0.72,
      );
      final s = (intense ? 3.5 : 2.8) + 2.8 * math.sin(t * math.pi + i);
      // Four-point sparkle
      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFF176),
          const Color(0xFFFFFDE7),
          (math.sin(t * math.pi * 2 + i) + 1) / 2,
        )!
            .withValues(alpha: reduceMotion ? 0.75 : 0.95);
      canvas.drawCircle(c, s * 0.55, paint);
      canvas.drawLine(
        c + Offset(0, -s),
        c + Offset(0, s),
        paint
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
      canvas.drawLine(
        c + Offset(-s, 0),
        c + Offset(s, 0),
        paint
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BunnyPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.celebrateT != celebrateT ||
        oldDelegate.showSparkles != showSparkles ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}

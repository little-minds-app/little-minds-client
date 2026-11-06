import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'animal_sound_matching_logic.dart';
import 'animal_sound_matching_visual_profile.dart';

/// Friendly palette + silhouette motifs — never color-only identification.
abstract final class AnimalSoundMatchingPalette {
  static Color fill(AnimalKind kind) => switch (kind) {
        AnimalKind.cat => const Color(0xFFFFB74D),
        AnimalKind.dog => const Color(0xFFA1887F),
        AnimalKind.cow => const Color(0xFFEEEEEE),
        AnimalKind.duck => const Color(0xFFFFF176),
        AnimalKind.bird => const Color(0xFF81D4FA),
        AnimalKind.sheep => const Color(0xFFF5F5F5),
        AnimalKind.frog => const Color(0xFF81C784),
        AnimalKind.horse => const Color(0xFF8D6E63),
      };

  static Color deep(AnimalKind kind) => switch (kind) {
        AnimalKind.cat => const Color(0xFFEF6C00),
        AnimalKind.dog => const Color(0xFF5D4037),
        AnimalKind.cow => const Color(0xFF424242),
        AnimalKind.duck => const Color(0xFFF9A825),
        AnimalKind.bird => const Color(0xFF0277BD),
        AnimalKind.sheep => const Color(0xFF616161),
        AnimalKind.frog => const Color(0xFF2E7D32),
        AnimalKind.horse => const Color(0xFF4E342E),
      };

  /// Distinct silhouette motif so correctness is never color-only.
  static AnimalSilhouette silhouette(AnimalKind kind) => switch (kind) {
        AnimalKind.cat => AnimalSilhouette.pointyEars,
        AnimalKind.dog => AnimalSilhouette.floppyEars,
        AnimalKind.cow => AnimalSilhouette.hornsSpot,
        AnimalKind.duck => AnimalSilhouette.beakRound,
        AnimalKind.bird => AnimalSilhouette.wingPeak,
        AnimalKind.sheep => AnimalSilhouette.fluffyOval,
        AnimalKind.frog => AnimalSilhouette.wideSquat,
        AnimalKind.horse => AnimalSilhouette.longMane,
      };
}

enum AnimalSilhouette {
  pointyEars,
  floppyEars,
  hornsSpot,
  beakRound,
  wingPeak,
  fluffyOval,
  wideSquat,
  longMane,
}

/// Friendly animal character with face + distinctive silhouette.
class AnimalSoundMatchingAnimalCharacter extends StatelessWidget {
  const AnimalSoundMatchingAnimalCharacter({
    super.key,
    required this.animal,
    required this.size,
    required this.profile,
    this.highlighted = false,
    this.selected = false,
  });

  final AnimalKind animal;
  final double size;
  final AnimalSoundMatchingVisualProfile profile;
  final bool highlighted;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scale = selected ? profile.choiceLiftScale : 1.0;
    return Transform.scale(
      scale: scale,
      child: CustomPaint(
        size: Size.square(size),
        painter: _AnimalPainter(
          animal: animal,
          faceScale: profile.faceScale,
          highlighted: highlighted,
        ),
      ),
    );
  }
}

class _AnimalPainter extends CustomPainter {
  _AnimalPainter({
    required this.animal,
    required this.faceScale,
    required this.highlighted,
  });

  final AnimalKind animal;
  final double faceScale;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AnimalSoundMatchingPalette.fill(animal);
    final outline = Paint()
      ..color = AnimalSoundMatchingPalette.deep(animal).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.045;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.38;

    _paintBody(canvas, size, center, r, fill, outline);
    _paintFace(canvas, size, center, r);

    if (highlighted) {
      canvas.drawCircle(
        center,
        r * 1.25,
        Paint()
          ..color = const Color(0xFFFFF59D).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.06,
      );
    }
  }

  void _paintBody(
    Canvas canvas,
    Size size,
    Offset center,
    double r,
    Paint fill,
    Paint outline,
  ) {
    switch (AnimalSoundMatchingPalette.silhouette(animal)) {
      case AnimalSilhouette.pointyEars:
        canvas.drawCircle(center, r, fill);
        canvas.drawCircle(center, r, outline);
        _ear(canvas, center + Offset(-r * 0.55, -r * 0.85), r * 0.38, fill, outline);
        _ear(canvas, center + Offset(r * 0.55, -r * 0.85), r * 0.38, fill, outline);
      case AnimalSilhouette.floppyEars:
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 1.9, height: r * 1.7),
          fill,
        );
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 1.9, height: r * 1.7),
          outline,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: center + Offset(-r * 0.95, 0),
            width: r * 0.55,
            height: r * 0.9,
          ),
          fill,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: center + Offset(r * 0.95, 0),
            width: r * 0.55,
            height: r * 0.9,
          ),
          fill,
        );
      case AnimalSilhouette.hornsSpot:
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 2.0, height: r * 1.7),
          fill,
        );
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 2.0, height: r * 1.7),
          outline,
        );
        final spot = Paint()..color = const Color(0xFF424242);
        canvas.drawCircle(center + Offset(-r * 0.35, -r * 0.1), r * 0.22, spot);
        canvas.drawCircle(center + Offset(r * 0.45, r * 0.25), r * 0.18, spot);
        _horn(canvas, center + Offset(-r * 0.55, -r * 0.95), outline);
        _horn(canvas, center + Offset(r * 0.55, -r * 0.95), outline);
      case AnimalSilhouette.beakRound:
        canvas.drawCircle(center, r, fill);
        canvas.drawCircle(center, r, outline);
        final beak = Path()
          ..moveTo(center.dx + r * 0.55, center.dy)
          ..lineTo(center.dx + r * 1.15, center.dy - r * 0.12)
          ..lineTo(center.dx + r * 0.55, center.dy + r * 0.2)
          ..close();
        canvas.drawPath(beak, Paint()..color = const Color(0xFFFF9800));
        canvas.drawPath(beak, outline);
      case AnimalSilhouette.wingPeak:
        final body = Path()
          ..moveTo(center.dx, center.dy - r)
          ..quadraticBezierTo(
            center.dx + r * 1.1,
            center.dy,
            center.dx,
            center.dy + r,
          )
          ..quadraticBezierTo(
            center.dx - r * 1.1,
            center.dy,
            center.dx,
            center.dy - r,
          );
        canvas.drawPath(body, fill);
        canvas.drawPath(body, outline);
        canvas.drawOval(
          Rect.fromCenter(
            center: center + Offset(-r * 0.7, 0),
            width: r * 0.7,
            height: r * 0.35,
          ),
          Paint()..color = AnimalSoundMatchingPalette.deep(animal),
        );
      case AnimalSilhouette.fluffyOval:
        for (final o in [
          Offset(0, 0),
          Offset(-0.55, -0.2),
          Offset(0.55, -0.15),
          Offset(-0.35, 0.4),
          Offset(0.4, 0.35),
        ]) {
          canvas.drawCircle(
            center + Offset(o.dx * r, o.dy * r),
            r * 0.55,
            fill,
          );
        }
        canvas.drawCircle(center, r * 0.95, outline);
      case AnimalSilhouette.wideSquat:
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 2.2, height: r * 1.5),
          fill,
        );
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 2.2, height: r * 1.5),
          outline,
        );
        canvas.drawCircle(
          center + Offset(-r * 0.55, -r * 0.7),
          r * 0.28,
          fill,
        );
        canvas.drawCircle(
          center + Offset(r * 0.55, -r * 0.7),
          r * 0.28,
          fill,
        );
      case AnimalSilhouette.longMane:
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 1.7, height: r * 1.9),
          fill,
        );
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 1.7, height: r * 1.9),
          outline,
        );
        final mane = Paint()..color = const Color(0xFF3E2723);
        for (var i = 0; i < 4; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: center + Offset(r * 0.75, -r * 0.5 + i * r * 0.28),
              width: r * 0.35,
              height: r * 0.22,
            ),
            mane,
          );
        }
    }
  }

  void _ear(
    Canvas canvas,
    Offset tip,
    double s,
    Paint fill,
    Paint outline,
  ) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy - s)
      ..lineTo(tip.dx + s * 0.7, tip.dy + s * 0.6)
      ..lineTo(tip.dx - s * 0.7, tip.dy + s * 0.6)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);
  }

  void _horn(Canvas canvas, Offset tip, Paint outline) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + 4, tip.dy + 14)
      ..lineTo(tip.dx - 4, tip.dy + 14)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF757575));
    canvas.drawPath(path, outline);
  }

  void _paintFace(Canvas canvas, Size size, Offset center, double r) {
    final eyeR = r * 0.11 * faceScale;
    final eyeY = center.dy - r * 0.12;
    final eyePaint = Paint()..color = const Color(0xFF212121);
    canvas.drawCircle(Offset(center.dx - r * 0.28, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(center.dx + r * 0.28, eyeY), eyeR, eyePaint);
    canvas.drawCircle(
      Offset(center.dx - r * 0.28 + eyeR * 0.35, eyeY - eyeR * 0.3),
      eyeR * 0.35,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(center.dx + r * 0.28 + eyeR * 0.35, eyeY - eyeR * 0.3),
      eyeR * 0.35,
      Paint()..color = Colors.white,
    );
    // Soft smile
    final smile = Path()
      ..moveTo(center.dx - r * 0.22, center.dy + r * 0.28)
      ..quadraticBezierTo(
        center.dx,
        center.dy + r * 0.42,
        center.dx + r * 0.22,
        center.dy + r * 0.28,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.03
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimalPainter oldDelegate) {
    return oldDelegate.animal != animal ||
        oldDelegate.faceScale != faceScale ||
        oldDelegate.highlighted != highlighted;
  }
}

/// Large non-interactive prompt silhouette for visual-fallback mode.
class AnimalSoundMatchingPromptCue extends StatelessWidget {
  const AnimalSoundMatchingPromptCue({
    super.key,
    required this.animal,
    required this.size,
    required this.profile,
  });

  final AnimalKind animal;
  final double size;
  final AnimalSoundMatchingVisualProfile profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: AnimalSoundMatchingPalette.deep(animal).withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: AnimalSoundMatchingAnimalCharacter(
          animal: animal,
          size: size * 0.84,
          profile: profile,
          highlighted: true,
        ),
      ),
    );
  }
}

/// Tiny decorative paw print (IgnorePointer scenery only).
class AnimalGardenPawPrint extends StatelessWidget {
  const AnimalGardenPawPrint({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PawPainter(),
    );
  }
}

class _PawPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x668D6E63);
    final c = Offset(size.width / 2, size.height * 0.58);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: size.width * 0.55, height: size.height * 0.42),
      paint,
    );
    for (var i = 0; i < 4; i++) {
      final a = -math.pi * 0.75 + i * (math.pi * 0.35);
      canvas.drawCircle(
        Offset(
          c.dx + math.cos(a) * size.width * 0.32,
          c.dy + math.sin(a) * size.height * 0.38 - size.height * 0.15,
        ),
        size.width * 0.12,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

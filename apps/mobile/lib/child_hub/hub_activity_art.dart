import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hub_activity_catalog.dart';
import 'hub_theme.dart';

/// Original CustomPainter motifs for the six V1 engines (offline, no remote art).
///
/// Intentionally abstract educational shapes — no third-party characters.
class HubActivityArt extends StatelessWidget {
  const HubActivityArt({
    super.key,
    required this.catalogId,
    required this.playable,
  });

  final HubCatalogActivityId catalogId;
  final bool playable;

  static Key artKey(String id) => Key('hub-activity-art-$id');

  @override
  Widget build(BuildContext context) {
    final accent = HubTheme.accentFor(catalogId);
    return DecoratedBox(
      key: artKey(catalogId.id),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: playable ? 0.22 : 0.12),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(HubTheme.artRadius),
      ),
      child: CustomPaint(
        painter: _HubArtPainter(catalogId: catalogId, accent: accent),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HubArtPainter extends CustomPainter {
  _HubArtPainter({required this.catalogId, required this.accent});

  final HubCatalogActivityId catalogId;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = math.min(size.width, size.height);

    switch (catalogId) {
      case HubCatalogActivityId.shapeMatching:
        _paintShapes(canvas, cx, cy, s);
      case HubCatalogActivityId.colorSorting:
        _paintColors(canvas, cx, cy, s);
      case HubCatalogActivityId.animalSounds:
        _paintAnimal(canvas, cx, cy, s);
      case HubCatalogActivityId.counting:
        _paintCounting(canvas, cx, cy, s);
      case HubCatalogActivityId.memoryMatching:
        _paintMemory(canvas, cx, cy, s);
      case HubCatalogActivityId.objectCategories:
        _paintCategories(canvas, cx, cy, s);
    }
  }

  void _paintShapes(Canvas canvas, double cx, double cy, double s) {
    final fill = Paint()..color = accent;
    final outline = Paint()
      ..color = HubTheme.ink.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03;

    canvas.drawCircle(Offset(cx - s * 0.18, cy), s * 0.16, fill);
    canvas.drawCircle(Offset(cx - s * 0.18, cy), s * 0.16, outline);

    final tri = Path()
      ..moveTo(cx + s * 0.05, cy - s * 0.18)
      ..lineTo(cx + s * 0.28, cy + s * 0.16)
      ..lineTo(cx - s * 0.08, cy + s * 0.16)
      ..close();
    canvas.drawPath(tri, fill);
    canvas.drawPath(tri, outline);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx + s * 0.02, cy + s * 0.02),
        width: s * 0.22,
        height: s * 0.22,
      ),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = accent.withValues(alpha: 0.55),
    );
  }

  void _paintColors(Canvas canvas, double cx, double cy, double s) {
    final colors = [
      const Color(0xFFFF8A65),
      const Color(0xFFFFD54F),
      const Color(0xFF66BB6A),
    ];
    for (var i = 0; i < 3; i++) {
      final dx = (i - 1) * s * 0.22;
      canvas.drawCircle(
        Offset(cx + dx, cy + s * 0.02),
        s * 0.14,
        Paint()..color = colors[i],
      );
      canvas.drawCircle(
        Offset(cx + dx, cy + s * 0.02),
        s * 0.14,
        Paint()
          ..color = HubTheme.ink.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.025,
      );
    }
  }

  void _paintAnimal(Canvas canvas, double cx, double cy, double s) {
    final body = Paint()..color = accent;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + s * 0.04),
        width: s * 0.42,
        height: s * 0.32,
      ),
      body,
    );
    canvas.drawCircle(Offset(cx - s * 0.12, cy - s * 0.12), s * 0.08, body);
    canvas.drawCircle(Offset(cx + s * 0.12, cy - s * 0.12), s * 0.08, body);
    final arc = Paint()
      ..color = HubTheme.ink.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + s * 0.28, cy - s * 0.02), width: s * 0.22, height: s * 0.22),
      -math.pi / 2,
      math.pi,
      false,
      arc,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + s * 0.34, cy - s * 0.02), width: s * 0.32, height: s * 0.32),
      -math.pi / 2,
      math.pi,
      false,
      arc,
    );
  }

  void _paintCounting(Canvas canvas, double cx, double cy, double s) {
    final colors = [
      accent,
      accent.withValues(alpha: 0.75),
      accent.withValues(alpha: 0.55),
    ];
    for (var i = 0; i < 3; i++) {
      final dx = (i - 1) * s * 0.2;
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + dx, cy),
          width: s * 0.16,
          height: s * 0.16,
        ),
        Radius.circular(s * 0.04),
      );
      canvas.drawRRect(r, Paint()..color = colors[i]);
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: HubTheme.ink.withValues(alpha: 0.8),
            fontSize: s * 0.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(cx + dx - tp.width / 2, cy - tp.height / 2),
      );
    }
  }

  void _paintMemory(Canvas canvas, double cx, double cy, double s) {
    void leaf(Offset c, double rot) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rot);
      final path = Path()
        ..moveTo(0, -s * 0.12)
        ..quadraticBezierTo(s * 0.12, 0, 0, s * 0.12)
        ..quadraticBezierTo(-s * 0.12, 0, 0, -s * 0.12)
        ..close();
      canvas.drawPath(path, Paint()..color = accent);
      canvas.drawPath(
        path,
        Paint()
          ..color = HubTheme.ink.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02,
      );
      canvas.restore();
    }

    leaf(Offset(cx - s * 0.14, cy), -0.35);
    leaf(Offset(cx + s * 0.14, cy), 0.35);
  }

  void _paintCategories(Canvas canvas, double cx, double cy, double s) {
    final basket = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + s * 0.06), width: s * 0.5, height: s * 0.28),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(basket, Paint()..color = accent.withValues(alpha: 0.55));
    canvas.drawRRect(
      basket,
      Paint()
        ..color = HubTheme.ink.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025,
    );
    canvas.drawCircle(
      Offset(cx - s * 0.12, cy - s * 0.08),
      s * 0.07,
      Paint()..color = const Color(0xFFFF8A65),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + s * 0.12, cy - s * 0.08),
          width: s * 0.14,
          height: s * 0.14,
        ),
        Radius.circular(s * 0.03),
      ),
      Paint()..color = const Color(0xFF64B5F6),
    );
  }

  @override
  bool shouldRepaint(covariant _HubArtPainter oldDelegate) =>
      oldDelegate.catalogId != catalogId || oldDelegate.accent != accent;
}

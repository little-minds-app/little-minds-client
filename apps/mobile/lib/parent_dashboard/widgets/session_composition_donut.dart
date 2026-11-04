import 'dart:math' as math;

import 'package:flutter/material.dart';

class SessionCompositionDonut extends StatelessWidget {
  const SessionCompositionDonut({
    super.key,
    required this.completed,
    required this.interrupted,
    required this.inProgress,
    required this.abandoned,
    required this.eligible,
  });

  final int completed;
  final int interrupted;
  final int inProgress;
  final int abandoned;
  final int eligible;

  @override
  Widget build(BuildContext context) {
    final segments = <({String label, int value, Color color})>[
      (label: 'Tamamlanan', value: completed, color: const Color(0xFF2D6A4F)),
      (label: 'Yarıda kalan', value: interrupted, color: const Color(0xFFBC6C25)),
      (label: 'Devam eden', value: inProgress, color: const Color(0xFF2552A4)),
      (label: 'Terk edilen', value: abandoned, color: const Color(0xFF6C757D)),
    ].where((segment) => segment.value > 0).toList();
    final total = segments.fold<int>(0, (sum, segment) => sum + segment.value);

    if (eligible <= 0 || total <= 0) {
      return Semantics(
        label: 'Oturum dağılımı grafiği: uygun oturum yok',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: const Text(
            'Bu dönemde dağılım gösterecek uygun oturum yok. Grafik yalnızca sunucudan gelen gerçek oturum sayılarıyla doldurulur.',
          ),
        ),
      );
    }

    return Semantics(
      label: 'Oturum dağılımı: ${segments.map((s) => '${s.label} ${s.value}').join(', ')}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DonutPainter(segments: segments, total: total),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final segment in segments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: segment.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(segment.label)),
                        Text('${segment.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.total});

  final List<({String label, int value, Color color})> segments;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2 - 4;
    const stroke = 14.0;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFEEF1F7);
    canvas.drawCircle(center, radius, base);

    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = (segment.value / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = segment.color
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.segments != segments;
}

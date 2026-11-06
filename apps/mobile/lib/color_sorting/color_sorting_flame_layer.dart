import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import 'color_sorting_activity.dart';

/// ADR-015 / LMP-44 hybrid: Flutter owns input and layout; Flame owns ambient
/// scoring-neutral celebration wash.
class ColorSortingFlameLayer extends Component {
  ColorSortingFlameLayer({required this.activity});

  final ColorSortingActivity activity;
  double _pulse = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (activity.showCelebrationPulse) {
      _pulse = (_pulse + dt * 2.2).clamp(0, 1);
    } else {
      _pulse = (_pulse - dt * 2.6).clamp(0, 1);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_pulse <= 0) return;
    final game = findGame();
    if (game == null) return;
    final size = game.size;

    final wash = Paint()
      ..color = Color.lerp(
        const Color(0x00000000),
        const Color(0x28FFE0B2),
        _pulse,
      )!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), wash);

    final sparkle =
        Paint()..color = const Color(0xCCFFCC80).withValues(alpha: 0.35 * _pulse);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + _pulse * math.pi;
      final r = math.min(size.x, size.y) * (0.18 + 0.1 * _pulse);
      final c = Offset(
        size.x * 0.5 + math.cos(a) * r,
        size.y * 0.35 + math.sin(a) * r * 0.55,
      );
      canvas.drawCircle(c, 3.5 + 2 * _pulse, sparkle);
    }
  }
}

extension ColorSortingFlameMount on ColorSortingActivity {
  Future<void> mountFlameLayer(FlameGame game) async {
    if (game.children.query<ColorSortingFlameLayer>().isNotEmpty) {
      return;
    }
    await game.add(ColorSortingFlameLayer(activity: this));
  }

  Future<void> unmountFlameLayer(FlameGame game) async {
    for (final layer in List<ColorSortingFlameLayer>.from(
      game.children.query<ColorSortingFlameLayer>(),
    )) {
      layer.removeFromParent();
    }
  }
}

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import 'shape_matching_activity.dart';

/// Gentle Flame feedback layer — scoring-neutral pulse on correct matches.
class ShapeMatchingFlameLayer extends Component {
  ShapeMatchingFlameLayer({required this.activity});

  final ShapeMatchingActivity activity;
  double _pulse = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (activity.showCelebrationPulse) {
      _pulse = (_pulse + dt * 2).clamp(0, 1);
    } else {
      _pulse = (_pulse - dt * 3).clamp(0, 1);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_pulse <= 0) return;
    final game = findGame();
    if (game == null) return;
    final size = game.size;
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0x00000000),
        const Color(0x334CAF50),
        _pulse,
      )!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}

extension ShapeMatchingFlameMount on ShapeMatchingActivity {
  Future<void> mountFlameLayer(FlameGame game) async {
    if (game.children.query<ShapeMatchingFlameLayer>().isNotEmpty) {
      return;
    }
    await game.add(ShapeMatchingFlameLayer(activity: this));
  }

  Future<void> unmountFlameLayer(FlameGame game) async {
    for (final layer in game.children.query<ShapeMatchingFlameLayer>()) {
      layer.removeFromParent();
    }
  }
}

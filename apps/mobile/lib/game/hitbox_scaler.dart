import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// Scales Flame hitboxes for phone/tablet viewports (F-034 / LMP-44).
///
/// Keeps touch targets usable (≥ [minLogicalSize]) and aligned with visuals
/// when the design canvas is letterboxed into a landscape play surface.
abstract final class HitboxScaler {
  /// Blueprint / a11y minimum touch target in logical pixels.
  static const double minLogicalSize = 44;

  /// Design canvas used by mini-games (landscape). Scaffolding until LMP-61.
  static const Size designCanvas = Size(800, 450);

  /// Uniform scale that fits [designCanvas] inside [viewport] (contain).
  static double containScale(Size viewport, {Size design = designCanvas}) {
    if (viewport.width <= 0 || viewport.height <= 0) {
      return 1;
    }
    final sx = viewport.width / design.width;
    final sy = viewport.height / design.height;
    return math.min(sx, sy);
  }

  /// Scales a design-space length into logical pixels, then clamps to min size.
  static double scaleLength(
    double designLength, {
    required Size viewport,
    Size design = designCanvas,
    double minLogical = minLogicalSize,
    double textScaleFactor = 1,
  }) {
    final scale = containScale(viewport, design: design);
    final raw = designLength * scale * textScaleFactor.clamp(1.0, 2.0);
    return math.max(raw, minLogical);
  }

  /// Maps a design-space axis-aligned rect into viewport logical coordinates,
  /// expanding short edges to [minLogical] while keeping the center.
  static Rect scaleRect(
    Rect designRect, {
    required Size viewport,
    Size design = designCanvas,
    double minLogical = minLogicalSize,
    double textScaleFactor = 1,
  }) {
    final scale = containScale(viewport, design: design);
    final letterboxed = Size(design.width * scale, design.height * scale);
    final origin = Offset(
      (viewport.width - letterboxed.width) / 2,
      (viewport.height - letterboxed.height) / 2,
    );

    var width = designRect.width * scale * textScaleFactor.clamp(1.0, 2.0);
    var height = designRect.height * scale * textScaleFactor.clamp(1.0, 2.0);
    width = math.max(width, minLogical);
    height = math.max(height, minLogical);

    final center = Offset(
      origin.dx + designRect.center.dx * scale,
      origin.dy + designRect.center.dy * scale,
    );
    return Rect.fromCenter(center: center, width: width, height: height);
  }
}

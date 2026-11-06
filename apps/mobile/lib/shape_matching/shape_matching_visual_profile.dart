import 'shape_matching_logic.dart';

/// Age-adaptive presentation knobs for the Playful Learning Garden scene.
///
/// Pedagogy (choice count, bands) stays in [ShapeMatchingBand]; this profile
/// only tunes visual density so younger children get calmer, larger cues.
enum ShapeMatchingVisualBand {
  toddler,
  preschool,
  early,
}

final class ShapeMatchingVisualProfile {
  const ShapeMatchingVisualProfile({
    required this.band,
    required this.faceScale,
    required this.mascotScale,
    required this.gardenDetail,
    required this.showChoiceLabels,
    required this.dragLiftScale,
    required this.targetGlow,
  });

  final ShapeMatchingVisualBand band;

  /// Relative size of facial features on shape characters.
  final double faceScale;

  /// Relative bunny mascot size in the scene.
  final double mascotScale;

  /// 0 = calm sparse garden, 1 = fuller garden accents.
  final double gardenDetail;

  /// Whether choice tiles show shape name captions (older bands).
  final bool showChoiceLabels;

  /// Feedback scale while dragging a shape.
  final double dragLiftScale;

  /// Soft target silhouette glow intensity.
  final double targetGlow;

  static ShapeMatchingVisualProfile forAgeMonths(int ageMonths) {
    if (ageMonths <= 35) {
      return const ShapeMatchingVisualProfile(
        band: ShapeMatchingVisualBand.toddler,
        faceScale: 1.2,
        mascotScale: 1.15,
        gardenDetail: 0.45,
        showChoiceLabels: false,
        dragLiftScale: 1.18,
        targetGlow: 0.9,
      );
    }
    if (ageMonths <= 47) {
      return const ShapeMatchingVisualProfile(
        band: ShapeMatchingVisualBand.preschool,
        faceScale: 1.0,
        mascotScale: 1.0,
        gardenDetail: 0.75,
        showChoiceLabels: false,
        dragLiftScale: 1.14,
        targetGlow: 0.7,
      );
    }
    return const ShapeMatchingVisualProfile(
      band: ShapeMatchingVisualBand.early,
      faceScale: 0.92,
      mascotScale: 0.92,
      gardenDetail: 1.0,
      showChoiceLabels: true,
      dragLiftScale: 1.12,
      targetGlow: 0.55,
    );
  }

  static ShapeMatchingVisualProfile forBand(ShapeMatchingBand? band) {
    if (band == null) {
      return forAgeMonths(36);
    }
    return forAgeMonths(band.minMonths);
  }
}

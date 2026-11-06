import '../shape_matching/shape_matching_visual_profile.dart';
import 'color_sorting_logic.dart';

/// Age-adaptive presentation knobs for the Colorful Orchard scene.
enum ColorSortingVisualBand {
  toddler,
  preschool,
  early,
}

final class ColorSortingVisualProfile {
  const ColorSortingVisualProfile({
    required this.band,
    required this.faceScale,
    required this.mascotScale,
    required this.orchardDetail,
    required this.showBinLabels,
    required this.dragLiftScale,
    required this.binGlow,
  });

  final ColorSortingVisualBand band;
  final double faceScale;
  final double mascotScale;

  /// 0 = calm sparse orchard, 1 = fuller accents.
  final double orchardDetail;

  /// Whether bins show localized color name captions (older bands).
  final bool showBinLabels;

  final double dragLiftScale;
  final double binGlow;

  static ColorSortingVisualProfile forAgeMonths(int ageMonths) {
    if (ageMonths <= 35) {
      return const ColorSortingVisualProfile(
        band: ColorSortingVisualBand.toddler,
        faceScale: 1.2,
        mascotScale: 1.15,
        orchardDetail: 0.45,
        showBinLabels: false,
        dragLiftScale: 1.18,
        binGlow: 0.9,
      );
    }
    if (ageMonths <= 47) {
      return const ColorSortingVisualProfile(
        band: ColorSortingVisualBand.preschool,
        faceScale: 1.0,
        mascotScale: 1.0,
        orchardDetail: 0.75,
        showBinLabels: false,
        dragLiftScale: 1.14,
        binGlow: 0.7,
      );
    }
    return const ColorSortingVisualProfile(
      band: ColorSortingVisualBand.early,
      faceScale: 0.92,
      mascotScale: 0.92,
      orchardDetail: 1.0,
      showBinLabels: true,
      dragLiftScale: 1.12,
      binGlow: 0.55,
    );
  }

  static ColorSortingVisualProfile forBand(ColorSortingBand? band) {
    if (band == null) {
      return forAgeMonths(36);
    }
    return forAgeMonths(band.minMonths);
  }

  /// Bridge so the shared Shape Matching bunny can render in this scene.
  ShapeMatchingVisualProfile get asBunnyProfile {
    final smBand = switch (band) {
      ColorSortingVisualBand.toddler => ShapeMatchingVisualBand.toddler,
      ColorSortingVisualBand.preschool => ShapeMatchingVisualBand.preschool,
      ColorSortingVisualBand.early => ShapeMatchingVisualBand.early,
    };
    return ShapeMatchingVisualProfile(
      band: smBand,
      faceScale: faceScale,
      mascotScale: mascotScale,
      gardenDetail: orchardDetail,
      showChoiceLabels: showBinLabels,
      dragLiftScale: dragLiftScale,
      targetGlow: binGlow,
    );
  }
}

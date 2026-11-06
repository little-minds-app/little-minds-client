import '../shape_matching/shape_matching_visual_profile.dart';
import 'animal_sound_matching_logic.dart';

/// Age-adaptive presentation knobs for the Animal Garden scene.
enum AnimalSoundMatchingVisualBand {
  toddler,
  preschool,
  early,
}

final class AnimalSoundMatchingVisualProfile {
  const AnimalSoundMatchingVisualProfile({
    required this.band,
    required this.faceScale,
    required this.mascotScale,
    required this.gardenDetail,
    required this.showChoiceLabels,
    required this.choiceLiftScale,
    required this.choiceGlow,
  });

  final AnimalSoundMatchingVisualBand band;
  final double faceScale;
  final double mascotScale;

  /// 0 = calm sparse garden, 1 = fuller accents.
  final double gardenDetail;

  /// Whether choices show localized animal name captions (older bands).
  final bool showChoiceLabels;

  final double choiceLiftScale;
  final double choiceGlow;

  static AnimalSoundMatchingVisualProfile forAgeMonths(int ageMonths) {
    if (ageMonths <= 35) {
      return const AnimalSoundMatchingVisualProfile(
        band: AnimalSoundMatchingVisualBand.toddler,
        faceScale: 1.2,
        mascotScale: 1.15,
        gardenDetail: 0.45,
        showChoiceLabels: false,
        choiceLiftScale: 1.12,
        choiceGlow: 0.9,
      );
    }
    if (ageMonths <= 47) {
      return const AnimalSoundMatchingVisualProfile(
        band: AnimalSoundMatchingVisualBand.preschool,
        faceScale: 1.0,
        mascotScale: 1.0,
        gardenDetail: 0.75,
        showChoiceLabels: false,
        choiceLiftScale: 1.1,
        choiceGlow: 0.7,
      );
    }
    return const AnimalSoundMatchingVisualProfile(
      band: AnimalSoundMatchingVisualBand.early,
      faceScale: 0.92,
      mascotScale: 0.92,
      gardenDetail: 1.0,
      showChoiceLabels: true,
      choiceLiftScale: 1.08,
      choiceGlow: 0.55,
    );
  }

  static AnimalSoundMatchingVisualProfile forBand(
    AnimalSoundMatchingBand? band,
  ) {
    if (band == null) {
      return forAgeMonths(36);
    }
    return forAgeMonths(band.minMonths);
  }

  /// Bridge so the shared Shape Matching bunny can render in this scene.
  ShapeMatchingVisualProfile get asBunnyProfile {
    final smBand = switch (band) {
      AnimalSoundMatchingVisualBand.toddler => ShapeMatchingVisualBand.toddler,
      AnimalSoundMatchingVisualBand.preschool =>
        ShapeMatchingVisualBand.preschool,
      AnimalSoundMatchingVisualBand.early => ShapeMatchingVisualBand.early,
    };
    return ShapeMatchingVisualProfile(
      band: smBand,
      faceScale: faceScale,
      mascotScale: mascotScale,
      gardenDetail: gardenDetail,
      showChoiceLabels: showChoiceLabels,
      dragLiftScale: choiceLiftScale,
      targetGlow: choiceGlow,
    );
  }
}

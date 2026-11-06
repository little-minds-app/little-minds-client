import 'dart:math' as math;

import 'animal_sound_matching_constants.dart';

/// Familiar child-safe animal kinds with distinct species-sound pairs.
enum AnimalKind {
  cat,
  dog,
  cow,
  duck,
  bird,
  sheep,
  frog,
  horse,
}

/// How the prompt is presented this round — never confuse visual with audio KPI.
enum AnimalPromptMode {
  /// Bundled animal vocalization is playable.
  audio,

  /// Sound-off, missing asset, or player failure — explicit visual matching.
  visualFallback,
}

/// Age-band configuration derived from selected child age (never a silent default).
final class AnimalSoundMatchingBand {
  const AnimalSoundMatchingBand({
    required this.minMonths,
    required this.maxMonths,
    required this.choiceCount,
  });

  final int minMonths;
  final int maxMonths;

  /// Animal choices for this band (2 / 3 / 4).
  final int choiceCount;

  static AnimalSoundMatchingBand? forAgeMonths(int ageMonths) {
    if (ageMonths < AnimalSoundMatchingConstants.productAgeMinMonths ||
        ageMonths > AnimalSoundMatchingConstants.productAgeMaxMonths) {
      return null;
    }
    if (ageMonths <= 35) {
      return const AnimalSoundMatchingBand(
        minMonths: 24,
        maxMonths: 35,
        choiceCount: 2,
      );
    }
    if (ageMonths <= 47) {
      return const AnimalSoundMatchingBand(
        minMonths: 36,
        maxMonths: 47,
        choiceCount: 3,
      );
    }
    return const AnimalSoundMatchingBand(
      minMonths: 48,
      maxMonths: 71,
      choiceCount: 4,
    );
  }
}

/// Deterministic round — one target animal + band-sized choice set.
final class AnimalSoundMatchingRound {
  const AnimalSoundMatchingRound({
    required this.roundIndex,
    required this.targetAnimal,
    required this.choices,
  });

  final int roundIndex;
  final AnimalKind targetAnimal;

  /// Choice animals in left-to-right display order (length = band.choiceCount).
  /// Always includes [targetAnimal] exactly once.
  final List<AnimalKind> choices;
}

abstract final class AnimalSoundMatchingLogic {
  /// Youngest band stays on the most familiar species.
  static const List<AnimalKind> toddlerPool = [
    AnimalKind.cat,
    AnimalKind.dog,
    AnimalKind.cow,
    AnimalKind.duck,
  ];

  static const List<AnimalKind> preschoolPool = [
    AnimalKind.cat,
    AnimalKind.dog,
    AnimalKind.cow,
    AnimalKind.duck,
    AnimalKind.bird,
    AnimalKind.sheep,
  ];

  static const List<AnimalKind> earlyPool = AnimalKind.values;

  static int _mixSeed(String playSessionId, int roundIndex) {
    var hash = roundIndex;
    for (final unit in playSessionId.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
    }
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  static math.Random _rng(String playSessionId, int roundIndex) {
    return math.Random(_mixSeed(playSessionId, roundIndex));
  }

  /// Animal pool for the band — younger ages get familiar species only.
  static List<AnimalKind> animalPoolForBand(AnimalSoundMatchingBand band) {
    if (band.choiceCount <= 2) return toddlerPool;
    if (band.choiceCount == 3) return preschoolPool;
    return earlyPool;
  }

  /// True when [animal] belongs to the band's species pool.
  static bool isAnimalAllowedForBand(
    AnimalSoundMatchingBand band,
    AnimalKind animal,
  ) {
    return animalPoolForBand(band).contains(animal);
  }

  /// Shared restore / layout gate — choices must be unique, exact band size,
  /// all in-band, and must include the target.
  static bool isValidRestoredLayout({
    required AnimalSoundMatchingBand band,
    required AnimalKind targetAnimal,
    required List<AnimalKind> choices,
  }) {
    if (choices.length != band.choiceCount) return false;
    if (choices.toSet().length != choices.length) return false;
    if (!isAnimalAllowedForBand(band, targetAnimal)) return false;
    if (!choices.contains(targetAnimal)) return false;
    for (final choice in choices) {
      if (!isAnimalAllowedForBand(band, choice)) return false;
    }
    return true;
  }

  static AnimalSoundMatchingRound buildRound({
    required String playSessionId,
    required int roundIndex,
    required AnimalSoundMatchingBand band,
  }) {
    final rng = _rng(playSessionId, roundIndex);
    final pool = List<AnimalKind>.from(animalPoolForBand(band));
    pool.shuffle(rng);

    final choices = pool.take(band.choiceCount).toList(growable: false);
    final targetAnimal = choices[rng.nextInt(choices.length)];

    // Display order: shuffle again so target position is not always first.
    final display = List<AnimalKind>.from(choices)..shuffle(rng);

    return AnimalSoundMatchingRound(
      roundIndex: roundIndex,
      targetAnimal: targetAnimal,
      choices: List.unmodifiable(display),
    );
  }

  static bool isCorrectChoice(
    AnimalSoundMatchingRound round,
    AnimalKind choice,
  ) {
    return choice == round.targetAnimal;
  }
}

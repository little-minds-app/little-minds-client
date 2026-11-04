import 'dart:math' as math;

import 'shape_matching_constants.dart';

/// Pedagogical shape tokens — developer-owned fixtures (ADR-015).
enum ShapeToken {
  circle,
  square,
  triangle,
  star,
  hexagon,
}

/// Age-band configuration derived from selected child age (never a silent default).
final class ShapeMatchingBand {
  const ShapeMatchingBand({
    required this.minMonths,
    required this.maxMonths,
    required this.choiceCount,
  });

  final int minMonths;
  final int maxMonths;
  final int choiceCount;

  static ShapeMatchingBand? forAgeMonths(int ageMonths) {
    if (ageMonths < ShapeMatchingConstants.productAgeMinMonths ||
        ageMonths > ShapeMatchingConstants.productAgeMaxMonths) {
      return null;
    }
    if (ageMonths <= 35) {
      return const ShapeMatchingBand(minMonths: 24, maxMonths: 35, choiceCount: 2);
    }
    if (ageMonths <= 47) {
      return const ShapeMatchingBand(minMonths: 36, maxMonths: 47, choiceCount: 3);
    }
    final choices = ageMonths >= 60 ? 5 : 4;
    return ShapeMatchingBand(minMonths: 48, maxMonths: 71, choiceCount: choices);
  }
}

/// Deterministic round layout — same seed always yields the same target and distractors.
final class ShapeMatchingRound {
  const ShapeMatchingRound({
    required this.roundIndex,
    required this.target,
    required this.choices,
  });

  final int roundIndex;
  final ShapeToken target;
  final List<ShapeToken> choices;
}

abstract final class ShapeMatchingLogic {
  static int _mixSeed(String playSessionId, int roundIndex) {
    var hash = roundIndex;
    for (final unit in playSessionId.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  static math.Random _rng(String playSessionId, int roundIndex) {
    return math.Random(_mixSeed(playSessionId, roundIndex));
  }

  static List<ShapeToken> _poolForBand(ShapeMatchingBand band) {
    const all = ShapeToken.values;
    if (band.choiceCount >= all.length) {
      return all;
    }
    return all.take(band.choiceCount + 1).toList(growable: false);
  }

  static ShapeMatchingRound buildRound({
    required String playSessionId,
    required int roundIndex,
    required ShapeMatchingBand band,
  }) {
    final rng = _rng(playSessionId, roundIndex);
    final pool = _poolForBand(band);
    final target = pool[rng.nextInt(pool.length)];

    final distractorPool = pool.where((s) => s != target).toList();
    distractorPool.shuffle(rng);

    final choices = <ShapeToken>[target];
    while (choices.length < band.choiceCount && distractorPool.isNotEmpty) {
      choices.add(distractorPool.removeAt(0));
    }
    choices.shuffle(rng);

    return ShapeMatchingRound(
      roundIndex: roundIndex,
      target: target,
      choices: List.unmodifiable(choices),
    );
  }

  static bool isCorrectChoice(ShapeMatchingRound round, ShapeToken picked) {
    return picked == round.target;
  }
}

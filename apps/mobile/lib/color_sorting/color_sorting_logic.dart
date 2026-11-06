import 'dart:math' as math;

import 'color_sorting_constants.dart';

/// High-contrast sorting colors — developer-owned fixtures (ADR-015).
enum ColorToken {
  red,
  yellow,
  blue,
  green,
}

/// Playful object silhouettes that carry a [ColorToken] (never color-only).
enum SortObjectForm {
  ball,
  block,
  flower,
  apple,
}

/// Age-band configuration derived from selected child age (never a silent default).
final class ColorSortingBand {
  const ColorSortingBand({
    required this.minMonths,
    required this.maxMonths,
    required this.binCount,
  });

  final int minMonths;
  final int maxMonths;

  /// Destination baskets for this band (2 / 3 / 4).
  final int binCount;

  static ColorSortingBand? forAgeMonths(int ageMonths) {
    if (ageMonths < ColorSortingConstants.productAgeMinMonths ||
        ageMonths > ColorSortingConstants.productAgeMaxMonths) {
      return null;
    }
    if (ageMonths <= 35) {
      return const ColorSortingBand(minMonths: 24, maxMonths: 35, binCount: 2);
    }
    if (ageMonths <= 47) {
      return const ColorSortingBand(minMonths: 36, maxMonths: 47, binCount: 3);
    }
    return const ColorSortingBand(minMonths: 48, maxMonths: 71, binCount: 4);
  }
}

/// Deterministic round — one object + the band's destination bins.
final class ColorSortingRound {
  const ColorSortingRound({
    required this.roundIndex,
    required this.objectColor,
    required this.objectForm,
    required this.bins,
  });

  final int roundIndex;
  final ColorToken objectColor;
  final SortObjectForm objectForm;

  /// Destination bins in left-to-right display order (length = band.binCount).
  final List<ColorToken> bins;
}

abstract final class ColorSortingLogic {
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

  /// Color pool for the band — youngest gets the highest-contrast pair first.
  static List<ColorToken> _poolForBand(ColorSortingBand band) {
    const all = ColorToken.values;
    return all.take(band.binCount).toList(growable: false);
  }

  static List<SortObjectForm> _formsForBand(ColorSortingBand band) {
    if (band.binCount <= 2) {
      return const [SortObjectForm.ball, SortObjectForm.block];
    }
    if (band.binCount == 3) {
      return const [
        SortObjectForm.ball,
        SortObjectForm.block,
        SortObjectForm.flower,
      ];
    }
    return SortObjectForm.values;
  }

  static ColorSortingRound buildRound({
    required String playSessionId,
    required int roundIndex,
    required ColorSortingBand band,
  }) {
    final rng = _rng(playSessionId, roundIndex);
    final pool = _poolForBand(band);
    final objectColor = pool[rng.nextInt(pool.length)];
    final forms = _formsForBand(band);
    final objectForm = forms[rng.nextInt(forms.length)];

    final bins = List<ColorToken>.from(pool)..shuffle(rng);

    return ColorSortingRound(
      roundIndex: roundIndex,
      objectColor: objectColor,
      objectForm: objectForm,
      bins: List.unmodifiable(bins),
    );
  }

  static bool isCorrectBin(ColorSortingRound round, ColorToken bin) {
    return bin == round.objectColor;
  }
}

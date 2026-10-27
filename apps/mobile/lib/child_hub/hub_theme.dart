import 'package:flutter/material.dart';

import 'hub_activity_catalog.dart';

/// Original Little Minds Child Hub visual tokens (LMP-43 polish).
///
/// Calm preschool daylight world — not a competitor clone.
abstract final class HubTheme {
  static const Color skyTop = Color(0xFFE8F6FF);
  static const Color skyMid = Color(0xFFFFF6E8);
  static const Color meadow = Color(0xFFD8F0D4);
  static const Color ink = Color(0xFF1F3A2E);
  static const Color brand = Color(0xFF2E7D32);
  static const Color cardStroke = Color(0x33FFFFFF);
  static const Color softWhite = Color(0xFFFFFFF8);

  static const double cardRadius = 28;
  static const double artRadius = 20;
  static const double minTouch = 72;

  static const LinearGradient worldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, meadow],
    stops: [0.0, 0.55, 1.0],
  );

  static List<BoxShadow> cardShadow({bool passive = false}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: passive ? 0.06 : 0.10),
          blurRadius: passive ? 12 : 18,
          offset: const Offset(0, 8),
        ),
      ];

  static Color accentFor(HubCatalogActivityId id) {
    switch (id) {
      case HubCatalogActivityId.shapeMatching:
        return const Color(0xFF64B5F6); // sky
      case HubCatalogActivityId.colorSorting:
        return const Color(0xFFFF8A65); // coral
      case HubCatalogActivityId.animalSounds:
        return const Color(0xFF7E57C2); // violet
      case HubCatalogActivityId.counting:
        return const Color(0xFF66BB6A); // leaf
      case HubCatalogActivityId.memoryMatching:
        return const Color(0xFFFFD54F); // sunshine
      case HubCatalogActivityId.objectCategories:
        return const Color(0xFF4DB6AC); // teal
    }
  }

  static Color cardFillFor(HubCatalogActivityId id, {required bool playable}) {
    final accent = accentFor(id);
    return Color.alphaBlend(
      accent.withValues(alpha: playable ? 0.28 : 0.14),
      softWhite,
    );
  }
}

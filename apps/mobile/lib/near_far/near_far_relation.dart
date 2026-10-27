import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../game/hitbox_scaler.dart';
import 'near_far_constants.dart';

/// Spatial relation labels for the Near/Far mechanic (Blueprint §5.2).
enum NearFarRelation {
  near,
  far,
  neither,
}

/// Pure drag-position relation math — no Flutter/Flame UI (unit-testable).
abstract final class NearFarRelationLogic {
  /// Classifies the distance between two object centers in a design canvas.
  static NearFarRelation classify({
    required Offset a,
    required Offset b,
    Size design = HitboxScaler.designCanvas,
    double nearMax = NearFarConstants.nearMaxNormalizedDistance,
    double farMin = NearFarConstants.farMinNormalizedDistance,
  }) {
    final diagonal = math.sqrt(
      design.width * design.width + design.height * design.height,
    );
    if (diagonal <= 0) {
      return NearFarRelation.neither;
    }
    final normalized = (a - b).distance / diagonal;
    if (normalized <= nearMax) {
      return NearFarRelation.near;
    }
    if (normalized >= farMin) {
      return NearFarRelation.far;
    }
    return NearFarRelation.neither;
  }

  /// True when [ageMonths] falls in the near_far_32m_v1 band (30–35).
  static bool isAgeEligible(int ageMonths) =>
      ageMonths >= NearFarConstants.ageMinMonths &&
      ageMonths <= NearFarConstants.ageMaxMonths;

  /// Default 32-month fixture positions: clearly far apart on the canvas.
  static ({Offset sock, Offset softToy}) initialFarPositions({
    Size design = HitboxScaler.designCanvas,
  }) {
    final y = design.height * 0.55;
    return (
      sock: Offset(design.width * 0.22, y),
      softToy: Offset(design.width * 0.78, y),
    );
  }

  /// Compact near positions used by tests / reduced-motion snap helpers.
  static ({Offset sock, Offset softToy}) nearPositions({
    Size design = HitboxScaler.designCanvas,
  }) {
    final center = Offset(design.width * 0.5, design.height * 0.55);
    return (
      sock: center.translate(-36, 0),
      softToy: center.translate(36, 0),
    );
  }
}

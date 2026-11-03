import 'package:flutter/services.dart';

import 'app_surface.dart';

/// ADR-018 (Blueprint §40) — LOCKED orientation policy by surface.
///
/// Do not weaken or reopen these rules in LMP-24 scaffolding.
abstract final class OrientationPolicy {
  /// Returns the preferred device orientations for [surface].
  static List<DeviceOrientation> allowedOrientations(AppSurface surface) {
    switch (surface) {
      case AppSurface.childHub:
      case AppSurface.miniGame:
      case AppSurface.gameResults:
      case AppSurface.profileSelection:
        return const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
      case AppSurface.parentGate:
      case AppSurface.parentSettings:
      case AppSurface.parentDashboard:
        return const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
    }
  }

  /// Whether [surface] is locked to landscape only.
  static bool isLandscapeOnly(AppSurface surface) {
    switch (surface) {
      case AppSurface.childHub:
      case AppSurface.miniGame:
      case AppSurface.gameResults:
      case AppSurface.profileSelection:
        return true;
      case AppSurface.parentGate:
      case AppSurface.parentSettings:
      case AppSurface.parentDashboard:
        return false;
    }
  }

  /// Applies ADR-018 preferred orientations for [surface].
  static Future<void> apply(AppSurface surface) {
    return SystemChrome.setPreferredOrientations(allowedOrientations(surface));
  }
}

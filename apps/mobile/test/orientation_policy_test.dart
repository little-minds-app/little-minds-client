import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/orientation/app_surface.dart';
import 'package:little_minds_mobile/orientation/orientation_policy.dart';

/// TC-SHELL-006 — Orientation policy helper maps surface → allowed orientations.
void main() {
  group('OrientationPolicy (ADR-018)', () {
    test('Child Hub / profile / mini-game / results are landscape-only', () {
      for (final surface in [
        AppSurface.childHub,
        AppSurface.profileSelection,
        AppSurface.miniGame,
        AppSurface.gameResults,
      ]) {
        expect(OrientationPolicy.isLandscapeOnly(surface), isTrue);
        expect(
          OrientationPolicy.allowedOrientations(surface),
          unorderedEquals(const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]),
        );
      }
    });

    test('Parent Gate / Settings / Dashboard allow portrait and landscape', () {
      for (final surface in [
        AppSurface.parentGate,
        AppSurface.parentSettings,
        AppSurface.parentDashboard,
      ]) {
        expect(OrientationPolicy.isLandscapeOnly(surface), isFalse);
        expect(
          OrientationPolicy.allowedOrientations(surface),
          unorderedEquals(const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]),
        );
      }
    });
  });
}

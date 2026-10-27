/// Scaffolding values used by LMP-24 bootstrap only.
///
/// **TECHNICAL ASSUMPTION** — not Product Owner–approved product locks.
/// Do not treat these numbers as the V1 device-support contract. See
/// `docs/device-support-matrix.md` (LMP-19) and Blueprint §39.2.
library;

/// Logical-width breakpoint classes (window-driven, not device-model).
/// TECHNICAL ASSUMPTION ⏳ — pending PO approval (LMP-19).
abstract final class ScaffoldingBreakpoints {
  /// Compact (phone-like) when width is below this value.
  static const double compactMaxWidth = 600;

  /// Expanded (tablet-like) when width is at or above this value.
  static const double expandedMinWidth = 840;

  // Medium: [compactMaxWidth, expandedMinWidth)
}

/// Representative CI / widget-test viewport widths × heights.
/// TECHNICAL ASSUMPTION ⏳ — pending PO approval (LMP-19).
abstract final class ScaffoldingViewports {
  static const double compactPhoneWidth = 390;
  static const double compactPhoneHeight = 844;
  static const double largePhoneWidth = 430;
  static const double largePhoneHeight = 932;
  static const double tabletWidth = 1024;
  static const double tabletHeight = 1366;
}

/// Minimum OS targets proposed for local scaffolding only.
/// TECHNICAL ASSUMPTION ⏳ — pending PO approval (LMP-19).
/// Platform project defaults may still follow Flutter tooling until PO locks.
abstract final class ScaffoldingMinOs {
  static const String ios = 'iOS 16.0+';
  static const String android = 'Android 10 (API 29)+';
}

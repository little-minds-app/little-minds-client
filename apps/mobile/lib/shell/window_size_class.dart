import '../config/scaffolding_assumptions.dart';

/// Window size class derived from available width (F-034 adaptive layout).
///
/// Breakpoint numbers are **TECHNICAL ASSUMPTION** scaffolding values.
enum WindowSizeClass {
  compact,
  medium,
  expanded,
}

WindowSizeClass windowSizeClassForWidth(double width) {
  if (width < ScaffoldingBreakpoints.compactMaxWidth) {
    return WindowSizeClass.compact;
  }
  if (width < ScaffoldingBreakpoints.expandedMinWidth) {
    return WindowSizeClass.medium;
  }
  return WindowSizeClass.expanded;
}

extension WindowSizeClassX on WindowSizeClass {
  bool get isExpandedLike =>
      this == WindowSizeClass.expanded || this == WindowSizeClass.medium;
}

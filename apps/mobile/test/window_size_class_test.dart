import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/shell/window_size_class.dart';

void main() {
  group('windowSizeClassForWidth', () {
    test('uses TECHNICAL ASSUMPTION breakpoints without claiming product lock', () {
      expect(
        windowSizeClassForWidth(ScaffoldingBreakpoints.compactMaxWidth - 1),
        WindowSizeClass.compact,
      );
      expect(
        windowSizeClassForWidth(ScaffoldingBreakpoints.compactMaxWidth),
        WindowSizeClass.medium,
      );
      expect(
        windowSizeClassForWidth(ScaffoldingBreakpoints.expandedMinWidth),
        WindowSizeClass.expanded,
      );
    });
  });
}

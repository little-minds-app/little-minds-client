import 'package:flutter/widgets.dart';

import 'screen_time_coordinator.dart';

/// Provides [ScreenTimeCoordinator] to Kids Mode surfaces.
final class ScreenTimeScope extends InheritedNotifier<ScreenTimeCoordinator> {
  const ScreenTimeScope({
    super.key,
    required ScreenTimeCoordinator coordinator,
    required super.child,
  }) : super(notifier: coordinator);

  static ScreenTimeCoordinator? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ScreenTimeScope>()
        ?.notifier;
  }

  static ScreenTimeCoordinator of(BuildContext context) {
    final coordinator = maybeOf(context);
    assert(coordinator != null, 'ScreenTimeScope not found in context');
    return coordinator!;
  }
}

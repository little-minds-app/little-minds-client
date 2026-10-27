import 'package:flutter/widgets.dart';

import 'app_config.dart';

/// Provides [AppConfig] to the widget tree without a state-management package.
class AppConfigScope extends InheritedWidget {
  const AppConfigScope({
    super.key,
    required this.config,
    required super.child,
  });

  final AppConfig config;

  static AppConfig of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppConfigScope>();
    assert(scope != null, 'AppConfigScope not found in widget tree');
    return scope!.config;
  }

  static AppConfig? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppConfigScope>()
        ?.config;
  }

  @override
  bool updateShouldNotify(AppConfigScope oldWidget) {
    return oldWidget.config.environment != config.environment ||
        oldWidget.config.apiBaseUrl != config.apiBaseUrl;
  }
}

import 'package:flutter/widgets.dart';

import 'parent_auth_controller.dart';

class ParentAuthScope extends InheritedNotifier<ParentAuthController> {
  const ParentAuthScope({
    super.key,
    required ParentAuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static ParentAuthController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ParentAuthScope>();
    assert(scope != null, 'ParentAuthScope missing above context');
    return scope!.notifier!;
  }
}

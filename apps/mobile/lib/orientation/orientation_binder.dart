import 'package:flutter/widgets.dart';

import 'app_surface.dart';
import 'orientation_policy.dart';

/// Applies ADR-018 preferred orientations while this route is mounted.
class OrientationBinder extends StatefulWidget {
  const OrientationBinder({
    super.key,
    required this.surface,
    required this.child,
  });

  final AppSurface surface;
  final Widget child;

  @override
  State<OrientationBinder> createState() => _OrientationBinderState();
}

class _OrientationBinderState extends State<OrientationBinder> {
  @override
  void initState() {
    super.initState();
    OrientationPolicy.apply(widget.surface);
  }

  @override
  void didUpdateWidget(covariant OrientationBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surface != widget.surface) {
      OrientationPolicy.apply(widget.surface);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'package:flutter/material.dart';

import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Native Parent Gate placeholder — portrait + landscape (ADR-018).
///
/// State (note field) must survive orientation / window-size changes.
class ParentGateSurface extends StatefulWidget {
  const ParentGateSurface({
    super.key,
    this.onBackToHub,
    this.onOpenSettings,
  });

  final VoidCallback? onBackToHub;
  final VoidCallback? onOpenSettings;

  static const Key surfaceKey = Key('surface-parent-gate');
  static const Key placeholderKey = Key('parent-gate-placeholder');
  static const Key noteFieldKey = Key('parent-gate-note-field');

  @override
  State<ParentGateSurface> createState() => ParentGateSurfaceState();
}

class ParentGateSurfaceState extends State<ParentGateSurface>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _noteController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get noteText => _noteController.text;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return OrientationBinder(
      surface: AppSurface.parentGate,
      child: AdaptiveShell(
        title: 'Parent Gate',
        actions: [
          TextButton(
            key: const Key('nav-parent-settings'),
            onPressed: widget.onOpenSettings,
            child: const Text('Settings'),
          ),
          TextButton(
            key: const Key('nav-back-hub-from-gate'),
            onPressed: widget.onBackToHub,
            child: const Text('Back to Hub'),
          ),
        ],
        body: KeyedSubtree(
          key: ParentGateSurface.surfaceKey,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  key: ParentGateSurface.placeholderKey,
                  'Parent Gate placeholder — real auth/GSM OTP is out of scope for LMP-24.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: ParentGateSurface.noteFieldKey,
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Gate note (state probe)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'window_size_class.dart';

/// Adaptive chrome that recomposes for compact vs expanded windows (F-034).
///
/// Compact: single-column body.
/// Expanded/medium: dual-pane with side navigation chrome (not stretched phone UI).
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.title,
    required this.body,
    this.navigation,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final Widget? navigation;
  final List<Widget> actions;

  static const Key compactChromeKey = Key('shell-compact-chrome');
  static const Key expandedChromeKey = Key('shell-expanded-chrome');
  static const Key dualPaneKey = Key('shell-dual-pane');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = windowSizeClassForWidth(constraints.maxWidth);
        final useExpanded = sizeClass == WindowSizeClass.expanded ||
            sizeClass == WindowSizeClass.medium;

        if (!useExpanded) {
          return Scaffold(
            key: compactChromeKey,
            appBar: AppBar(
              title: Text(title),
              actions: actions,
            ),
            body: SafeArea(
              child: body,
            ),
          );
        }

        return Scaffold(
          key: expandedChromeKey,
          body: SafeArea(
            child: Row(
              key: dualPaneKey,
              children: [
                SizedBox(
                  width: 280,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(child: navigation ?? const SizedBox.shrink()),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      if (actions.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions,
                            ),
                          ),
                        ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

enum ParentFeedbackKind { error, success, info, warning }

/// Accessible status banner — icon, heading, message; not color alone (LMP-131).
class ParentFeedbackBanner extends StatelessWidget {
  const ParentFeedbackBanner({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Yeniden dene',
    this.retryKey,
  });

  final ParentFeedbackKind kind;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Key? retryKey;

  static const Key bannerKey = Key('parent-feedback-banner');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (kind) {
      ParentFeedbackKind.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
        ),
      ParentFeedbackKind.success => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.check_circle_outline,
        ),
      ParentFeedbackKind.info => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.info_outline,
        ),
      ParentFeedbackKind.warning => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.warning_amber_outlined,
        ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $message',
      child: Material(
        key: bannerKey,
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(message, style: TextStyle(color: foreground)),
                      ],
                    ),
                  ),
                ],
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(key: retryKey, onPressed: onRetry, child: Text(retryLabel)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

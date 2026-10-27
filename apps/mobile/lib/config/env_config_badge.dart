import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'app_config_scope.dart';

/// Compact, non-interactive env readout for debug / test visibility (LMP-28).
///
/// Not a marketing card — single-line text so builds are identifiable.
/// Hidden in release profiles unless [forceVisible] is true (widget tests).
class EnvConfigBadge extends StatelessWidget {
  const EnvConfigBadge({
    super.key,
    this.config,
    this.forceVisible = false,
  });

  final AppConfig? config;
  final bool forceVisible;

  static const Key badgeKey = Key('env-config-badge');

  @override
  Widget build(BuildContext context) {
    if (!forceVisible && kReleaseMode) {
      return const SizedBox.shrink();
    }

    final resolved = config ?? AppConfigScope.maybeOf(context);
    if (resolved == null) {
      return const SizedBox.shrink();
    }

    return Text(
      key: badgeKey,
      'env=${resolved.environmentWireName} api=${resolved.apiBaseUrlString}',
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

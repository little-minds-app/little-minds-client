import '../game/activity_registry.dart';
import 'hub_production_telemetry.dart';
import 'shape_matching_activity.dart';

/// Dependencies for LMP-134 production telemetry wiring at the hub composition root.
class HubActivityRegistryOptions {
  const HubActivityRegistryOptions({
    this.telemetryCoordinator,
    this.localeTag = 'en-US',
    this.soundOff = false,
  });

  final HubProductionTelemetryCoordinator? telemetryCoordinator;
  final String localeTag;
  final bool soundOff;
}

/// Production composition root for Kids Hub playable engines (LMP-55 / LMP-134).
///
/// When [options.telemetryCoordinator] is null, Shape Matching uses the local-only
/// buffer. The coordinator's [HubProductionTelemetryCoordinator.reconcileHubRegistry]
/// replaces the registry entry when parent, child, device, consent, and published
/// content version gates are satisfied.
ActivityRegistry createHubActivityRegistry({
  required int? Function() ageMonthsProvider,
  HubActivityRegistryOptions options = const HubActivityRegistryOptions(),
}) {
  return ActivityRegistry([
    ShapeMatchingActivity(
      ageMonthsProvider: ageMonthsProvider,
      localeTag: options.localeTag,
      soundOff: options.soundOff,
    ),
  ]);
}

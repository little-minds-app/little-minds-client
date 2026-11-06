import '../color_sorting/color_sorting_activity.dart';
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

/// Production composition root for Kids Hub playable engines (LMP-55 / LMP-56 / LMP-134).
///
/// When [options.telemetryCoordinator] is null, activities use the local-only
/// buffer. The coordinator's [HubProductionTelemetryCoordinator.reconcileHubRegistry]
/// replaces registry entries when parent, child, device, consent, and published
/// content version gates are satisfied. Color Sorting stays fail-closed for
/// production sync until an authoritative published `content_version_id` exists.
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
    ColorSortingActivity(
      ageMonthsProvider: ageMonthsProvider,
      localeTag: options.localeTag,
      soundOff: options.soundOff,
    ),
  ]);
}

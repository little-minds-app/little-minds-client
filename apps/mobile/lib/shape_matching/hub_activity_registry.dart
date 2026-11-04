import '../game/activity_registry.dart';
import 'shape_matching_activity.dart';

/// Production composition root for Kids Hub playable engines (LMP-55).
ActivityRegistry createHubActivityRegistry({
  required int? Function() ageMonthsProvider,
  String localeTag = 'en-US',
  bool soundOff = false,
}) {
  return ActivityRegistry([
    ShapeMatchingActivity(
      ageMonthsProvider: ageMonthsProvider,
      localeTag: localeTag,
      soundOff: soundOff,
    ),
  ]);
}

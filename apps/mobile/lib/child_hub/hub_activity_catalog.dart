import '../game/activity_registry.dart';
import '../game/learning_activity.dart';
import '../l10n/app_localizations.dart';

/// Blueprint V1 six engines — catalog identity only (F-005 deferred).
///
/// These IDs are stable extension points. Cards stay **passive** until a
/// matching [LearningActivity] with [LearningActivity.isPlayable] is registered.
enum HubCatalogActivityId {
  shapeMatching('shape_matching'),
  colorSorting('color_sorting'),
  animalSounds('animal_sound_matching'),
  counting('counting'),
  memoryMatching('memory_matching'),
  objectCategories('object_categorization');

  const HubCatalogActivityId(this.id);
  final String id;
}

/// Resolved hub tile: catalog metadata + optional playable registry match.
class HubActivityTile {
  const HubActivityTile({
    required this.catalogId,
    required this.title,
    required this.isPlayable,
    this.activity,
  });

  final HubCatalogActivityId catalogId;
  final String title;
  final bool isPlayable;
  final LearningActivity? activity;

  String get id => catalogId.id;
}

/// Builds Child Hub tiles from the static catalog + live [ActivityRegistry].
abstract final class HubActivityCatalog {
  static List<HubActivityTile> resolve({
    required AppLocalizations l10n,
    required ActivityRegistry registry,
  }) {
    return HubCatalogActivityId.values.map((catalogId) {
      final registered = registry.findById(catalogId.id);
      final playable = registered != null && registered.isPlayable;
      return HubActivityTile(
        catalogId: catalogId,
        title: _titleFor(catalogId, l10n),
        isPlayable: playable,
        activity: playable ? registered : null,
      );
    }).toList(growable: false);
  }

  static String _titleFor(HubCatalogActivityId id, AppLocalizations l10n) {
    switch (id) {
      case HubCatalogActivityId.shapeMatching:
        return l10n.activityShapeMatching;
      case HubCatalogActivityId.colorSorting:
        return l10n.activityColorSorting;
      case HubCatalogActivityId.animalSounds:
        return l10n.activityAnimalSounds;
      case HubCatalogActivityId.counting:
        return l10n.activityCounting;
      case HubCatalogActivityId.memoryMatching:
        return l10n.activityMemoryMatching;
      case HubCatalogActivityId.objectCategories:
        return l10n.activityObjectCategories;
    }
  }
}

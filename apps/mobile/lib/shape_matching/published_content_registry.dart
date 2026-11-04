/// Resolves authoritative published [content_version_id] values for hub activities.
///
/// LMP-134: never fabricate production UUIDs. When the backend content release
/// registry has not published an activity version, resolution returns null and
/// hub telemetry stays on the local-only buffer (LMP-55 fail-safe).
abstract class PublishedContentRegistry {
  Future<String?> contentVersionIdForActivity(String activityId);

  void invalidate();
}

/// Default production bootstrap — always unresolved until a real registry is wired.
final class FailClosedPublishedContentRegistry implements PublishedContentRegistry {
  @override
  Future<String?> contentVersionIdForActivity(String activityId) async => null;

  @override
  void invalidate() {}
}

/// In-memory registry for widget/unit tests and future manifest hydration.
final class MapPublishedContentRegistry implements PublishedContentRegistry {
  MapPublishedContentRegistry([Map<String, String>? seed]) : _ids = {...?seed};

  final Map<String, String> _ids;

  void put(String activityId, String contentVersionId) {
    _ids[activityId] = contentVersionId;
  }

  @override
  Future<String?> contentVersionIdForActivity(String activityId) async =>
      _ids[activityId];

  @override
  void invalidate() {}
}

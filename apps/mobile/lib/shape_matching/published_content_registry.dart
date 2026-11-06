import 'activity_publication_fixture.dart';
import 'shape_matching_constants.dart';

/// Authoritative published activity metadata for hub production telemetry.
class PublishedActivityPublication {
  const PublishedActivityPublication({
    required this.contentVersionId,
    required this.consentPolicyVersion,
  });

  final String contentVersionId;
  final String consentPolicyVersion;
}

/// Resolves authoritative published [content_version_id] values for hub activities.
///
/// LMP-134: never fabricate production UUIDs in Dart literals. When resolution
/// fails, hub telemetry stays on the local-only buffer (LMP-55 fail-safe).
abstract class PublishedContentRegistry {
  Future<PublishedActivityPublication?> publicationForActivity(
    String activityId,
  );

  void invalidate();
}

/// Default production bootstrap — always unresolved until a real registry is wired.
final class FailClosedPublishedContentRegistry implements PublishedContentRegistry {
  @override
  Future<PublishedActivityPublication?> publicationForActivity(
    String activityId,
  ) async =>
      null;

  @override
  void invalidate() {}
}

/// In-memory registry for widget/unit tests.
final class MapPublishedContentRegistry implements PublishedContentRegistry {
  MapPublishedContentRegistry([
    Map<String, PublishedActivityPublication>? seed,
  ]) : _publications = {...?seed};

  final Map<String, PublishedActivityPublication> _publications;

  void put(String activityId, PublishedActivityPublication publication) {
    _publications[activityId] = publication;
  }

  @override
  Future<PublishedActivityPublication?> publicationForActivity(
    String activityId,
  ) async =>
      _publications[activityId];

  @override
  void invalidate() {}
}

/// Resolves Shape Matching from the pinned backend publication fixture (LMP-134).
final class PinnedActivityPublicationRegistry implements PublishedContentRegistry {
  PinnedActivityPublicationRegistry({
    ActivityPublicationFixtureLoader? loader,
  }) : _loader = loader ?? ActivityPublicationFixtureLoader();

  final ActivityPublicationFixtureLoader _loader;
  ActivityPublicationRecord? _shapeMatchingCache;

  @override
  void invalidate() {
    _shapeMatchingCache = null;
  }

  @override
  Future<PublishedActivityPublication?> publicationForActivity(
    String activityId,
  ) async {
    if (activityId != ShapeMatchingConstants.activityId) {
      return null;
    }
    _shapeMatchingCache ??= await _loader.requireShapeMatching();
    final record = _shapeMatchingCache!;
    return PublishedActivityPublication(
      contentVersionId: record.contentVersionId,
      consentPolicyVersion: record.consentPolicyVersion,
    );
  }
}

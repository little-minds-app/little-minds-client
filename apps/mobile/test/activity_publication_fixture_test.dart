import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/shape_matching/activity_publication_fixture.dart';
import 'package:little_minds_mobile/shape_matching/activity_publication_pin.dart';
import 'package:little_minds_mobile/shape_matching/published_content_registry.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pinned Shape Matching publication fixture', () {
    test('loader reads LMP-134 seeded content_version_id from assets', () async {
      final record = await ActivityPublicationFixtureLoader().requireShapeMatching();
      expect(record.hubActivityId, ShapeMatchingConstants.activityId);
      expect(record.contentVersionId, '018f1340-0000-4000-8000-000000000001');
      expect(record.consentPolicyVersion, 'synthetic-policy-v1');
      expect(record.isPublished, isTrue);
    });

    test('PinnedActivityPublicationRegistry resolves publication for hub id', () async {
      final registry = PinnedActivityPublicationRegistry();
      final publication = await registry.publicationForActivity(
        ShapeMatchingConstants.activityId,
      );
      expect(publication, isNotNull);
      expect(
        publication!.contentVersionId,
        '018f1340-0000-4000-8000-000000000001',
      );
      expect(publication.consentPolicyVersion, 'synthetic-policy-v1');
    });

    test('pin metadata references backend PR #37 commit', () {
      expect(ActivityPublicationPin.backendCommitSha, startsWith('4f0c592'));
      expect(
        ActivityPublicationPin.backendPullRequestUrl,
        contains('little-minds-backend/pull/37'),
      );
    });
  });
}

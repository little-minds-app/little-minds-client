import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/config/app_environment.dart';
import 'package:little_minds_mobile/shape_matching/hub_bootstrap.dart';
import 'package:little_minds_mobile/shape_matching/published_content_registry.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LMP-134 publication matrix (P2)', () {
    test('P2-02 development resolves pinned synthetic fixture publication', () async {
      final config = AppConfig.resolve(envName: 'development');
      final registry = publishedContentRegistryFor(config);
      expect(registry, isA<PinnedActivityPublicationRegistry>());
      final publication = await registry.publicationForActivity(
        ShapeMatchingConstants.activityId,
      );
      expect(publication, isNotNull);
      expect(
        publication!.contentVersionId,
        '018f1340-0000-4000-8000-000000000001',
      );
    });

    test('P2-03 staging fails closed — fixture is not prod auth', () async {
      final config = AppConfig.resolve(
        envName: 'staging',
        apiBaseUrl: 'https://api.staging.example',
      );
      final registry = publishedContentRegistryFor(config);
      expect(registry, isA<FailClosedPublishedContentRegistry>());
      expect(
        await registry.publicationForActivity(ShapeMatchingConstants.activityId),
        isNull,
      );
    });

    test('P2-04 production fails closed without unsafe override', () async {
      final config = AppConfig.resolve(
        envName: 'production',
        apiBaseUrl: 'https://api.example.com',
      );
      expect(config.environment, AppEnvironment.production);
      final registry = publishedContentRegistryFor(config);
      expect(
        await registry.publicationForActivity(ShapeMatchingConstants.activityId),
        isNull,
      );
    });
  });
}

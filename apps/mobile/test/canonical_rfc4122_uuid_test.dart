import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/parent_scoped_device_id.dart';
import 'package:little_minds_mobile/core/canonical_rfc4122_uuid.dart';
import 'package:little_minds_mobile/shape_matching/hub_production_telemetry.dart';

void main() {
  group('CanonicalRfc4122Uuid', () {
    test('accepts v4, v5 (scoped device), and v7', () {
      expect(CanonicalRfc4122Uuid.isValid('018f1340-0000-4000-8000-000000000001'),
          isTrue);
      expect(
        CanonicalRfc4122Uuid.isValid(
          parentScopedDeviceId(
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          ),
        ),
        isTrue,
      );
      expect(CanonicalRfc4122Uuid.isValid('018f1340-0000-7000-8000-000000000002'),
          isTrue);
    });

    test('rejects malformed and unsupported versions', () {
      expect(CanonicalRfc4122Uuid.isValid('not-a-uuid'), isFalse);
      expect(CanonicalRfc4122Uuid.isValid(''), isFalse);
      // v3 namespace UUID shape
      expect(
        CanonicalRfc4122Uuid.isValid('018f1340-0000-3000-8000-000000000001'),
        isFalse,
      );
      // v5 version nibble but invalid RFC variant
      expect(
        CanonicalRfc4122Uuid.isValid('a9a62045-4dfd-598f-c32d-a73072d887bc'),
        isFalse,
      );
    });
  });

  test('parentScopedDeviceId passes HubProductionTelemetryGate', () {
    const installationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const parentId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    const childId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
    const contentId = '018f1340-0000-4000-8000-000000000001';
    final scopedDeviceId = parentScopedDeviceId(installationId, parentId);

    expect(HubProductionTelemetryGate.isUuid(scopedDeviceId), isTrue);
    expect(
      scopedDeviceId,
      'a9a62045-4dfd-598f-a32d-a73072d887bc',
    );

    final result = HubProductionTelemetryGate.evaluate(
      session: const AuthSession(
        parentId: parentId,
        sessionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        accessToken: 't',
        refreshToken: 't',
        expiresInSeconds: 300,
      ),
      selectedChildId: childId,
      deviceId: scopedDeviceId,
      authorizedDeviceChildId: childId,
      publishedContentVersionId: contentId,
    );
    expect(result.allowed, isTrue);
    expect(result.reason, isNull);
  });
}

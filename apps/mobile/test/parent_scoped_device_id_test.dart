import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/parent_scoped_device_id.dart';

void main() {
  test('matches backend scopedDeviceId digest', () {
    const installationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const parentId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    expect(
      parentScopedDeviceId(installationId, parentId),
      'a9a62045-4dfd-598f-a32d-a73072d887bc',
    );
  });
}

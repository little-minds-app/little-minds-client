import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/child_profiles/child_profiles_controller.dart';

import 'child_profiles_widget_test.dart' show FakeChildProfiles, signedIn;

void main() {
  test('save maps ApiException 400 to actionable profile message', () async {
    final auth = signedIn('11111111-1111-4111-8111-111111111111');
    final fake = _FailingEdit(auth);
    fake.rows.add(ChildProfileResponse(
      childId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      nickname: 'Demo',
      ageMonths: 32,
      preferredLocale: 'tr-TR',
    ));
    final controller = ChildProfilesController(repository: fake, auth: auth);
    await controller.load();
    controller.select('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    final ok = await controller.save(
      childId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      nickname: 'Demo',
      ageMonths: 17,
    );
    expect(ok, isFalse);
    expect(controller.error, contains('sunucu tarafından kabul edilmedi'));
    controller.dispose();
    auth.dispose();
  });

  test('save maps ApiException 409 conflict', () async {
    final auth = signedIn('11111111-1111-4111-8111-111111111111');
    final fake = _StatusEdit(auth, 409);
    fake.rows.add(ChildProfileResponse(
      childId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      nickname: 'Demo',
      ageMonths: 32,
      preferredLocale: 'tr-TR',
    ));
    final controller = ChildProfilesController(repository: fake, auth: auth);
    await controller.load();
    final ok = await controller.save(
      childId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      nickname: 'Demo',
      ageMonths: 33,
    );
    expect(ok, isFalse);
    expect(controller.error, contains('çakışması'));
    controller.dispose();
    auth.dispose();
  });
}

class _FailingEdit extends FakeChildProfiles {
  _FailingEdit(super.auth);

  @override
  Future<ChildProfileResponse> edit({
    required String childId,
    required int ageMonths,
    required String nickname,
    required DateTime referenceDate,
  }) async {
    throw ApiException(400, 'invalid');
  }
}

class _StatusEdit extends FakeChildProfiles {
  _StatusEdit(super.auth, this.status);

  final int status;

  @override
  Future<ChildProfileResponse> edit({
    required String childId,
    required int ageMonths,
    required String nickname,
    required DateTime referenceDate,
  }) async {
    throw ApiException(status, 'error');
  }
}

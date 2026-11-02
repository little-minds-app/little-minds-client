import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/surfaces/optional_parent_profile_surface.dart';

OptionalParentProfile sample({String? firstName}) => OptionalParentProfile(
  firstName: firstName, lastName: null,
  ageBandOptional: null, genderOptional: null,
  numberOfChildrenOptional: null, occupationOptional: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('optional unified parent form supports skip, save and clearing on small phone', (tester) async {
    tester.view.physicalSize = const Size(700, 370);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = ParentAuthController(repository: ParentAuthRepository(
      config: AppConfig.developmentLocal, tokenStore: InMemoryAuthTokenStore(),
    ));
    addTearDown(auth.dispose);
    auth.seedAuthenticatedSessionForTests(const AuthSession(
      accessToken: 'synthetic', refreshToken: 'synthetic',
      parentId: '11111111-1111-4111-8111-111111111111',
      sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      expiresInSeconds: 900,
    ));
    var saves = 0;
    var clears = 0;
    var skips = 0;
    var record = sample();
    await tester.pumpWidget(MaterialApp(home: OptionalParentProfileSurface(
      auth: auth, config: AppConfig.developmentLocal, onBack: () => skips++,
      loadForTest: () async => record,
      saveForTest: (input) async {
        saves++;
        record = sample(firstName: input.firstName);
        return record;
      },
      clearForTest: () async {
        clears++;
        record = sample();
        return record;
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Ad'), findsOneWidget);
    expect(find.text('Soyad'), findsOneWidget);
    expect(find.text('Mesleki durum'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Çağrı');
    await tester.ensureVisible(find.byKey(const Key('parent-profile-save')));
    await tester.tap(find.byKey(const Key('parent-profile-save')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(record.firstName, 'Çağrı');
    await tester.ensureVisible(find.byKey(const Key('parent-profile-clear')));
    await tester.tap(find.byKey(const Key('parent-profile-clear')));
    await tester.pumpAndSettle();
    expect(clears, 1);
    expect(record.firstName, isNull);
    await tester.ensureVisible(find.byKey(const Key('parent-profile-skip')));
    await tester.tap(find.byKey(const Key('parent-profile-skip')));
    expect(skips, 1);
    expect(tester.takeException(), isNull);
  });
}

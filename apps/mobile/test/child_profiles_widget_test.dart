import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/child_profiles/child_profile_repository.dart';
import 'package:little_minds_mobile/child_profiles/child_profiles_controller.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/surfaces/profile_selection_surface.dart';

class FakeChildProfiles extends ChildProfileRepository {
  FakeChildProfiles(ParentAuthController auth)
      : super(config: AppConfig.developmentLocal, auth: auth);
  final List<ChildProfileResponse> rows = [];
  bool failNextLoad = false;
  Completer<List<ChildProfileResponse>>? pendingLoad;
  int creates = 0;
  int edits = 0;

  @override
  Future<List<ChildProfileResponse>> list() async {
    if (pendingLoad != null) return pendingLoad!.future;
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('offline');
    }
    return List.of(rows);
  }

  @override
  Future<String> create({
    required int ageMonths,
    required String nickname,
    required DateTime referenceDate,
  }) async {
    creates++;
    final id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    rows.add(ChildProfileResponse(
      childId: id, nickname: nickname,
      ageMonths: ageMonths, preferredLocale: 'tr-TR',
    ));
    return id;
  }

  @override
  Future<ChildProfileResponse> edit({
    required String childId,
    required int ageMonths,
    required String nickname,
    required DateTime referenceDate,
  }) async {
    edits++;
    final index = rows.indexWhere((child) => child.childId == childId);
    final updated = ChildProfileResponse(
      childId: childId, nickname: nickname,
      ageMonths: ageMonths, preferredLocale: 'tr-TR',
    );
    rows[index] = updated;
    return updated;
  }
}

ParentAuthController signedIn(String parentId) {
  final auth = ParentAuthController(
    repository: ParentAuthRepository(
      config: AppConfig.developmentLocal,
      tokenStore: InMemoryAuthTokenStore(),
    ),
  );
  auth.seedAuthenticatedSessionForTests(AuthSession(
    accessToken: 'synthetic-token',
    refreshToken: 'synthetic-refresh',
    parentId: parentId,
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    expiresInSeconds: 900,
  ));
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stale result from prior parent cannot populate the next parent state', () async {
    final auth = signedIn('11111111-1111-4111-8111-111111111111');
    final fake = FakeChildProfiles(auth);
    final pending = Completer<List<ChildProfileResponse>>();
    fake.pendingLoad = pending;
    final controller = ChildProfilesController(repository: fake, auth: auth);
    final running = controller.load();
    auth.seedAuthenticatedSessionForTests(const AuthSession(
      accessToken: 'other-token', refreshToken: 'other-refresh',
      parentId: '22222222-2222-4222-8222-222222222222',
      sessionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      expiresInSeconds: 900,
    ));
    pending.complete([ChildProfileResponse(
      childId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', nickname: 'Old family',
      ageMonths: 24, preferredLocale: 'tr-TR',
    )]);
    await running;
    expect(controller.children, isEmpty);
    expect(controller.selectedId, isNull);
    expect(controller.busy, isFalse);
    controller.dispose();
    auth.dispose();
  });

  testWidgets('parent can create, select, and edit a fictional child without DOB', (tester) async {
    tester.view.physicalSize = const Size(1024, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = signedIn('11111111-1111-4111-8111-111111111111');
    final fake = FakeChildProfiles(auth);
    final profiles = ChildProfilesController(repository: fake, auth: auth);
    addTearDown(profiles.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ProfileSelectionSurface(controller: profiles, allowManage: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Henüz çocuk profili yok.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-nickname')), 'Demo');
    await tester.enterText(find.byKey(const Key('profile-age-months')), '32');
    await tester.ensureVisible(find.byKey(ProfileSelectionSurface.saveKey));
    await tester.tap(find.byKey(ProfileSelectionSurface.saveKey));
    await tester.pumpAndSettle();
    expect(fake.creates, 1);
    expect(profiles.selectedId, fake.rows.single.childId);
    await tester.tap(find.text('Düzenle'));
    await tester.enterText(find.byKey(const Key('profile-nickname')), 'Updated');
    await tester.enterText(find.byKey(const Key('profile-age-months')), '33');
    await tester.ensureVisible(find.byKey(ProfileSelectionSurface.saveKey));
    await tester.tap(find.byKey(ProfileSelectionSurface.saveKey));
    await tester.pumpAndSettle();
    expect(fake.edits, 1);
    expect(profiles.children.single.nickname, 'Updated');
  });

  testWidgets('kids mode shows selection but never exposes create/edit', (tester) async {
    final auth = signedIn('11111111-1111-4111-8111-111111111111');
    final fake = FakeChildProfiles(auth);
    fake.rows.add(ChildProfileResponse(
      childId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      nickname: 'Fictional', ageMonths: 24, preferredLocale: 'tr-TR',
    ));
    final controller = ChildProfilesController(repository: fake, auth: auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(home: ProfileSelectionSurface(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileSelectionSurface.saveKey), findsNothing);
    expect(find.text('Düzenle'), findsNothing);
    await tester.tap(find.byKey(const Key('profile-select-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')));
    expect(controller.selectedId, fake.rows.single.childId);
    auth.seedAuthenticatedSessionForTests(const AuthSession(
      accessToken: 'other-token', refreshToken: 'other-refresh',
      parentId: '22222222-2222-4222-8222-222222222222',
      sessionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      expiresInSeconds: 900,
    ));
    await tester.pump();
    expect(controller.selectedId, isNull);
    expect(controller.children, isEmpty);
  });

  testWidgets('load failure shows retry and later recovers', (tester) async {
    final auth = signedIn('11111111-1111-4111-8111-111111111111');
    final fake = FakeChildProfiles(auth)..failNextLoad = true;
    final controller = ChildProfilesController(repository: fake, auth: auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(home: ProfileSelectionSurface(controller: controller, allowManage: true)));
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileSelectionSurface.retryKey), findsOneWidget);
    await tester.tap(find.byKey(ProfileSelectionSurface.retryKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileSelectionSurface.retryKey), findsNothing);
    expect(find.text('Henüz çocuk profili yok.'), findsOneWidget);
  });
}

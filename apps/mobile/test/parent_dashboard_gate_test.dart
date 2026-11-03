import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/child_profiles/child_profiles_controller.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_repository.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_window.dart';
import 'package:little_minds_mobile/parent_gate/parent_gate_api.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_dashboard_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';

import 'child_profiles_widget_test.dart' show FakeChildProfiles;
import 'parent_dashboard_fixtures.dart';

class _FakeGateApi extends ParentGateApi {
  _FakeGateApi() : super(AppConfig.developmentLocal);

  @override
  void authorize(AuthSession session) {}

  @override
  Future<bool> configured() async => true;

  @override
  Future<String> verify(String pin) async {
    if (pin != '654321') throw StateError('invalid');
    return 'opaque-gate-token';
  }
}

class _FakeKpiRepo extends SessionKpiRepository {
  _FakeKpiRepo(ParentAuthController auth)
      : super(config: AppConfig.developmentLocal, auth: auth);

  @override
  Future<SessionKpiResponse> fetch({
    required SessionKpiWindow window,
    String? childId,
  }) async {
    return sampleKpiResponse(eligible: 3);
  }
}

Future<void> _pumpFrames(WidgetTester tester, [int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<ChildProfilesController> _profilesWithSelection(ParentAuthController auth) async {
  const childId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  final fakeProfiles = FakeChildProfiles(auth);
  fakeProfiles.rows.add(ChildProfileResponse(
    childId: childId,
    nickname: 'Ada',
    ageMonths: 32,
    preferredLocale: 'tr-TR',
  ));
  final profiles = ChildProfilesController(repository: fakeProfiles, auth: auth);
  await profiles.load();
  profiles.select(childId);
  return profiles;
}

Future<void> _unlockPin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, '654321');
  await tester.tap(find.byKey(const Key('parent-pin-verify')));
  await tester.pumpAndSettle();
}

Future<void> _openDashboardFromHub(WidgetTester tester, LittleMindsApp app) async {
  await tester.pumpWidget(app);
  await _pumpFrames(tester);
  await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
  await _pumpFrames(tester);
  await tester.tap(find.byKey(const Key('parent-auth-open-settings')));
  await _pumpFrames(tester);
  await _unlockPin(tester);
  expect(find.byKey(ParentSettingsSurface.parentDashboardKey), findsOneWidget);
  await tester.tap(find.byKey(ParentSettingsSurface.parentDashboardKey));
  await tester.pumpAndSettle();
}

ParentAuthController _authenticatedAuth() {
  final auth = ParentAuthController(
    repository: ParentAuthRepository(
      config: AppConfig.developmentLocal,
      tokenStore: InMemoryAuthTokenStore(),
    ),
  );
  auth.seedAuthenticatedSessionForTests(const AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    parentId: '11111111-1111-4111-8111-111111111111',
    expiresInSeconds: 900,
  ));
  return auth;
}

LittleMindsApp _app({
  required ParentAuthController auth,
  required ChildProfilesController profiles,
  required SessionKpiRepository kpiRepo,
}) {
  return LittleMindsApp(
    parentAuthController: auth,
    childProfilesController: profiles,
    parentGateApi: _FakeGateApi(),
    sessionKpiRepository: kpiRepo,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authenticated parent cannot bypass PIN to reach dashboard', (tester) async {
    final auth = _authenticatedAuth();
    addTearDown(auth.dispose);
    final profiles = await _profilesWithSelection(auth);
    addTearDown(profiles.dispose);

    await tester.pumpWidget(_app(auth: auth, profiles: profiles, kpiRepo: _FakeKpiRepo(auth)));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.authenticatedKey), findsOneWidget);

    await tester.tap(find.byKey(const Key('parent-auth-open-settings')));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('parent-pin-verify')), findsOneWidget);
    expect(find.byKey(ParentSettingsSurface.parentDashboardKey), findsNothing);
    expect(find.byKey(ParentDashboardSurface.surfaceKey), findsNothing);
  });

  testWidgets('real PIN flow reaches dashboard then expires grant while open',
      (tester) async {
    final auth = _authenticatedAuth();
    addTearDown(auth.dispose);
    final profiles = await _profilesWithSelection(auth);
    addTearDown(profiles.dispose);

    await _openDashboardFromHub(
      tester,
      _app(auth: auth, profiles: profiles, kpiRepo: _FakeKpiRepo(auth)),
    );
    expect(find.byKey(ParentDashboardSurface.contentKey), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    await _pumpFrames(tester);

    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.surfaceKey), findsNothing);

    await tester.tap(find.byKey(const Key('parent-auth-open-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parent-pin-verify')), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.surfaceKey), findsNothing);
  });

  testWidgets('background inactive clears dashboard without reopening via auth shortcut',
      (tester) async {
    final auth = _authenticatedAuth();
    addTearDown(auth.dispose);
    final profiles = await _profilesWithSelection(auth);
    addTearDown(profiles.dispose);

    await _openDashboardFromHub(
      tester,
      _app(auth: auth, profiles: profiles, kpiRepo: _FakeKpiRepo(auth)),
    );
    expect(find.byKey(ParentDashboardSurface.surfaceKey), findsOneWidget);

    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.surfaceKey), findsNothing);
    expect(find.byKey(ParentSettingsSurface.parentDashboardKey), findsNothing);
  });
}

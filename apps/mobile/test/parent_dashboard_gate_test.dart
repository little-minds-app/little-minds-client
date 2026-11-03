import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/parent_gate/parent_gate_api.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_dashboard_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';

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

Future<void> _pumpFrames(WidgetTester tester, [int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _unlockParentSettings(WidgetTester tester, LittleMindsApp app) async {
  await tester.pumpWidget(app);
  await _pumpFrames(tester);
  await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
  await _pumpFrames(tester);
  await tester.tap(find.byKey(const Key('parent-auth-open-settings')));
  await _pumpFrames(tester);
  await tester.enterText(find.byType(TextField).first, '654321');
  await tester.tap(find.byKey(const Key('parent-pin-verify')));
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

LittleMindsApp _app(ParentAuthController auth) {
  return LittleMindsApp(
    parentAuthController: auth,
    parentGateApi: _FakeGateApi(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authenticated parent cannot bypass PIN to reach dashboard', (tester) async {
    final auth = _authenticatedAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(auth));
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

  testWidgets('expired PIN grant clears adult access on parent settings', (tester) async {
    final auth = _authenticatedAuth();
    addTearDown(auth.dispose);

    await _unlockParentSettings(tester, _app(auth));
    expect(find.byKey(ParentSettingsSurface.surfaceKey), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    await _pumpFrames(tester);

    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(ParentSettingsSurface.surfaceKey), findsNothing);
  });

  testWidgets('background lifecycle clears adult grant on parent settings',
      (tester) async {
    final auth = _authenticatedAuth();
    addTearDown(auth.dispose);

    await _unlockParentSettings(tester, _app(auth));
    expect(find.byKey(ParentSettingsSurface.surfaceKey), findsOneWidget);

    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(ParentSettingsSurface.surfaceKey), findsNothing);
  });
}

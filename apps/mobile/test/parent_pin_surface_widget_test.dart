import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/parent_gate/parent_gate_api.dart';
import 'package:little_minds_mobile/parent_gate/parent_pin_surface.dart';

class _FakeGateApi extends ParentGateApi {
  _FakeGateApi({required this.hasPin}) : super(AppConfig.developmentLocal);

  bool hasPin;
  int verifyCount = 0;
  int proofs = 0;
  int setups = 0;
  @override
  void authorize(AuthSession session) {}
  @override
  Future<bool> configured() async => hasPin;
  @override
  Future<String> verify(String pin) async {
    verifyCount++;
    if (pin != '654321') throw StateError('invalid');
    return 'opaque-gate-token';
  }
  @override
  Future<String> beginIdentityProof(String channel, String identifier) async => 'challenge-id';
  @override
  Future<String> confirmIdentityProof(String provider, String challengeId, String code) async {
    proofs++;
    if (code != '123456') throw StateError('invalid OTP');
    return 'fresh-one-time-proof';
  }
  @override
  Future<void> setPin(String pin, String confirmation, String proof, {required bool reset}) async {
    if (pin != confirmation || proof != 'fresh-one-time-proof') throw StateError('invalid PIN setup');
    setups++;
    hasPin = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('LMP-42 PIN denies wrong code and unlocks with correct code at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = ParentAuthController(repository: ParentAuthRepository(
        config: AppConfig.developmentLocal, tokenStore: InMemoryAuthTokenStore(),
      ));
      addTearDown(auth.dispose);
      auth.seedAuthenticatedSessionForTests(const AuthSession(
        accessToken: 'access', refreshToken: 'refresh',
        sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        parentId: '11111111-1111-4111-8111-111111111111',
        expiresInSeconds: 900,
      ));
      final api = _FakeGateApi(hasPin: true);
      String? unlocked;
      await tester.pumpWidget(MaterialApp(home: ParentPinSurface(
        auth: auth, config: AppConfig.developmentLocal,
        api: api, onBack: () {}, onUnlocked: (token) => unlocked = token,
      )));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '111111');
      await tester.tap(find.byKey(const Key('parent-pin-verify')));
      await tester.pumpAndSettle();
      expect(unlocked, isNull);
      expect(find.byKey(const Key('parent-pin-error')), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '654321');
      await tester.tap(find.byKey(const Key('parent-pin-verify')));
      await tester.pumpAndSettle();
      expect(unlocked, 'opaque-gate-token');
      expect(api.verifyCount, 2);
    });
  }

  testWidgets('LMP-42 setup requires OTP proof and confirmed PIN', (tester) async {
    final auth = ParentAuthController(repository: ParentAuthRepository(
      config: AppConfig.developmentLocal, tokenStore: InMemoryAuthTokenStore(),
    ));
    addTearDown(auth.dispose);
    auth.seedAuthenticatedSessionForTests(const AuthSession(
      accessToken: 'access', refreshToken: 'refresh',
      sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      parentId: '11111111-1111-4111-8111-111111111111',
      expiresInSeconds: 900,
    ));
    final api = _FakeGateApi(hasPin: false);
    await tester.pumpWidget(MaterialApp(home: ParentPinSurface(
      auth: auth, config: AppConfig.developmentLocal,
      api: api, onBack: () {}, onUnlocked: (_) {},
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '+905551112233');
    await tester.tap(find.text('Doğrulama kodu gönder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('OTP doğrula'));
    await tester.pumpAndSettle();
    expect(api.proofs, 1);
    await tester.enterText(find.byType(TextField).first, '654321');
    await tester.enterText(find.byType(TextField).last, '654321');
    await tester.ensureVisible(find.byKey(const Key('parent-pin-setup')));
    await tester.tap(find.byKey(const Key('parent-pin-setup')));
    await tester.pumpAndSettle();
    expect(api.setups, 1);
    expect(find.byKey(const Key('parent-pin-verify')), findsOneWidget);
  });
}

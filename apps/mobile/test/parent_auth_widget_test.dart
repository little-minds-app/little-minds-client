import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/auth/auth_error.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/shell/adaptive_shell.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';

class _RecordingParentAuthRepository extends ParentAuthRepository {
  _RecordingParentAuthRepository({required super.tokenStore})
      : super(config: AppConfig.developmentLocal);

  int phoneStarts = 0;
  bool failNextStart = false;

  @override
  Future<PhoneOtpStartResponse> startPhoneOtp(String phone) async {
    phoneStarts++;
    if (failNextStart) {
      throw const ParentAuthFailure(
        code: 'sms_unavailable',
        message: 'SMS is temporarily unavailable.',
      );
    }
    return PhoneOtpStartResponse(
      challengeId: '00000000-0000-4000-8000-000000000099',
      expiresIn: PhoneOtpStartResponseExpiresInEnum.number300,
      resendAfter: PhoneOtpStartResponseResendAfterEnum.number60,
    );
  }

  @override
  Future<AuthSession> verifyPhoneOtp({
    required String challengeId,
    required String code,
  }) async {
    return AuthSession(
      accessToken: 'access-test',
      refreshToken: 'refresh-test',
      sessionId: '00000000-0000-4000-8000-000000000001',
      parentId: '00000000-0000-4000-8000-000000000002',
      expiresInSeconds: 900,
    );
  }
}

Future<void> _pumpFrames(WidgetTester tester, [int times = 3]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<ParentAuthController> _authWithRepo(_RecordingParentAuthRepository repo) async {
  final controller = ParentAuthController(repository: repo);
  await controller.bootstrap();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-AUTH-W01 onboarding shows phone/email and disabled social',
      (tester) async {
    final repo = _RecordingParentAuthRepository(
      tokenStore: InMemoryAuthTokenStore(),
    );
    final auth = await _authWithRepo(repo);
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        parentAuthController: auth,
      ),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);

    expect(find.byKey(ParentGateSurface.onboardingKey), findsOneWidget);
    expect(find.byKey(const Key('parent-auth-apple')), findsOneWidget);
    expect(find.byKey(const Key('parent-auth-google')), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNWidgets(2));
  });

  testWidgets('TC-AUTH-W05 social buttons disabled without native SDK',
      (tester) async {
    final repo = _RecordingParentAuthRepository(
      tokenStore: InMemoryAuthTokenStore(),
    );
    final auth = await _authWithRepo(repo);
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        parentAuthController: auth,
      ),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);

    for (final key in [
      const Key('parent-auth-apple'),
      const Key('parent-auth-google'),
    ]) {
      expect(tester.widget<OutlinedButton>(find.byKey(key)).onPressed, isNull);
    }
    expect(find.textContaining('unavailable'), findsNWidgets(2));
  });

  testWidgets('TC-AUTH-W02 phone validation and OTP verify success',
      (tester) async {
    final repo = _RecordingParentAuthRepository(
      tokenStore: InMemoryAuthTokenStore(),
    );
    final auth = await _authWithRepo(repo);
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        parentAuthController: auth,
      ),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('parent-auth-phone-entry')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('parent-auth-phone-submit')));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.errorBannerKey), findsOneWidget);

    await tester.enterText(
      find.byKey(ParentGateSurface.phoneFieldKey),
      '+905551112233',
    );
    await tester.tap(find.byKey(const Key('parent-auth-phone-submit')));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.otpFieldKey), findsOneWidget);

    await tester.enterText(find.byKey(ParentGateSurface.otpFieldKey), '123456');
    await tester.tap(find.byKey(const Key('parent-auth-phone-submit')));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.authenticatedKey), findsOneWidget);
  });

  testWidgets('TC-AUTH-W03 error/retry banner on SMS failure', (tester) async {
    final repo = _RecordingParentAuthRepository(
      tokenStore: InMemoryAuthTokenStore(),
    );
    repo.failNextStart = true;
    final auth = await _authWithRepo(repo);
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        parentAuthController: auth,
      ),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('parent-auth-phone-entry')));
    await _pumpFrames(tester);
    await tester.enterText(
      find.byKey(ParentGateSurface.phoneFieldKey),
      '+905551112233',
    );
    await tester.tap(find.byKey(const Key('parent-auth-phone-submit')));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.errorBannerKey), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('TC-AUTH-W04 phone field survives rotation (F-034)',
      (tester) async {
    final view = tester.view;
    view.physicalSize = Size(
      ScaffoldingViewports.compactPhoneWidth,
      ScaffoldingViewports.compactPhoneHeight,
    );
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final repo = _RecordingParentAuthRepository(
      tokenStore: InMemoryAuthTokenStore(),
    );
    final auth = await _authWithRepo(repo);
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        parentAuthController: auth,
      ),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('parent-auth-phone-entry')));
    await _pumpFrames(tester);
    await tester.enterText(
      find.byKey(ParentGateSurface.phoneFieldKey),
      'keep-phone-state',
    );

    view.physicalSize = Size(
      ScaffoldingViewports.tabletWidth,
      ScaffoldingViewports.tabletHeight,
    );
    await _pumpFrames(tester);
    expect(find.text('keep-phone-state'), findsOneWidget);
    expect(find.byKey(AdaptiveShell.expandedChromeKey), findsOneWidget);
  });
}

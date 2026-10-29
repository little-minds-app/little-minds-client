import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_profile_result.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';

class _RotatingFetchRepo extends ParentAuthRepository {
  _RotatingFetchRepo({required InMemoryAuthTokenStore store})
      : _store = store,
        super(config: AppConfig.developmentLocal, tokenStore: store);

  final InMemoryAuthTokenStore _store;
  String? logoutRefreshToken;

  static const rotated = AuthSession(
    accessToken: 'access-rotated',
    refreshToken: 'refresh-rotated',
    sessionId: '00000000-0000-4000-8000-000000000001',
    parentId: '00000000-0000-4000-8000-000000000002',
    expiresInSeconds: 900,
  );

  @override
  Future<ParentAuthProfileResult> fetchParentProfile(AuthSession session) async {
    await _store.writeSession(rotated);
    return ParentAuthProfileResult(
      profile: ParentMeResponse(
        parentId: rotated.parentId,
        locale: 'tr-TR',
        timezone: 'UTC',
        lifecycle: ParentMeResponseLifecycleEnum.active,
      ),
      session: rotated,
    );
  }

  @override
  Future<void> logout(AuthSession session) async {
    logoutRefreshToken = session.refreshToken;
    await super.logout(session);
  }
}

void main() {
  ParentAuthController controller() {
    return ParentAuthController(
      repository: ParentAuthRepository(
        config: AppConfig.developmentLocal,
        tokenStore: InMemoryAuthTokenStore(),
      ),
    );
  }

  test('TC-AUTH-U01 rejects short phone before API', () async {
    final auth = controller();
    await auth.submitPhone('12');
    expect(auth.lastError?.code, 'invalid_request');
    expect(auth.step, ParentAuthStep.onboarding);
  });

  test('TC-AUTH-U03 bootstrap syncs rotated session after profile fetch',
      () async {
    final store = InMemoryAuthTokenStore();
    await store.writeSession(
      const AuthSession(
        accessToken: 'access-stale',
        refreshToken: 'refresh-stale',
        sessionId: '00000000-0000-4000-8000-000000000001',
        parentId: '00000000-0000-4000-8000-000000000002',
        expiresInSeconds: 900,
      ),
    );
    final repo = _RotatingFetchRepo(store: store);
    final auth = ParentAuthController(repository: repo);
    await auth.bootstrap();
    expect(auth.session?.refreshToken, 'refresh-rotated');
    await auth.logout();
    expect(repo.logoutRefreshToken, 'refresh-rotated');
  });

  test('TC-AUTH-U02 rejects invalid email before API', () async {
    final auth = controller();
    auth.openEmailFlow();
    await auth.submitEmail('not-an-email');
    expect(auth.lastError?.code, 'invalid_request');
    expect(auth.step, ParentAuthStep.emailEntry);
  });
}

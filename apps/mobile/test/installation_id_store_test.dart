import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/installation_id_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';

void main() {
  test('TC-08: installation identity survives account switch and new repository', () async {
    final installation = MemoryInstallationIdStore();
    final tokens = InMemoryAuthTokenStore();
    final repoA = ParentAuthRepository(
      config: AppConfig.developmentLocal,
      tokenStore: tokens,
      installationIdStore: installation,
    );
    final idA = await repoA.deviceId();
    await tokens.writeSession(const AuthSession(
      accessToken: 'a', refreshToken: 'a-refresh',
      parentId: '11111111-1111-4111-8111-111111111111',
      sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      expiresInSeconds: 900,
    ));
    await tokens.clear(); // Logout must not erase installation identity.
    final repoB = ParentAuthRepository(
      config: AppConfig.developmentLocal,
      tokenStore: tokens,
      installationIdStore: installation,
    );
    expect(await repoB.deviceId(), idA);
    expect(await tokens.readSession(), isNull);
    expect(await repoA.deviceId(), idA);
  });
}

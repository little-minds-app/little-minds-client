import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';

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

  test('TC-AUTH-U02 rejects invalid email before API', () async {
    final auth = controller();
    auth.openEmailFlow();
    await auth.submitEmail('not-an-email');
    expect(auth.lastError?.code, 'invalid_request');
    expect(auth.step, ParentAuthStep.emailEntry);
  });
}

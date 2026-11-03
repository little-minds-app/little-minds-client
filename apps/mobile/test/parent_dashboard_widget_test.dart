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
import 'package:little_minds_mobile/parent_dashboard/parent_dashboard_controller.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_repository.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_window.dart';
import 'package:little_minds_mobile/surfaces/parent_dashboard_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';

import 'child_profiles_widget_test.dart' show FakeChildProfiles;
import 'parent_dashboard_fixtures.dart';

class FakeSessionKpiRepository extends SessionKpiRepository {
  FakeSessionKpiRepository(ParentAuthController auth)
      : super(config: AppConfig.developmentLocal, auth: auth);

  SessionKpiResponse? response;

  @override
  Future<SessionKpiResponse> fetch({
    required SessionKpiWindow window,
    String? childId,
  }) async {
    if (response == null) throw ApiException(503, 'offline');
    return response!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Parent Settings entry opens dashboard with mission unavailable',
      (tester) async {
    final auth = ParentAuthController(
      repository: ParentAuthRepository(
        config: AppConfig.developmentLocal,
        tokenStore: InMemoryAuthTokenStore(),
      ),
    );
    auth.seedAuthenticatedSessionForTests(const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      parentId: '11111111-1111-4111-8111-111111111111',
      sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      expiresInSeconds: 900,
    ));

    final fakeProfiles = FakeChildProfiles(auth);
    fakeProfiles.rows.add(ChildProfileResponse(
      childId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      nickname: 'Ada',
      ageMonths: 32,
      preferredLocale: 'tr-TR',
    ));
    final profiles = ChildProfilesController(repository: fakeProfiles, auth: auth);
    await profiles.load();
    profiles.select('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');

    final repo = FakeSessionKpiRepository(auth);
    repo.response = sampleKpiResponse();

    final dashboardController = ParentDashboardController(
      repository: repo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ParentDashboardSurface.contentKey), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.byKey(ParentDashboardSurface.missionUnavailableKey), findsOneWidget);
    expect(
      find.text(ParentDashboardController.missionStatusUnavailableMessage),
      findsOneWidget,
    );
  });

  testWidgets('Child Hub does not expose dashboard entry without parent path',
      (tester) async {
    await tester.pumpWidget(LittleMindsApp(
      testOnlyAdultAccess: true,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(ParentSettingsSurface.parentDashboardKey), findsNothing);
    expect(find.byKey(ParentDashboardSurface.surfaceKey), findsNothing);
  });
}

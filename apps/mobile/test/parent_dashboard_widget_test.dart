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
import 'package:little_minds_mobile/parent_dashboard/mission_status_repository.dart';
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
  Object? throwError;

  @override
  Future<SessionKpiResponse> fetch({
    required SessionKpiWindow window,
    String? childId,
  }) async {
    if (throwError != null) throw throwError!;
    if (response == null) throw ApiException(503, 'offline');
    return response!;
  }
}

class FakeMissionStatusRepository extends MissionStatusRepository {
  FakeMissionStatusRepository(ParentAuthController auth)
      : super(config: AppConfig.developmentLocal, auth: auth);

  MissionStatusListResponse? response;
  Object? throwError;

  @override
  Future<MissionStatusListResponse> fetch({
    required String childId,
    required SessionKpiWindow window,
    int? limit,
  }) async {
    if (throwError != null) throw throwError!;
    return response ?? sampleMissionStatusResponse();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard shows parent-reported mission row from server',
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
    final missionRepo = FakeMissionStatusRepository(auth)
      ..response = sampleMissionStatusResponse();

    final dashboardController = ParentDashboardController(
      repository: repo,
      missionRepository: missionRepo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          missionRepository: missionRepo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ParentDashboardSurface.contentKey), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.byKey(ParentDashboardSurface.missionContentKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.missionRowKey), findsOneWidget);
    expect(find.textContaining('Ebeveyn bildirimi: Tamamlandı'), findsOneWidget);
  });

  testWidgets('mission error shows unavailable while KPI metrics remain',
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

    final repo = FakeSessionKpiRepository(auth)..response = sampleKpiResponse();
    final missionRepo = FakeMissionStatusRepository(auth)
      ..throwError = ApiException(503, 'down');

    final dashboardController = ParentDashboardController(
      repository: repo,
      missionRepository: missionRepo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          missionRepository: missionRepo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ParentDashboardSurface.contentKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.missionUnavailableKey), findsOneWidget);
  });

  testWidgets('no_report mission row uses informational presentation',
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

    final repo = FakeSessionKpiRepository(auth)..response = sampleKpiResponse();
    final missionRepo = FakeMissionStatusRepository(auth)
      ..response = sampleMissionStatusResponse(
        items: [
          sampleMissionRow(
            reportAvailability: MissionParentReportFactsAvailabilityEnum.noReport,
          ),
        ],
      );

    final dashboardController = ParentDashboardController(
      repository: repo,
      missionRepository: missionRepo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          missionRepository: missionRepo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Ebeveyn bildirimi yok'), findsOneWidget);
  });

  testWidgets('KPI 5xx keeps mission panel when mission loaded',
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

    final repo = FakeSessionKpiRepository(auth)
      ..throwError = ApiException(503, 'down');
    final missionRepo = FakeMissionStatusRepository(auth)
      ..response = sampleMissionStatusResponse();

    final dashboardController = ParentDashboardController(
      repository: repo,
      missionRepository: missionRepo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          missionRepository: missionRepo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ParentDashboardSurface.kpiErrorKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.kpiRetryKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.missionContentKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.errorKey), findsNothing);
  });

  testWidgets('KPI 401 hides mission panel fail-closed', (tester) async {
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

    final repo = FakeSessionKpiRepository(auth)
      ..throwError = ApiException(401, 'expired');
    final missionRepo = FakeMissionStatusRepository(auth)
      ..response = sampleMissionStatusResponse();

    final dashboardController = ParentDashboardController(
      repository: repo,
      missionRepository: missionRepo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          missionRepository: missionRepo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ParentDashboardSurface.errorKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.missionContentKey), findsNothing);
    expect(find.byKey(ParentDashboardSurface.kpiErrorKey), findsNothing);
  });

  testWidgets('KPI 404 hides mission panel fail-closed', (tester) async {
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

    final repo = FakeSessionKpiRepository(auth)
      ..throwError = ApiException(404, 'missing');
    final missionRepo = FakeMissionStatusRepository(auth)
      ..response = sampleMissionStatusResponse();

    final dashboardController = ParentDashboardController(
      repository: repo,
      missionRepository: missionRepo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          missionRepository: missionRepo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ParentDashboardSurface.errorKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.missionContentKey), findsNothing);
    expect(find.byKey(ParentDashboardSurface.kpiErrorKey), findsNothing);
  });

  testWidgets('KPI empty still shows mission data when mission loaded',
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

    final repo = FakeSessionKpiRepository(auth)
      ..response = sampleKpiResponse(eligible: 0);
    final missionRepo = FakeMissionStatusRepository(auth)
      ..response = sampleMissionStatusResponse();

    final dashboardController = ParentDashboardController(
      repository: repo,
      missionRepository: missionRepo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          missionRepository: missionRepo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ParentDashboardSurface.emptyKey), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.missionContentKey), findsOneWidget);
    expect(find.textContaining('Ebeveyn bildirimi: Tamamlandı'), findsOneWidget);
  });

  testWidgets('truncated mission pagination shows explicit incomplete label',
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

    final repo = FakeSessionKpiRepository(auth)
      ..response = sampleKpiResponse();
    final missionRepo = FakeMissionStatusRepository(auth)
      ..response = sampleMissionStatusResponse(truncated: true);

    final dashboardController = ParentDashboardController(
      repository: repo,
      missionRepository: missionRepo,
      auth: auth,
      profiles: profiles,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParentDashboardSurface(
          auth: auth,
          profiles: profiles,
          repository: repo,
          missionRepository: missionRepo,
          controller: dashboardController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ParentDashboardSurface.missionTruncatedKey), findsOneWidget);
    expect(find.textContaining('Liste sınırı'), findsOneWidget);
    expect(find.byKey(ParentDashboardSurface.missionContentKey), findsOneWidget);
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

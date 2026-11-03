import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/child_profiles/child_profiles_controller.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/parent_dashboard/parent_dashboard_controller.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_repository.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_window.dart';

import 'child_profiles_widget_test.dart' show FakeChildProfiles;
import 'parent_dashboard_fixtures.dart';

class FakeSessionKpiRepository extends SessionKpiRepository {
  FakeSessionKpiRepository(ParentAuthController auth)
      : super(config: AppConfig.developmentLocal, auth: auth);

  SessionKpiResponse? response;
  Completer<SessionKpiResponse>? pending;
  String? lastChildId;

  @override
  Future<SessionKpiResponse> fetch({
    required SessionKpiWindow window,
    String? childId,
  }) async {
    lastChildId = childId;
    if (pending != null) return pending!.future;
    if (response == null) {
      throw ApiException(503, 'offline');
    }
    return response!;
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
    accessToken: 'token',
    refreshToken: 'refresh',
    parentId: parentId,
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    expiresInSeconds: 900,
  ));
  return auth;
}

void main() {
  test('stale KPI response dropped after parent switch', () async {
    final auth = signedIn('11111111-1111-4111-8111-111111111111');
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
    repo.pending = Completer<SessionKpiResponse>();
    final controller = ParentDashboardController(
      repository: repo,
      auth: auth,
      profiles: profiles,
      windowBuilder: () => SessionKpiWindow.recentSevenDaysPlusToday(
        now: DateTime.utc(2026, 11, 3),
      ),
    );

    final loadFuture = controller.load();
    auth.seedAuthenticatedSessionForTests(const AuthSession(
      accessToken: 'other',
      refreshToken: 'other-r',
      parentId: '22222222-2222-4222-8222-222222222222',
      sessionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      expiresInSeconds: 900,
    ));
    repo.pending!.complete(sampleKpiResponse());
    await loadFuture;

    expect(controller.view, isNull);
    expect(controller.phase, isNot(ParentDashboardPhase.loaded));
  });

  test('maps loaded server metrics without client-side recomputation', () async {
    final auth = signedIn('11111111-1111-4111-8111-111111111111');
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
    repo.response = sampleKpiResponse(eligible: 5);

    final controller = ParentDashboardController(
      repository: repo,
      auth: auth,
      profiles: profiles,
    );
    await controller.load();

    expect(controller.phase, ParentDashboardPhase.loaded);
    expect(controller.view?.eligibleSessions, 5);
    expect(controller.view?.completedRateLabel, contains('67%'));
    expect(controller.view?.firstAttemptAccuracyUnavailable, isTrue);
    expect(repo.lastChildId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  });
}

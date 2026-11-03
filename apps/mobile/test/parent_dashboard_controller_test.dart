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

const _parentA = '11111111-1111-4111-8111-111111111111';
const _sessionS1 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _sessionS2 = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _childAda = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _childBob = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

ParentAuthController signedIn({
  required String parentId,
  String sessionId = _sessionS1,
  String accessToken = 'token',
}) {
  final auth = ParentAuthController(
    repository: ParentAuthRepository(
      config: AppConfig.developmentLocal,
      tokenStore: InMemoryAuthTokenStore(),
    ),
  );
  auth.seedAuthenticatedSessionForTests(AuthSession(
    accessToken: accessToken,
    refreshToken: 'refresh',
    parentId: parentId,
    sessionId: sessionId,
    expiresInSeconds: 900,
  ));
  return auth;
}

Future<ChildProfilesController> profilesWithChild(ParentAuthController auth) async {
  final fakeProfiles = FakeChildProfiles(auth);
  fakeProfiles.rows.add(ChildProfileResponse(
    childId: _childAda,
    nickname: 'Ada',
    ageMonths: 32,
    preferredLocale: 'tr-TR',
  ));
  fakeProfiles.rows.add(ChildProfileResponse(
    childId: _childBob,
    nickname: 'Bora',
    ageMonths: 36,
    preferredLocale: 'tr-TR',
  ));
  final profiles = ChildProfilesController(repository: fakeProfiles, auth: auth);
  await profiles.load();
  profiles.select(_childAda);
  return profiles;
}

void main() {
  test('stale KPI response dropped after different parent switch', () async {
    final auth = signedIn(parentId: _parentA);
    final profiles = await profilesWithChild(auth);

    final repo = FakeSessionKpiRepository(auth);
    repo.pending = Completer<SessionKpiResponse>();
    final controller = ParentDashboardController(
      repository: repo,
      auth: auth,
      profiles: profiles,
    );

    final loadFuture = controller.load();
    await Future<void>.delayed(Duration.zero);
    auth.seedAuthenticatedSessionForTests(const AuthSession(
      accessToken: 'other',
      refreshToken: 'other-r',
      parentId: '22222222-2222-4222-8222-222222222222',
      sessionId: _sessionS2,
      expiresInSeconds: 900,
    ));
    repo.pending!.complete(sampleKpiResponse());
    await loadFuture;

    expect(controller.view, isNull);
    expect(controller.phase, isNot(ParentDashboardPhase.loaded));
  });

  test('stale KPI response dropped after same parent new sessionId', () async {
    final auth = signedIn(parentId: _parentA, sessionId: _sessionS1);
    final profiles = await profilesWithChild(auth);

    final repo = FakeSessionKpiRepository(auth);
    repo.pending = Completer<SessionKpiResponse>();
    final controller = ParentDashboardController(
      repository: repo,
      auth: auth,
      profiles: profiles,
    );

    final loadFuture = controller.load();
    await Future<void>.delayed(Duration.zero);
    auth.seedAuthenticatedSessionForTests(AuthSession(
      accessToken: 'rotated-access',
      refreshToken: 'rotated-refresh',
      parentId: _parentA,
      sessionId: _sessionS2,
      expiresInSeconds: 900,
    ));
    repo.pending!.complete(sampleKpiResponse(eligible: 9));
    await loadFuture;

    expect(controller.view, isNull);
    expect(controller.phase, ParentDashboardPhase.initial);
  });

  test('token refresh same parent+sessionId allows in-flight KPI to commit', () async {
    final auth = signedIn(parentId: _parentA, sessionId: _sessionS1, accessToken: 'stale');
    final profiles = await profilesWithChild(auth);

    final repo = FakeSessionKpiRepository(auth);
    repo.pending = Completer<SessionKpiResponse>();
    final controller = ParentDashboardController(
      repository: repo,
      auth: auth,
      profiles: profiles,
    );

    final loadFuture = controller.load();
    auth.seedAuthenticatedSessionForTests(AuthSession(
      accessToken: 'fresh-access',
      refreshToken: 'refresh',
      parentId: _parentA,
      sessionId: _sessionS1,
      expiresInSeconds: 900,
    ));
    repo.pending!.complete(sampleKpiResponse(eligible: 4));
    await loadFuture;

    expect(controller.phase, ParentDashboardPhase.loaded);
    expect(controller.view?.eligibleSessions, 4);
  });

  test('child switch mid-flight refetches and drops prior generation', () async {
    final auth = signedIn(parentId: _parentA);
    final profiles = await profilesWithChild(auth);

    final repo = FakeSessionKpiRepository(auth);
    repo.pending = Completer<SessionKpiResponse>();
    final controller = ParentDashboardController(
      repository: repo,
      auth: auth,
      profiles: profiles,
    );

    final loadFuture = controller.load();
    expect(repo.lastChildId, _childAda);
    profiles.select(_childBob);
    await Future<void>.delayed(Duration.zero);
    expect(repo.lastChildId, _childBob);
    repo.pending!.complete(sampleKpiResponse(eligible: 8));
    await loadFuture;

    expect(controller.phase, ParentDashboardPhase.loaded);
    expect(controller.view?.eligibleSessions, 8);
  });

  test('maps loaded server metrics without client-side recomputation', () async {
    final auth = signedIn(parentId: _parentA);
    final profiles = await profilesWithChild(auth);

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
    expect(repo.lastChildId, _childAda);
  });
}

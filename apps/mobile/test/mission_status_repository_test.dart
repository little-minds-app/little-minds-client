import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/auth/auth_error.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/parent_dashboard/mission_status_repository.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_window.dart';

import 'parent_dashboard_fixtures.dart';

const _parentA = '11111111-1111-4111-8111-111111111111';
const _parentB = '22222222-2222-4222-8222-222222222222';
const _sessionS1 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _sessionS2 = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _childAda = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

class _CountingMissionsApi extends MissionsApi {
  _CountingMissionsApi(this._handler) : super(ApiClient(basePath: 'http://test.invalid'));

  final Future<MissionStatusListResponse?> Function(int attempt) _handler;
  int attempts = 0;

  @override
  Future<MissionStatusListResponse?> listChildMissionStatus(
    String childId,
    DateTime from,
    DateTime to, {
    int? limit,
    Future<void>? abortTrigger,
  }) async {
    attempts++;
    return _handler(attempts);
  }
}

class _RefreshOnceRepo extends ParentAuthRepository {
  _RefreshOnceRepo({required InMemoryAuthTokenStore store})
      : super(config: AppConfig.developmentLocal, tokenStore: store);

  int refreshCalls = 0;

  @override
  Future<AuthSession> refreshSession(AuthSession session) async {
    refreshCalls++;
    return AuthSession(
      accessToken: 'access-refreshed',
      refreshToken: session.refreshToken,
      sessionId: session.sessionId,
      parentId: session.parentId,
      expiresInSeconds: session.expiresInSeconds,
    );
  }
}

class _FailingRefreshRepo extends ParentAuthRepository {
  _FailingRefreshRepo({required InMemoryAuthTokenStore store})
      : super(config: AppConfig.developmentLocal, tokenStore: store);

  @override
  Future<AuthSession> refreshSession(AuthSession session) async {
    throw const ParentAuthFailure(
      code: 'invalid_token',
      message: 'Session expired.',
    );
  }
}

ParentAuthController authWithRepo(ParentAuthRepository repo) {
  final auth = ParentAuthController(repository: repo);
  auth.seedAuthenticatedSessionForTests(const AuthSession(
    accessToken: 'access-stale',
    refreshToken: 'refresh',
    parentId: _parentA,
    sessionId: _sessionS1,
    expiresInSeconds: 900,
  ));
  return auth;
}

final _window = SessionKpiWindow.recentSevenDaysPlusToday(
  now: DateTime.utc(2026, 11, 3),
);

MissionStatusRepository missionRepo(ParentAuthController auth, MissionsApi api) {
  return MissionStatusRepository(
    config: AppConfig.developmentLocal,
    auth: auth,
    missions: api,
  );
}

void main() {
  test('fetch passes child id and shared KPI window instants', () async {
    final auth = authWithRepo(
      ParentAuthRepository(
        config: AppConfig.developmentLocal,
        tokenStore: InMemoryAuthTokenStore(),
      ),
    );
    const childId = _childAda;

    DateTime? capturedFrom;
    DateTime? capturedTo;
    final api = _CountingMissionsApi((attempt) async {
      expect(attempt, 1);
      capturedFrom = _window.fromUtc;
      capturedTo = _window.toUtcExclusive;
      return sampleMissionStatusResponse(childId: childId);
    });

    await missionRepo(auth, api).fetch(childId: childId, window: _window);
    expect(capturedFrom, _window.fromUtc);
    expect(capturedTo, _window.toUtcExclusive);
    expect(api.attempts, 1);
  });

  test('401 triggers one refresh and single retry', () async {
    final store = InMemoryAuthTokenStore();
    final repo = _RefreshOnceRepo(store: store);
    final auth = authWithRepo(repo);
    final api = _CountingMissionsApi((attempt) async {
      if (attempt == 1) throw ApiException(401, 'expired');
      return sampleMissionStatusResponse();
    });

    final result = await missionRepo(auth, api).fetch(childId: _childAda, window: _window);

    expect(api.attempts, 2);
    expect(repo.refreshCalls, 1);
    expect(result.items, isNotEmpty);
  });

  test('failed refresh clears auth without extra mission calls', () async {
    final store = InMemoryAuthTokenStore();
    final repo = _FailingRefreshRepo(store: store);
    final auth = authWithRepo(repo);
    final api = _CountingMissionsApi((attempt) async {
      throw ApiException(401, 'expired');
    });

    await expectLater(
      missionRepo(auth, api).fetch(childId: _childAda, window: _window),
      throwsA(isA<StateError>()),
    );
    expect(api.attempts, 1);
    expect(auth.session, isNull);
    expect(auth.isAuthenticated, isFalse);
  });

  test('persistent 401 after refresh does not loop', () async {
    final store = InMemoryAuthTokenStore();
    final repo = _RefreshOnceRepo(store: store);
    final auth = authWithRepo(repo);
    final api = _CountingMissionsApi((attempt) async {
      throw ApiException(401, 'expired');
    });

    await expectLater(
      missionRepo(auth, api).fetch(childId: _childAda, window: _window),
      throwsA(isA<ApiException>()),
    );
    expect(api.attempts, 2);
    expect(repo.refreshCalls, 1);
  });

  test('401 retry aborted when parent account changes before refresh', () async {
    final store = InMemoryAuthTokenStore();
    final repo = _RefreshOnceRepo(store: store);
    final auth = authWithRepo(repo);
    final api = _CountingMissionsApi((attempt) async {
      if (attempt == 1) {
        auth.seedAuthenticatedSessionForTests(const AuthSession(
          accessToken: 'other',
          refreshToken: 'other-r',
          parentId: _parentB,
          sessionId: _sessionS2,
          expiresInSeconds: 900,
        ));
        throw ApiException(401, 'expired');
      }
      return sampleMissionStatusResponse();
    });

    await expectLater(
      missionRepo(auth, api).fetch(childId: _childAda, window: _window),
      throwsA(isA<StateError>()),
    );
    expect(api.attempts, 1);
    expect(repo.refreshCalls, 0);
  });

  test('401 retry aborted when sessionId changes before refresh', () async {
    final store = InMemoryAuthTokenStore();
    final repo = _RefreshOnceRepo(store: store);
    final auth = authWithRepo(repo);
    final api = _CountingMissionsApi((attempt) async {
      if (attempt == 1) {
        auth.seedAuthenticatedSessionForTests(const AuthSession(
          accessToken: 'rotated',
          refreshToken: 'refresh',
          parentId: _parentA,
          sessionId: _sessionS2,
          expiresInSeconds: 900,
        ));
        throw ApiException(401, 'expired');
      }
      return sampleMissionStatusResponse();
    });

    await expectLater(
      missionRepo(auth, api).fetch(childId: _childAda, window: _window),
      throwsA(isA<StateError>()),
    );
    expect(api.attempts, 1);
    expect(repo.refreshCalls, 0);
  });

  test('null mission response throws invalid response', () async {
    final auth = authWithRepo(
      ParentAuthRepository(
        config: AppConfig.developmentLocal,
        tokenStore: InMemoryAuthTokenStore(),
      ),
    );
    final api = _CountingMissionsApi((_) async => null);

    await expectLater(
      missionRepo(auth, api).fetch(childId: _childAda, window: _window),
      throwsA(isA<StateError>()),
    );
  });

  test('mapMissionStatusException maps 404 to child not found', () {
    expect(
      mapMissionStatusException(ApiException(404, 'missing')),
      isA<MissionStatusChildNotFound>(),
    );
  });

  test('mapMissionStatusException maps 403 to child not found', () {
    expect(
      mapMissionStatusException(ApiException(403, 'forbidden')),
      isA<MissionStatusChildNotFound>(),
    );
  });

  test('mapMissionStatusException maps 5xx to network', () {
    expect(
      mapMissionStatusException(ApiException(503, 'down')),
      isA<MissionStatusNetwork>(),
    );
  });
}

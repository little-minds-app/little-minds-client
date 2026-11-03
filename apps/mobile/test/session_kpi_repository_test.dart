import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/auth/auth_error.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_repository.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_window.dart';

import 'parent_dashboard_fixtures.dart';

const _parentA = '11111111-1111-4111-8111-111111111111';
const _sessionS1 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class _CountingInsightsApi extends InsightsApi {
  _CountingInsightsApi(this._handler)
      : super(ApiClient(basePath: 'http://test.invalid'));

  final Future<SessionKpiResponse?> Function(int attempt) _handler;
  int attempts = 0;

  @override
  Future<SessionKpiResponse?> getSessionKpis(
    DateTime from,
    DateTime to,
    String timezone, {
    String? childId,
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

void main() {
  test('401 triggers one refresh and single retry', () async {
    final store = InMemoryAuthTokenStore();
    final repo = _RefreshOnceRepo(store: store);
    final auth = authWithRepo(repo);
    final insights = _CountingInsightsApi((attempt) async {
      if (attempt == 1) throw ApiException(401, 'expired');
      return sampleKpiResponse(eligible: 2);
    });
    final kpiRepo = SessionKpiRepository(
      config: AppConfig.developmentLocal,
      auth: auth,
      insights: insights,
    );

    final result = await kpiRepo.fetch(window: _window, childId: null);

    expect(insights.attempts, 2);
    expect(repo.refreshCalls, 1);
    expect(result.metrics.eligibleSessionCount, 2);
  });

  test('failed refresh surfaces unauthorized without extra KPI calls', () async {
    final store = InMemoryAuthTokenStore();
    final repo = _FailingRefreshRepo(store: store);
    final auth = authWithRepo(repo);
    final insights = _CountingInsightsApi((attempt) async {
      throw ApiException(401, 'expired');
    });
    final kpiRepo = SessionKpiRepository(
      config: AppConfig.developmentLocal,
      auth: auth,
      insights: insights,
    );

    await expectLater(
      kpiRepo.fetch(window: _window),
      throwsA(isA<StateError>()),
    );
    expect(insights.attempts, 1);
    expect(auth.session, isNull);
    expect(auth.isAuthenticated, isFalse);
  });

  test('persistent 401 after refresh does not loop', () async {
    final store = InMemoryAuthTokenStore();
    final repo = _RefreshOnceRepo(store: store);
    final auth = authWithRepo(repo);
    final insights = _CountingInsightsApi((attempt) async {
      throw ApiException(401, 'expired');
    });
    final kpiRepo = SessionKpiRepository(
      config: AppConfig.developmentLocal,
      auth: auth,
      insights: insights,
    );

    await expectLater(
      kpiRepo.fetch(window: _window),
      throwsA(isA<ApiException>()),
    );
    expect(insights.attempts, 2);
    expect(repo.refreshCalls, 1);
  });
}

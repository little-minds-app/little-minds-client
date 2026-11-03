import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/auth/auth_api_clients.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/parent_dashboard/mission_status_repository.dart';
import 'package:little_minds_mobile/parent_dashboard/session_kpi_window.dart';

import 'parent_dashboard_fixtures.dart';

class _RecordingMissionsApi extends MissionsApi {
  _RecordingMissionsApi(this.handler) : super(ApiClient(basePath: 'http://test'));

  final Future<MissionStatusListResponse?> Function(
    String childId,
    DateTime from,
    DateTime to, {
    int? limit,
  }) handler;

  int callCount = 0;
  String? lastToken;

  @override
  Future<MissionStatusListResponse?> listChildMissionStatus(
    String childId,
    DateTime from,
    DateTime to, {
    int? limit,
    Future<void>? abortTrigger,
  }) async {
    callCount++;
    return handler(childId, from, to, limit: limit);
  }
}

void main() {
  test('fetch passes child id and shared KPI window instants', () async {
    final auth = ParentAuthController(
      repository: ParentAuthRepository(
        config: AppConfig.developmentLocal,
        tokenStore: InMemoryAuthTokenStore(),
      ),
    );
    auth.seedAuthenticatedSessionForTests(const AuthSession(
      accessToken: 'access-1',
      refreshToken: 'refresh',
      parentId: '11111111-1111-4111-8111-111111111111',
      sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      expiresInSeconds: 900,
    ));

    final window = SessionKpiWindow.recentSevenDaysPlusToday(
      now: DateTime.utc(2026, 11, 3, 12),
    );
    const childId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

    DateTime? capturedFrom;
    DateTime? capturedTo;
    final api = _RecordingMissionsApi((id, from, to, {limit}) async {
      expect(id, childId);
      capturedFrom = from;
      capturedTo = to;
      expect(limit, missionStatusDefaultLimit);
      return sampleMissionStatusResponse(childId: childId);
    });

    final clients = AuthApiClients(basePath: AppConfig.developmentLocal.apiBaseUrlString);
    final repo = MissionStatusRepository(
      config: AppConfig.developmentLocal,
      auth: auth,
      clients: clients,
      missions: api,
    );

    await repo.fetch(childId: childId, window: window);
    expect(capturedFrom, window.fromUtc);
    expect(capturedTo, window.toUtcExclusive);
    expect(api.callCount, 1);
  });

  test('mapMissionStatusException maps 403 to child not found', () {
    expect(
      mapMissionStatusException(ApiException(403, 'forbidden')),
      isA<MissionStatusChildNotFound>(),
    );
  });
}

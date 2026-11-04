import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/shape_matching/hub_bootstrap.dart';
import 'package:little_minds_mobile/shape_matching/hub_authorized_device_child.dart';
import 'package:little_minds_mobile/shape_matching/hub_device_child_binding.dart';
import 'package:little_minds_mobile/shape_matching/hub_device_child_binding_client.dart';

void main() {
  const session = AuthSession(
    parentId: '11111111-1111-4111-8111-111111111111',
    sessionId: '00000000-0000-4000-8000-000000000001',
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    expiresInSeconds: 300,
  );
  const installationId = '33333333-3333-4333-8333-333333333333';
  const childId = '44444444-4444-4444-8444-444444444444';
  const childB = '55555555-5555-4555-8555-555555555555';
  const scopedDeviceId = '22222222-2222-4222-8222-222222222222';

  Map<String, Object?> bindingJson({
    required String child,
    required int revision,
  }) =>
      {
        'device_id': scopedDeviceId,
        'installation_id': installationId,
        'child_id': child,
        'binding_revision': revision,
        'updated_at': '2026-11-04T16:00:00.000Z',
      };

  group('LMP-134 device child binding (P2)', () {
    test('P2-05 composition root uses OpenAPI DevicesApi client', () {
      final config = AppConfig.developmentLocal;
      final client = hubDeviceChildBindingClientFor(config);
      expect(client, isA<OpenApiHubDeviceChildBindingClient>());
      expect(client, isNot(isA<FailClosedHubDeviceChildBindingClient>()));
    });

    test('P2-06 bindSelectedChild mirrors authorized child on 200', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = Uri.parse('http://${server.address.host}:${server.port}');
      addTearDown(server.close);

      server.listen((request) async {
        if (request.method == 'GET') {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        expect(request.method, 'PUT');
        expect(
          request.uri.path,
          '/v1/devices/$installationId/active-child',
        );
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer ${session.accessToken}',
        );
        final body = await utf8.decoder.bind(request).join();
        expect(
          jsonDecode(body),
          {'child_id': childId, 'expected_binding_revision': 0},
        );
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode(bindingJson(child: childId, revision: 1)),
        );
        await request.response.close();
      });

      final client = OpenApiHubDeviceChildBindingClient(
        config: AppConfig(apiBaseUrl: base, environment: AppConfig.developmentLocal.environment),
      );
      final result = await client.bindSelectedChild(
        session: session,
        installationId: installationId,
        selectedChildId: childId,
      );
      expect(result, isA<HubDeviceChildBound>());
      expect((result as HubDeviceChildBound).childId, childId);
    });

    test('P2-07 bindSelectedChild fails closed on 403', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = Uri.parse('http://${server.address.host}:${server.port}');
      addTearDown(server.close);

      server.listen((request) async {
        request.response.statusCode = 403;
        await request.response.close();
      });

      final client = OpenApiHubDeviceChildBindingClient(
        config: AppConfig(apiBaseUrl: base, environment: AppConfig.developmentLocal.environment),
      );
      final result = await client.bindSelectedChild(
        session: session,
        installationId: installationId,
        selectedChildId: childId,
      );
      expect(result, isA<HubDeviceChildBindingFailed>());
    });

    test('P1-02 bindSelectedChild retries on 409 with fresh revision', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = Uri.parse('http://${server.address.host}:${server.port}');
      addTearDown(server.close);
      var putAttempts = 0;
      var serverRevision = 2;

      server.listen((request) async {
        if (request.method == 'GET') {
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode(
              bindingJson(child: childB, revision: serverRevision),
            ),
          );
          await request.response.close();
          return;
        }
        if (request.method == 'PUT') {
          putAttempts++;
          final body =
              jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
          final expected = body['expected_binding_revision'] as int;
          if (putAttempts == 1) {
            expect(expected, 2);
            request.response.statusCode = 409;
            await request.response.close();
            serverRevision = 3;
            return;
          }
          expect(expected, 3);
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode(bindingJson(child: childId, revision: 4)),
          );
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      });

      final client = OpenApiHubDeviceChildBindingClient(
        config: AppConfig(apiBaseUrl: base, environment: AppConfig.developmentLocal.environment),
      );
      final result = await client.bindSelectedChild(
        session: session,
        installationId: installationId,
        selectedChildId: childId,
      );
      expect(putAttempts, 2);
      expect(result, isA<HubDeviceChildBound>());
    });

    test('P1-02 bindSelectedChild reconciles stale PUT via GET', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = Uri.parse('http://${server.address.host}:${server.port}');
      addTearDown(server.close);

      var getCount = 0;
      server.listen((request) async {
        if (request.method == 'PUT') {
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode(bindingJson(child: childB, revision: 1)),
          );
          await request.response.close();
          return;
        }
        if (request.method == 'GET') {
          getCount++;
          if (getCount == 1) {
            request.response.statusCode = 404;
            await request.response.close();
            return;
          }
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode(bindingJson(child: childId, revision: 2)),
          );
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      });

      final client = OpenApiHubDeviceChildBindingClient(
        config: AppConfig(apiBaseUrl: base, environment: AppConfig.developmentLocal.environment),
      );
      final result = await client.bindSelectedChild(
        session: session,
        installationId: installationId,
        selectedChildId: childId,
      );
      expect(result, isA<HubDeviceChildBound>());
      expect((result as HubDeviceChildBound).childId, childId);
    });
  });

  group('LMP-134 device child binding service (P1-02)', () {
    test('rapid A→B→A keeps latest catalog child', () async {
      final catalog = MemoryHubAuthorizedDeviceChildCatalog();
      final client = _DelayedBindClient(delay: const Duration(milliseconds: 25));
      final service = HubDeviceChildBindingService(catalog: catalog, client: client);
      AuthSession? active = session;

      unawaited(
        service.synchronizeSelectedChild(
          readSession: () => active,
          installationId: installationId,
          scopedDeviceId: scopedDeviceId,
          selectedChildId: childId,
        ),
      );
      unawaited(
        service.synchronizeSelectedChild(
          readSession: () => active,
          installationId: installationId,
          scopedDeviceId: scopedDeviceId,
          selectedChildId: childB,
        ),
      );
      await service.synchronizeSelectedChild(
        readSession: () => active,
        installationId: installationId,
        scopedDeviceId: scopedDeviceId,
        selectedChildId: childId,
      );

      expect(
        await catalog.authorizedChildId(
          parentId: session.parentId,
          scopedDeviceId: scopedDeviceId,
        ),
        childId,
      );
    });

    test('logout during bind does not mirror stale child', () async {
      final catalog = MemoryHubAuthorizedDeviceChildCatalog();
      final client = _SlowBindClient(delay: const Duration(milliseconds: 30));
      final service = HubDeviceChildBindingService(catalog: catalog, client: client);
      AuthSession? active = session;

      final inFlight = service.synchronizeSelectedChild(
        readSession: () => active,
        installationId: installationId,
        scopedDeviceId: scopedDeviceId,
        selectedChildId: childId,
      );
      active = null;
      await inFlight;

      expect(
        await catalog.authorizedChildId(
          parentId: session.parentId,
          scopedDeviceId: scopedDeviceId,
        ),
        isNull,
      );
    });
  });
}

final class _DelayedBindClient implements HubDeviceChildBindingClient {
  _DelayedBindClient({required this.delay});

  final Duration delay;

  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String installationId,
    required String selectedChildId,
    Future<void>? abortTrigger,
  }) async {
    await Future<void>.delayed(delay);
    return HubDeviceChildBound(selectedChildId);
  }
}

final class _SlowBindClient implements HubDeviceChildBindingClient {
  _SlowBindClient({required this.delay});

  final Duration delay;

  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String installationId,
    required String selectedChildId,
    Future<void>? abortTrigger,
  }) async {
    await Future<void>.delayed(delay);
    return HubDeviceChildBound(selectedChildId);
  }
}

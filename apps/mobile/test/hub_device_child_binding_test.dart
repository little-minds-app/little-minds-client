import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/shape_matching/hub_bootstrap.dart';
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
  const scopedDeviceId = '22222222-2222-4222-8222-222222222222';
  const childId = '44444444-4444-4444-8444-444444444444';

  group('LMP-134 device child binding (P2)', () {
    test('P2-05 composition root uses authenticated HTTP client', () {
      final config = AppConfig.developmentLocal;
      final client = hubDeviceChildBindingClientFor(config);
      expect(client, isA<HttpHubDeviceChildBindingClient>());
      expect(client, isNot(isA<FailClosedHubDeviceChildBindingClient>()));
    });

    test('P2-06 bindSelectedChild mirrors authorized child on 200', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = Uri.parse('http://${server.address.host}:${server.port}');
      addTearDown(server.close);

      server.listen((request) async {
        expect(request.method, 'PUT');
        expect(
          request.uri.path,
          '/v1/devices/$scopedDeviceId/active-child',
        );
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer ${session.accessToken}',
        );
        final body = await utf8.decoder.bind(request).join();
        expect(jsonDecode(body), {'child_id': childId});
        request.response.statusCode = 200;
        request.response.write(jsonEncode({'child_id': childId}));
        await request.response.close();
      });

      final client = HttpHubDeviceChildBindingClient(apiBaseUrl: base);
      final result = await client.bindSelectedChild(
        session: session,
        scopedDeviceId: scopedDeviceId,
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

      final client = HttpHubDeviceChildBindingClient(apiBaseUrl: base);
      final result = await client.bindSelectedChild(
        session: session,
        scopedDeviceId: scopedDeviceId,
        selectedChildId: childId,
      );
      expect(result, isA<HubDeviceChildBindingFailed>());
    });
  });
}

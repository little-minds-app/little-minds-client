import 'dart:convert';
import 'dart:io';

import '../auth/auth_session.dart';
import 'hub_device_child_binding.dart';

/// Authenticated device↔child bind via pinned OpenAPI wire path (LMP-134).
///
/// Uses Bearer parent session auth. When backend OpenAPI adds generated
/// [DevicesApi], migrate call sites to generated models; keep this transport
/// until the client pin includes device bind routes.
final class HttpHubDeviceChildBindingClient
    implements HubDeviceChildBindingClient {
  HttpHubDeviceChildBindingClient({
    required this._apiBaseUrl,
    HttpClient? httpClient,
  }) : _client = httpClient ?? HttpClient();

  final Uri _apiBaseUrl;
  final HttpClient _client;

  static Uri activeChildEndpoint(Uri apiBaseUrl, String scopedDeviceId) =>
      apiBaseUrl.resolve(
        'v1/devices/${Uri.encodeComponent(scopedDeviceId)}/active-child',
      );

  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String scopedDeviceId,
    required String selectedChildId,
  }) async {
    final endpoint = activeChildEndpoint(_apiBaseUrl, scopedDeviceId);
    final req = await _client.putUrl(endpoint).timeout(const Duration(seconds: 15));
    req.headers.contentType = ContentType.json;
    req.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${session.accessToken}',
    );
    req.add(
      utf8.encode(
        jsonEncode(<String, String>{'child_id': selectedChildId}),
      ),
    );
    final response = await req.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const HubDeviceChildBindingFailed();
      }
      final childId = decoded['child_id']?.toString();
      if (childId == null || childId.isEmpty) {
        return const HubDeviceChildBindingFailed();
      }
      return HubDeviceChildBound(childId);
    }
    return const HubDeviceChildBindingFailed();
  }
}

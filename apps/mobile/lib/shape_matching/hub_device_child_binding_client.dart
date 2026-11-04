import 'package:little_minds_api/api.dart';

import '../auth/auth_session.dart';
import '../config/app_config.dart';
import 'hub_device_child_binding.dart';

/// Authenticated device↔child bind via pinned OpenAPI [DevicesApi] (LMP-134).
final class OpenApiHubDeviceChildBindingClient
    implements HubDeviceChildBindingClient {
  OpenApiHubDeviceChildBindingClient({
    required AppConfig config,
    DevicesApi? devicesApi,
  }) : _devices = devicesApi ??
            DevicesApi(
              ApiClient(
                basePath: config.apiBaseUrlString,
                authentication: HttpBearerAuth(),
              ),
            );

  final DevicesApi _devices;

  HttpBearerAuth get _bearer {
    final auth = _devices.apiClient.authentication;
    if (auth is HttpBearerAuth) {
      return auth;
    }
    throw StateError('DevicesApi must use HttpBearerAuth');
  }

  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String installationId,
    required String selectedChildId,
  }) async {
    _bearer.accessToken = session.accessToken;
    try {
      final binding = await _devices.setDeviceActiveChild(
        installationId,
        SetDeviceActiveChildRequest(childId: selectedChildId),
      );
      final childId = binding?.childId;
      if (childId == null || childId.isEmpty) {
        return const HubDeviceChildBindingFailed();
      }
      return HubDeviceChildBound(childId);
    } on ApiException {
      return const HubDeviceChildBindingFailed();
    }
  }
}

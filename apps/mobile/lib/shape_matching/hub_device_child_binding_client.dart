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

  static const _maxCasAttempts = 4;

  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String installationId,
    required String selectedChildId,
    Future<void>? abortTrigger,
  }) async {
    _bearer.accessToken = session.accessToken;

    for (var attempt = 0; attempt < _maxCasAttempts; attempt++) {
      try {
        final expectedRevision = await _readExpectedRevision(
          installationId: installationId,
          abortTrigger: abortTrigger,
        );
        final binding = await _devices.setDeviceActiveChild(
          installationId,
          SetDeviceActiveChildRequest(
            childId: selectedChildId,
            expectedBindingRevision: expectedRevision,
          ),
          abortTrigger: abortTrigger,
        );
        final childId = binding?.childId;
        if (childId != null &&
            childId.isNotEmpty &&
            childId == selectedChildId) {
          return HubDeviceChildBound(childId);
        }
        final reconciled = await _reconcileAuthoritativeChild(
          installationId: installationId,
          selectedChildId: selectedChildId,
          abortTrigger: abortTrigger,
        );
        if (reconciled != null) {
          return reconciled;
        }
      } on ApiException catch (error) {
        if (error.code == 409 && attempt + 1 < _maxCasAttempts) {
          continue;
        }
        return const HubDeviceChildBindingFailed();
      }
    }
    return const HubDeviceChildBindingFailed();
  }

  Future<int> _readExpectedRevision({
    required String installationId,
    Future<void>? abortTrigger,
  }) async {
    try {
      final read = await _devices.getDeviceActiveChild(
        installationId,
        abortTrigger: abortTrigger,
      );
      return read?.bindingRevision ?? 0;
    } on ApiException catch (error) {
      if (error.code == 404) {
        return 0;
      }
      rethrow;
    }
  }

  Future<HubDeviceChildBindingResult?> _reconcileAuthoritativeChild({
    required String installationId,
    required String selectedChildId,
    Future<void>? abortTrigger,
  }) async {
    try {
      final read = await _devices.getDeviceActiveChild(
        installationId,
        abortTrigger: abortTrigger,
      );
      final childId = read?.childId;
      if (childId != null &&
          childId.isNotEmpty &&
          childId == selectedChildId) {
        return HubDeviceChildBound(childId);
      }
    } on ApiException {
      return null;
    }
    return null;
  }
}

// ignore_for_file: prefer_initializing_formals

import 'package:little_minds_api/api.dart';

import '../auth/auth_api_clients.dart';
import '../auth/parent_auth_controller.dart';
import '../config/app_config.dart';

/// Parent-owned API. Uses the pinned generated OpenAPI Dart client only.
class ChildProfileRepository {
  ChildProfileRepository({
    required AppConfig config,
    required ParentAuthController auth,
    AuthApiClients? clients,
  })  : _auth = auth,
        _clients = clients ?? AuthApiClients(basePath: config.apiBaseUrlString);

  final ParentAuthController _auth;
  final AuthApiClients _clients;

  Future<T> _authorized<T>(Future<T> Function(ParentApi api) request) async {
    final session = _auth.session;
    if (session == null) throw StateError('Parent authentication required');
    _clients.setAccessToken(session.accessToken);
    try {
      return await request(_clients.parent);
    } on ApiException catch (error) {
      if (error.code != 401) rethrow;
      final refreshed = await _auth.refreshForChildProfiles();
      if (refreshed == null) throw StateError('Parent session expired');
      _clients.setAccessToken(refreshed);
      return request(_clients.parent);
    }
  }

  Future<List<ChildProfileResponse>> list() async {
    final result = await _authorized((api) => api.listChildProfiles());
    if (result == null) throw StateError('Invalid child list response');
    return result.children;
  }

  Future<String> create({
    required int ageMonths,
    required String nickname,
    required DateTime referenceDate,
  }) async {
    final result = await _authorized((api) => api.createChildProfile(
      CreateChildProfileRequest(
        ageMonths: ageMonths,
        referenceDate: referenceDate,
        nickname: nickname,
        timezone: 'Europe/Istanbul',
      ),
    ));
    if (result == null) throw StateError('Invalid create profile response');
    return result.childId;
  }

  Future<ChildProfileResponse> edit({
    required String childId,
    required int ageMonths,
    required String nickname,
    required DateTime referenceDate,
  }) async {
    final result = await _authorized((api) => api.updateChildProfile(
      childId,
      UpdateChildProfileRequest(
        ageMonths: ageMonths,
        referenceDate: referenceDate,
        nickname: nickname,
        timezone: 'Europe/Istanbul',
      ),
    ));
    if (result == null) throw StateError('Invalid edit profile response');
    return result;
  }
}

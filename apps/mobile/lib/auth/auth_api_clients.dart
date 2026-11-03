import 'package:little_minds_api/api.dart';

/// Generated OpenAPI clients with bearer injection for parent routes.
class AuthApiClients {
  AuthApiClients({required String basePath}) : bearer = HttpBearerAuth() {
    apiClient = ApiClient(basePath: basePath, authentication: bearer);
    auth = AuthApi(apiClient);
    parent = ParentApi(apiClient);
    insights = InsightsApi(apiClient);
    missions = MissionsApi(apiClient);
  }

  final HttpBearerAuth bearer;
  late final ApiClient apiClient;
  late final AuthApi auth;
  late final ParentApi parent;
  late final InsightsApi insights;
  late final MissionsApi missions;

  void setAccessToken(String? token) {
    bearer.accessToken = token ?? '';
  }
}

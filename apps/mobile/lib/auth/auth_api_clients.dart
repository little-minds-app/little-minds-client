import 'package:little_minds_api/api.dart';

/// Generated OpenAPI clients with bearer injection for parent routes.
class AuthApiClients {
  AuthApiClients({required String basePath}) : bearer = HttpBearerAuth() {
    apiClient = ApiClient(basePath: basePath, authentication: bearer);
    auth = AuthApi(apiClient);
    parent = ParentApi(apiClient);
  }

  final HttpBearerAuth bearer;
  late final ApiClient apiClient;
  late final AuthApi auth;
  late final ParentApi parent;

  void setAccessToken(String? token) {
    bearer.accessToken = token ?? '';
  }
}

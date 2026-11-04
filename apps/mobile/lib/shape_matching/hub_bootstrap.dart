import '../config/app_config.dart';
import '../config/app_environment.dart';
import 'hub_device_child_binding.dart';
import 'hub_device_child_binding_client.dart';
import 'published_content_registry.dart';

/// LMP-134 composition-root helpers — environment-aware publication matrix.
PublishedContentRegistry publishedContentRegistryFor(AppConfig config) {
  switch (config.environment) {
    case AppEnvironment.development:
      return PinnedActivityPublicationRegistry();
    case AppEnvironment.staging:
    case AppEnvironment.production:
      // Synthetic seed fixtures are local/CI only; staging/prod fail closed
      // until LMP-69 release manifests (no dart-define override).
      return FailClosedPublishedContentRegistry();
  }
}

HubDeviceChildBindingClient hubDeviceChildBindingClientFor(AppConfig config) {
  return HttpHubDeviceChildBindingClient(apiBaseUrl: config.apiBaseUrl);
}

import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_token_store.dart';
import 'auth/installation_id_store.dart';
import 'auth/parent_auth_controller.dart';
import 'auth/parent_auth_repository.dart';
import 'config/app_config.dart';
import 'offline/activity_file_outbox.dart';
import 'offline/activity_outbox_sync.dart';
import 'offline/activity_telemetry_diagnostics.dart';
import 'screen_time/screen_time.dart';
import 'shape_matching/hub_authorized_device_child.dart';
import 'consent/essential_play_events_consent_client.dart';
import 'consent/essential_play_events_consent_service.dart';
import 'shape_matching/hub_bootstrap.dart';
import 'shape_matching/hub_device_child_binding.dart';
import 'shape_matching/hub_production_telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fail-fast on invalid public build-time config (LMP-28).
  final config = AppConfig.fromEnvironment();

  // Local screen-time SSoT (LMP-49). Storage open failures fail closed inside
  // the coordinator — never a silent fresh 30-minute day.
  final store = await SharedPreferencesPersistentStore.open();
  final screenTime = ScreenTimeCoordinator.withDependencies(
    monotonicClock: StopwatchMonotonicClock(),
    wallClock: const SystemWallClock(),
    store: store,
    tickInterval: const Duration(seconds: 15),
    persistEveryTicks: 4,
  );
  await screenTime.initialize();

  final parentAuth = ParentAuthController(
    repository: ParentAuthRepository(
      config: config,
      tokenStore: SecureAuthTokenStore(),
      installationIdStore: SecureInstallationIdStore(),
    ),
  );
  await parentAuth.bootstrap();

  final offlineOutbox = await ActivityFileOutbox.open();
  final offlineSync = ActivityOutboxSync(
    outbox: offlineOutbox,
    currentSession: () => parentAuth.session,
    refreshSession: (session) async {
      final access = await parentAuth.refreshForChildProfiles();
      if (access == null) return null;
      final active = parentAuth.session;
      if (active == null ||
          active.parentId != session.parentId ||
          active.sessionId != session.sessionId) {
        return null;
      }
      return active;
    },
    send: ActivityHttpBatchSender(apiBaseUrl: config.apiBaseUrl).send,
  );
  offlineOutbox.onEventPersisted = (pendingHint) {
    ActivityTelemetryDiagnostics.outboxEnqueued(pendingHint: pendingHint);
    offlineSync.scheduleFlush();
  };
  final publishedContent = publishedContentRegistryFor(config);
  final deviceChildCatalog = MemoryHubAuthorizedDeviceChildCatalog();
  final hubDeviceChildBinding = HubDeviceChildBindingService(
    catalog: deviceChildCatalog,
    client: hubDeviceChildBindingClientFor(config),
  );
  final essentialPlayConsent = EssentialPlayEventsConsentService(
    client: essentialPlayEventsConsentClientFor(config),
    outbox: offlineOutbox,
    offlineSync: offlineSync,
  );
  final hubTelemetry = HubProductionTelemetryCoordinator(
    outbox: offlineOutbox,
    contentRegistry: publishedContent,
    deviceChildCatalog: deviceChildCatalog,
    consentService: essentialPlayConsent,
  );

  runApp(
    LittleMindsApp(
      config: config,
      screenTime: screenTime,
      parentAuthController: parentAuth,
      offlineSync: offlineSync,
      hubTelemetry: hubTelemetry,
      hubDeviceChildBinding: hubDeviceChildBinding,
      essentialPlayConsent: essentialPlayConsent,
    ),
  );
}

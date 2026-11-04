import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_token_store.dart';
import 'auth/installation_id_store.dart';
import 'auth/parent_auth_controller.dart';
import 'auth/parent_auth_repository.dart';
import 'config/app_config.dart';
import 'offline/activity_file_outbox.dart';
import 'offline/activity_outbox_sync.dart';
import 'screen_time/screen_time.dart';
import 'shape_matching/hub_production_telemetry.dart';
import 'shape_matching/published_content_registry.dart';

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
    send: ActivityHttpBatchSender(apiBaseUrl: config.apiBaseUrl).send,
  );
  final publishedContent = FailClosedPublishedContentRegistry();
  final hubTelemetry = HubProductionTelemetryCoordinator(
    outbox: offlineOutbox,
    contentRegistry: publishedContent,
  );

  runApp(
    LittleMindsApp(
      config: config,
      screenTime: screenTime,
      parentAuthController: parentAuth,
      offlineSync: offlineSync,
      hubTelemetry: hubTelemetry,
    ),
  );
}

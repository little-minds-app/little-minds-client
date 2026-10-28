import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'screen_time/screen_time.dart';

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

  runApp(
    LittleMindsApp(
      config: config,
      screenTime: screenTime,
    ),
  );
}

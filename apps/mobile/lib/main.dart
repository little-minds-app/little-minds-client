import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fail-fast on invalid public build-time config (LMP-28).
  final config = AppConfig.fromEnvironment();
  runApp(LittleMindsApp(config: config));
}

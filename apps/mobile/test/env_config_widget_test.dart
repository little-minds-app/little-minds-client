import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/config/app_environment.dart';
import 'package:little_minds_mobile/config/env_config_badge.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/shell/adaptive_shell.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';

Future<void> _pumpFrames(WidgetTester tester, [int times = 3]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _setSurface(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  final view = tester.view;
  view.physicalSize = Size(width, height);
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // TC-ENV-006 — App boots with resolved development config; badge visible.
  testWidgets('TC-ENV-006 boots with development config badge', (tester) async {
    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneWidth,
      height: ScaffoldingViewports.compactPhoneHeight,
    );

    final config = AppConfig.resolve(
      envName: 'development',
      apiBaseUrl: 'http://localhost:3000',
    );

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        config: config,
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(EnvConfigBadge.badgeKey), findsOneWidget);
    expect(
      find.textContaining('env=${AppEnvironment.development.wireName}'),
      findsOneWidget,
    );
    expect(find.textContaining('api=http://localhost:3000'), findsOneWidget);
  });

  // TC-ENV-007 — F-034 compact + expanded still compose with injected config.
  testWidgets('TC-ENV-007 compact and expanded chrome with staging config',
      (tester) async {
    final config = AppConfig.resolve(
      envName: 'staging',
      apiBaseUrl: 'https://api.staging.example.test',
    );

    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneWidth,
      height: ScaffoldingViewports.compactPhoneHeight,
    );
    await tester.pumpWidget(
      LittleMindsApp(game: StubLearningGame(), config: config),
    );
    await _pumpFrames(tester);

    expect(find.byKey(AdaptiveShell.compactChromeKey), findsOneWidget);
    expect(find.textContaining('env=staging'), findsOneWidget);

    await _setSurface(
      tester,
      width: ScaffoldingViewports.tabletWidth,
      height: ScaffoldingViewports.tabletHeight,
    );
    await tester.pumpWidget(
      LittleMindsApp(game: StubLearningGame(), config: config),
    );
    await _pumpFrames(tester);

    expect(find.byKey(AdaptiveShell.expandedChromeKey), findsOneWidget);
    expect(find.byKey(AdaptiveShell.dualPaneKey), findsOneWidget);
    expect(find.textContaining('env=staging'), findsOneWidget);
  });
}

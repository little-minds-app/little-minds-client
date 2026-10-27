import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
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

  // TC-ENV-006 — Badge is developer/test only on Child Hub (not child-facing).
  testWidgets('TC-ENV-006 env badge hidden by default; visible when forced',
      (tester) async {
    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );

    final config = AppConfig.resolve(
      envName: 'development',
      apiBaseUrl: 'http://localhost:3000',
    );

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        config: config,
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(EnvConfigBadge.badgeKey), findsNothing);

    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        config: config,
        audioGuidance: RecordingHubAudioGuidance(),
        forceShowEnvBadge: true,
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(EnvConfigBadge.badgeKey), findsOneWidget);
    expect(
      find.textContaining('env=${AppEnvironment.development.wireName}'),
      findsOneWidget,
    );
    expect(find.textContaining('api=http://localhost:3000'), findsOneWidget);
  });

  // TC-ENV-007 — F-034 compact carousel + expanded grid with staging config.
  testWidgets('TC-ENV-007 compact and expanded hub layout with staging config',
      (tester) async {
    final config = AppConfig.resolve(
      envName: 'staging',
      apiBaseUrl: 'https://api.staging.example.test',
    );

    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        config: config,
        audioGuidance: RecordingHubAudioGuidance(),
        forceShowEnvBadge: true,
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.compactLayoutKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.activityCarouselKey), findsOneWidget);
    expect(find.textContaining('env=staging'), findsOneWidget);

    await _setSurface(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        config: config,
        audioGuidance: RecordingHubAudioGuidance(),
        forceShowEnvBadge: true,
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.expandedLayoutKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.activityGridKey), findsOneWidget);
    expect(find.textContaining('env=staging'), findsOneWidget);

    await tester.ensureVisible(find.byKey(ChildHubSurface.parentExitKey));
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    expect(find.byKey(AdaptiveShell.expandedChromeKey), findsOneWidget);
  });
}

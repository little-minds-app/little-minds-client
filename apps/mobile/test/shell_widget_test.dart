import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/orientation/app_surface.dart';
import 'package:little_minds_mobile/orientation/orientation_policy.dart';
import 'package:little_minds_mobile/shell/adaptive_shell.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';
import 'package:little_minds_mobile/surfaces/profile_selection_surface.dart';

/// Flame's GameWidget schedules continuous frames; avoid pumpAndSettle.
Future<void> _pumpFrames(WidgetTester tester, [int times = 3]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _setSurface(
  WidgetTester tester, {
  required double width,
  required double height,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  final view = tester.view;
  view.physicalSize = Size(width, height);
  view.devicePixelRatio = 1.0;
  view.padding = FakeViewPadding(
    left: padding.left,
    top: padding.top,
    right: padding.right,
    bottom: padding.bottom,
  );
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
  addTearDown(view.resetPadding);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // TC-SHELL-001 — App boots; primary navigation targets present.
  testWidgets('TC-SHELL-001 boots to shell with primary navigation',
      (tester) async {
    await _setSurface(
      tester,
      // Landscape phone (ADR-018 Child Hub).
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.homeKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.profilesKey), findsOneWidget);
    expect(find.byKey(ChildHubSurface.parentExitKey), findsOneWidget);

    await tester.tap(find.byKey(ChildHubSurface.profilesKey));
    await _pumpFrames(tester);
    expect(find.byKey(ProfileSelectionSurface.surfaceKey), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-back-hub')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);
    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
  });

  // TC-SHELL-002 — Compact vs expanded layout (F-034) on Parent Gate shell.
  testWidgets('TC-SHELL-002 compact vs expanded chrome recomposes',
      (tester) async {
    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneWidth,
      height: ScaffoldingViewports.compactPhoneHeight,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.parentExitKey), findsOneWidget);
    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);

    expect(find.byKey(AdaptiveShell.compactChromeKey), findsOneWidget);
    expect(find.byKey(AdaptiveShell.expandedChromeKey), findsNothing);
    expect(find.byKey(AdaptiveShell.dualPaneKey), findsNothing);

    // Stay on Parent Gate and only resize — preserves AdaptiveShell probe.
    await _setSurface(
      tester,
      width: ScaffoldingViewports.tabletWidth,
      height: ScaffoldingViewports.tabletHeight,
    );
    await _pumpFrames(tester);

    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    expect(find.byKey(AdaptiveShell.expandedChromeKey), findsOneWidget);
    expect(find.byKey(AdaptiveShell.dualPaneKey), findsOneWidget);
    expect(find.byKey(AdaptiveShell.compactChromeKey), findsNothing);
  });

  // TC-SHELL-003 — Child Hub landscape policy (portrait not accepted for route).
  testWidgets('TC-SHELL-003 Child Hub uses landscape-only ADR-018 policy',
      (tester) async {
    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(ChildHubSurface.surfaceKey), findsOneWidget);
    expect(OrientationPolicy.isLandscapeOnly(AppSurface.childHub), isTrue);
    expect(
      OrientationPolicy.allowedOrientations(AppSurface.childHub),
      isNot(contains(DeviceOrientation.portraitUp)),
    );

    await tester.tap(find.byKey(ChildHubSurface.profilesKey));
    await _pumpFrames(tester);
    expect(
      OrientationPolicy.isLandscapeOnly(AppSurface.profileSelection),
      isTrue,
    );
  });

  // TC-SHELL-004 — Parent Gate preserves state across orientation change.
  testWidgets('TC-SHELL-004 Parent Gate preserves note across orientation',
      (tester) async {
    final parentAuth = ParentAuthController(
      repository: ParentAuthRepository(
        config: AppConfig.developmentLocal,
        tokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await parentAuth.bootstrap();
    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneWidth,
      height: ScaffoldingViewports.compactPhoneHeight,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
        parentAuthController: parentAuth,
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('parent-auth-phone-entry')));
    await _pumpFrames(tester);
    await tester.enterText(
      find.byKey(ParentGateSurface.phoneFieldKey),
      'keep-me-across-rotation',
    );
    await _pumpFrames(tester);

    expect(find.text('keep-me-across-rotation'), findsOneWidget);

    // Rotate to landscape while staying on Parent Gate.
    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await _pumpFrames(tester);

    expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
    expect(find.text('keep-me-across-rotation'), findsOneWidget);
    expect(find.byKey(ParentGateSurface.phoneFieldKey), findsOneWidget);
    expect(OrientationPolicy.isLandscapeOnly(AppSurface.parentGate), isFalse);
  });

  // TC-SHELL-005 — SafeArea / MediaQuery padding respected.
  testWidgets('TC-SHELL-005 shell respects safe-area padding', (tester) async {
    const notch = EdgeInsets.only(top: 48, bottom: 24, left: 12, right: 12);
    await _setSurface(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
      padding: notch,
    );
    await tester.pumpWidget(
      LittleMindsApp(
        game: StubLearningGame(),
        audioGuidance: RecordingHubAudioGuidance(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byType(SafeArea), findsWidgets);

    final brand = tester.getRect(find.byKey(ChildHubSurface.brandKey));
    expect(brand.top, greaterThanOrEqualTo(notch.top));
    expect(brand.left, greaterThanOrEqualTo(notch.left));
  });
}

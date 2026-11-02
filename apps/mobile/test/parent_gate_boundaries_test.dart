import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/app.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/surfaces/child_hub_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_gate_surface.dart';
import 'package:little_minds_mobile/surfaces/parent_settings_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in <Size>[const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('LMP-42 signed-out child cannot reach parent settings at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = ParentAuthController(
        repository: ParentAuthRepository(
          config: AppConfig.developmentLocal,
          tokenStore: InMemoryAuthTokenStore(),
        ),
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(LittleMindsApp(
        parentAuthController: auth,
      ));
      await tester.pump();

      expect(find.byKey(ParentSettingsSurface.surfaceKey), findsNothing);
      await tester.tap(find.byKey(ChildHubSurface.parentExitKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ParentGateSurface.surfaceKey), findsOneWidget);
      expect(find.byKey(ParentSettingsSurface.surfaceKey), findsNothing);
      expect(find.byKey(const Key('nav-parent-settings')), findsNothing);
      expect(find.byKey(const Key('parent-auth-open-settings')), findsNothing);
    });
  }
}

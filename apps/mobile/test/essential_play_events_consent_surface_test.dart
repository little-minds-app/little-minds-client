import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/auth/auth_token_store.dart';
import 'package:little_minds_mobile/auth/parent_auth_controller.dart';
import 'package:little_minds_mobile/auth/parent_auth_repository.dart';
import 'package:little_minds_mobile/auth/parent_auth_scope.dart';
import 'package:little_minds_mobile/config/app_config.dart';
import 'package:little_minds_mobile/consent/essential_play_events_consent_scope.dart';
import 'package:little_minds_mobile/consent/essential_play_events_consent_service.dart';
import 'package:little_minds_mobile/offline/activity_file_outbox.dart';
import 'package:little_minds_mobile/shape_matching/published_content_registry.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_constants.dart';
import 'package:little_minds_mobile/surfaces/essential_play_events_consent_surface.dart';

import 'support/fake_essential_play_events_consent_client.dart';

void main() {
  testWidgets('grant requires explicit unchecked opt-in', (tester) async {
    final auth = ParentAuthController(
      repository: ParentAuthRepository(
        config: AppConfig.developmentLocal,
        tokenStore: InMemoryAuthTokenStore(),
      ),
    );
    auth.seedAuthenticatedSessionForTests(
      const AuthSession(
        parentId: '11111111-1111-4111-8111-111111111111',
        sessionId: '00000000-0000-4000-8000-000000000001',
        accessToken: 't',
        refreshToken: 'r',
        expiresInSeconds: 300,
      ),
    );
    final client = FakeEssentialPlayEventsConsentClient();
    final outbox = ActivityFileOutbox.forTesting(
      await Directory.systemTemp.createTemp('consent-ui-'),
    );
    final service = EssentialPlayEventsConsentService(
      client: client,
      outbox: outbox,
    );
    final registry = MapPublishedContentRegistry({
      ShapeMatchingConstants.activityId: PublishedActivityPublication(
        contentVersionId: '33333333-3333-4333-8333-333333333333',
        consentPolicyVersion: 'synthetic-policy-v1',
      ),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ParentAuthScope(
          controller: auth,
          child: EssentialPlayEventsConsentScope(
            notifier: service,
            child: EssentialPlayEventsConsentSurface(
              publicationRegistry: registry,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final grant = find.byKey(EssentialPlayEventsConsentSurface.grantButtonKey);
    final button = tester.widget<FilledButton>(grant);
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(EssentialPlayEventsConsentSurface.optInCheckboxKey));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(grant).onPressed, isNotNull);
    await tester.tap(grant);
    await tester.pumpAndSettle();
    expect(client.grantCalls, 1);
    expect(client.lastGrantPolicy, 'synthetic-policy-v1');
  });
}

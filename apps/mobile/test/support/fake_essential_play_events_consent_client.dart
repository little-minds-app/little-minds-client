import 'package:little_minds_mobile/auth/auth_session.dart';
import 'package:little_minds_mobile/consent/essential_play_events_consent.dart';
import 'package:little_minds_mobile/consent/essential_play_events_consent_client.dart';

class FakeEssentialPlayEventsConsentClient
    implements EssentialPlayEventsConsentClient {
  FakeEssentialPlayEventsConsentClient({
    this.initialStatus,
  });

  EssentialPlayEventsConsentStatus? initialStatus;
  int grantCalls = 0;
  int withdrawCalls = 0;
  String? lastGrantPolicy;

  @override
  Future<EssentialPlayEventsConsentStatus?> fetchStatus(
    AuthSession session,
  ) async =>
      initialStatus;

  @override
  Future<EssentialPlayEventsConsentStatus?> grant({
    required AuthSession session,
    required String policyVersion,
    required String consentTextVersion,
  }) async {
    grantCalls++;
    lastGrantPolicy = policyVersion;
    initialStatus = EssentialPlayEventsConsentStatus(
      authorized: true,
      effectiveStatus: 'granted',
      policyVersion: policyVersion,
    );
    return initialStatus;
  }

  @override
  Future<EssentialPlayEventsConsentStatus?> withdraw({
    required AuthSession session,
    required String policyVersion,
  }) async {
    withdrawCalls++;
    initialStatus = const EssentialPlayEventsConsentStatus(
      authorized: false,
      effectiveStatus: 'withdrawn',
    );
    return initialStatus;
  }
}

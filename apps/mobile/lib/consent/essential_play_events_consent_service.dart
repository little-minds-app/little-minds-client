import 'package:flutter/foundation.dart';

import '../auth/auth_session.dart';
import '../offline/activity_file_outbox.dart';
import '../offline/activity_outbox_sync.dart';
import '../shape_matching/shape_matching_production_consent.dart';
import 'essential_play_events_consent.dart';
import 'essential_play_events_consent_client.dart';

/// Cached server consent for production play telemetry (LMP-134).
class EssentialPlayEventsConsentService extends ChangeNotifier {
  EssentialPlayEventsConsentService({
    required EssentialPlayEventsConsentClient this._client,
    required ActivityFileOutbox this._outbox,
    ActivityOutboxSync? this._offlineSync,
  });

  final EssentialPlayEventsConsentClient _client;
  final ActivityFileOutbox _outbox;
  final ActivityOutboxSync? _offlineSync;

  EssentialPlayEventsConsentStatus? _status;
  String? _boundParentId;
  String? _boundSessionId;

  EssentialPlayEventsConsentStatus? get status => _status;

  bool get hasEffectiveGrant =>
      _status?.authorized == true &&
      (_status!.effectiveStatus == 'granted' ||
          _status!.effectiveStatus == 'Granted');

  /// True when server grant matches the publication policy on the wire.
  bool isAuthorizedForPolicy(String policyVersion) {
    if (!hasEffectiveGrant) return false;
    final serverPolicy = _status!.policyVersion;
    if (serverPolicy == null || serverPolicy.isEmpty) return false;
    return serverPolicy == policyVersion;
  }

  void clearForLogout() {
    _status = null;
    _boundParentId = null;
    _boundSessionId = null;
    notifyListeners();
  }

  Future<EssentialPlayEventsConsentStatus?> refresh(AuthSession session) async {
    if (_boundParentId != session.parentId ||
        _boundSessionId != session.sessionId) {
      _status = null;
    }
    _boundParentId = session.parentId;
    _boundSessionId = session.sessionId;
    try {
      _status = await _client.fetchStatus(session);
    } catch (_) {
      // Keep last known status on transient errors; fail closed for new grants.
    }
    notifyListeners();
    return _status;
  }

  Future<EssentialPlayEventsConsentMutationResult> grant({
    required AuthSession session,
    required String policyVersion,
  }) async {
    try {
      final next = await _client.grant(
        session: session,
        policyVersion: policyVersion,
        consentTextVersion: EssentialPlayEventsConsentCopy.consentTextVersion,
      );
      if (next == null) {
        return const EssentialPlayEventsConsentMutationFailed(
          'Consent service is not available yet.',
        );
      }
      _boundParentId = session.parentId;
      _boundSessionId = session.sessionId;
      _status = next;
      notifyListeners();
      if (next.authorized) {
        await _requeueQuarantinedPlayEvents(session.parentId);
      }
      return EssentialPlayEventsConsentMutationOk(next);
    } on Object catch (error) {
      return EssentialPlayEventsConsentMutationFailed('$error');
    }
  }

  Future<EssentialPlayEventsConsentMutationResult> withdraw(
    AuthSession session, {
    String? policyVersion,
  }) async {
    final policy = policyVersion ?? _status?.policyVersion;
    if (policy == null || policy.isEmpty) {
      return const EssentialPlayEventsConsentMutationFailed(
        'Missing policy version for withdrawal.',
      );
    }
    try {
      final next = await _client.withdraw(
        session: session,
        policyVersion: policy,
      );
      if (next == null) {
        return const EssentialPlayEventsConsentMutationFailed(
          'Consent service is not available yet.',
        );
      }
      _status = next;
      notifyListeners();
      await _outbox.purgeConsentScope(
        session.parentId,
        ShapeMatchingProductionConsent.scope,
      );
      return EssentialPlayEventsConsentMutationOk(next);
    } on Object catch (error) {
      return EssentialPlayEventsConsentMutationFailed('$error');
    }
  }

  Future<int> _requeueQuarantinedPlayEvents(String parentId) async {
    final requeued = await _outbox.requeueQuarantinedConsentScope(
      parentId,
      ShapeMatchingProductionConsent.scope,
    );
    if (requeued > 0) {
      _offlineSync?.scheduleFlush();
    }
    return requeued;
  }
}

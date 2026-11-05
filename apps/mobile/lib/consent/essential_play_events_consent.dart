/// LMP-134 / F-033 — server-attested opt-in for Shape Matching play telemetry.
abstract final class EssentialPlayEventsConsentCopy {
  static const purpose = 'essential_play_events';

  /// Draft placeholder until legal sign-off (distinct from [AuthPrivacyNotice]).
  static const consentTextVersion = 'essential-play-events-v1-draft';

  static const screenTitle = 'Play activity sync';

  static const lead =
      'Optional: share minimal play activity from Shape Matching so we can '
      'improve the game. This is separate from the privacy notice you saw at '
      'sign-in and separate from the Parent Gate PIN.';

  static const checkboxLabel =
      'I agree to sync essential play activity events for product improvement '
      '(not pre-selected; you can withdraw later in Parent Settings).';

  static const declineLabel = 'Not now';

  static const grantLabel = 'Save choice';

  static const withdrawLabel = 'Withdraw play activity sync';

  static const withdrawConfirm =
      'New play events will stay on this device only until you opt in again. '
      'Queued uploads for this purpose will stop.';
}

/// Server-reported authorization for [EssentialPlayEventsConsentCopy.purpose].
class EssentialPlayEventsConsentStatus {
  const EssentialPlayEventsConsentStatus({
    required this.authorized,
    required this.effectiveStatus,
    this.policyVersion,
  });

  final bool authorized;
  final String effectiveStatus;
  final String? policyVersion;

  factory EssentialPlayEventsConsentStatus.fromJson(Map<String, dynamic> json) {
    final authorized = json['authorized'] == true;
    final status = json['effective_status'] ?? json['status'] ?? 'unknown';
    return EssentialPlayEventsConsentStatus(
      authorized: authorized,
      effectiveStatus: status is String ? status : status.toString(),
      policyVersion: json['policy_version'] as String?,
    );
  }
}

sealed class EssentialPlayEventsConsentMutationResult {
  const EssentialPlayEventsConsentMutationResult();
}

final class EssentialPlayEventsConsentMutationOk
    extends EssentialPlayEventsConsentMutationResult {
  const EssentialPlayEventsConsentMutationOk(this.status);
  final EssentialPlayEventsConsentStatus status;
}

final class EssentialPlayEventsConsentMutationFailed
    extends EssentialPlayEventsConsentMutationResult {
  const EssentialPlayEventsConsentMutationFailed(this.message);
  final String message;
}

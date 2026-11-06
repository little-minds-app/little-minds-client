import 'dart:async';

import '../core/canonical_rfc4122_uuid.dart';
import '../offline/activity_event_emitter.dart';
import 'animal_sound_matching_events.dart';
import 'animal_sound_matching_production_consent.dart';
import 'animal_sound_matching_wire_payload.dart';

/// Optional production adapter — construct only with server-bound UUID session ids.
///
/// Do not construct when authoritative Animal Sound Matching `content_version_id`
/// is unavailable — hub telemetry must fail closed (local buffer only).
class AnimalSoundMatchingProductionEventBuffer
    extends AnimalSoundMatchingLocalEventBuffer {
  AnimalSoundMatchingProductionEventBuffer({
    required this.emitter,
    required this.sessionPayload,
    required String deviceId,
    required String contentVersionId,
  }) : super(deviceId: deviceId, contentVersionId: contentVersionId) {
    if (!CanonicalRfc4122Uuid.isValid(deviceId) ||
        !CanonicalRfc4122Uuid.isValid(contentVersionId) ||
        !CanonicalRfc4122Uuid.isValid(
          sessionPayload['play_session_id']?.toString() ?? '',
        ) ||
        emitter.deviceId != deviceId ||
        emitter.contentVersionId != contentVersionId ||
        sessionPayload['consent'] is! Map ||
        (sessionPayload['consent'] as Map)['purpose'] !=
            AnimalSoundMatchingProductionConsent.purpose ||
        (sessionPayload['consent'] as Map)['consent_scope'] !=
            AnimalSoundMatchingProductionConsent.scope ||
        (sessionPayload['consent'] as Map)['policy_version'] !=
            emitter.consentPolicyVersion ||
        sessionPayload['schema_version'] != '1.0.0' ||
        sessionPayload['device_id'] != deviceId ||
        sessionPayload['content_version_id'] != contentVersionId) {
      throw ArgumentError(
        'production Animal Sound Matching session must be server-bound',
      );
    }
  }

  final ActivityEventEmitter emitter;
  final Map<String, dynamic> sessionPayload;
  final List<AnimalSoundMatchingActivityEvent> _pending = [];
  Future<void>? _draining;
  final Stopwatch _duration = Stopwatch();
  int _hintsUsed = 0;
  int _eligibleFirstAttempts = 0;
  int _correctFirstAttempts = 0;

  /// Round indexes whose first attempt has already been counted this session.
  final Set<int> _firstAttemptRoundsCounted = <int>{};

  @override
  AnimalSoundMatchingActivityEvent emit({
    required String playSessionId,
    required AnimalSoundMatchingEventType type,
    Map<String, Object?> payload = const {},
    int? monotonicDurationSeconds,
  }) {
    if (playSessionId != sessionPayload['play_session_id']) {
      throw ArgumentError('Animal Sound Matching session ID mismatch');
    }
    final event = super.emit(
      playSessionId: playSessionId,
      type: type,
      payload: payload,
      monotonicDurationSeconds: monotonicDurationSeconds,
    );
    if (type == AnimalSoundMatchingEventType.activityStarted) {
      if (!_duration.isRunning) {
        _duration.start();
      }
      if (event.payload['restart'] == true) {
        _resetSessionTallies();
      }
    }
    if (type == AnimalSoundMatchingEventType.activityHintUsed) {
      _hintsUsed++;
    }
    if (type == AnimalSoundMatchingEventType.activityAttempted) {
      _countFirstAttemptIfEligible(event);
    }
    _pending.add(event);
    unawaited(drain().catchError((Object _) {}));
    return event;
  }

  void _resetSessionTallies() {
    _hintsUsed = 0;
    _eligibleFirstAttempts = 0;
    _correctFirstAttempts = 0;
    _firstAttemptRoundsCounted.clear();
  }

  /// Counts at most one eligible first attempt per [round_index].
  ///
  /// Visual-fallback attempts still count locally but [prompt_mode] is stripped
  /// on the wire so they are never claimed as sound-recognition performance.
  void _countFirstAttemptIfEligible(AnimalSoundMatchingActivityEvent event) {
    final roundIndex = event.payload['round_index'];
    if (roundIndex is! int) return;
    if (_firstAttemptRoundsCounted.contains(roundIndex)) return;
    _firstAttemptRoundsCounted.add(roundIndex);
    _eligibleFirstAttempts++;
    if (event.payload['correct'] == true) {
      _correctFirstAttempts++;
    }
  }

  Future<void> drain() async {
    if (_draining != null) return _draining;
    final work = _persistPending();
    _draining = work;
    try {
      await work;
    } finally {
      _draining = null;
    }
  }

  Future<void> _persistPending() async {
    while (_pending.isNotEmpty) {
      final event = _pending.first;
      final durationBearing = event.eventType ==
              AnimalSoundMatchingEventType.activityCompleted.wireName ||
          event.eventType ==
              AnimalSoundMatchingEventType.activityAbandoned.wireName;
      await emitter.emit(
        eventType: event.eventType,
        consentScope: AnimalSoundMatchingProductionConsent.scope,
        payload: _canonicalPayload(event),
        source: 'instrumented',
        emitter: 'kids_mode_client',
        playSessionId: event.playSessionId,
        sessionPayload: _sessionFor(event),
        durationSeconds: durationBearing
            ? (event.monotonicDurationSeconds ?? _duration.elapsed.inSeconds)
            : null,
      );
      _pending.removeAt(0);
    }
  }

  Map<String, dynamic> _sessionFor(AnimalSoundMatchingActivityEvent event) {
    final copy = Map<String, dynamic>.from(sessionPayload);
    final finished = event.eventType ==
            AnimalSoundMatchingEventType.activityCompleted.wireName ||
        event.eventType ==
            AnimalSoundMatchingEventType.activityAbandoned.wireName;
    if (finished) {
      copy['ended_at'] = event.occurredAt.toUtc().toIso8601String();
      copy['completion_status'] = event.eventType ==
              AnimalSoundMatchingEventType.activityCompleted.wireName
          ? 'completed'
          : 'abandoned';
      copy['monotonic_duration_seconds'] =
          event.monotonicDurationSeconds ?? _duration.elapsed.inSeconds;
    }
    return copy;
  }

  Map<String, dynamic> _canonicalPayload(
    AnimalSoundMatchingActivityEvent event,
  ) {
    return AnimalSoundMatchingWirePayload.canonicalPayload(
      eventType: event.eventType,
      instrumentPayload: Map<String, dynamic>.from(event.payload),
      hintsUsed: _hintsUsed,
      eligibleFirstAttempts: event.eventType ==
              AnimalSoundMatchingEventType.activityCompleted.wireName
          ? _eligibleFirstAttempts
          : null,
      correctFirstAttempts: event.eventType ==
              AnimalSoundMatchingEventType.activityCompleted.wireName
          ? _correctFirstAttempts
          : null,
    );
  }
}

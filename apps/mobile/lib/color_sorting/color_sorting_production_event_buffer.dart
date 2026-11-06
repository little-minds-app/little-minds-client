import 'dart:async';

import '../core/canonical_rfc4122_uuid.dart';
import '../offline/activity_event_emitter.dart';
import 'color_sorting_events.dart';
import 'color_sorting_production_consent.dart';
import 'color_sorting_wire_payload.dart';

/// Optional production adapter — construct only with server-bound UUID session ids.
///
/// Do not construct when authoritative Color Sorting `content_version_id` is
/// unavailable — hub telemetry must fail closed (local buffer only).
class ColorSortingProductionEventBuffer extends ColorSortingLocalEventBuffer {
  ColorSortingProductionEventBuffer({
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
            ColorSortingProductionConsent.purpose ||
        (sessionPayload['consent'] as Map)['consent_scope'] !=
            ColorSortingProductionConsent.scope ||
        (sessionPayload['consent'] as Map)['policy_version'] !=
            emitter.consentPolicyVersion ||
        sessionPayload['schema_version'] != '1.0.0' ||
        sessionPayload['device_id'] != deviceId ||
        sessionPayload['content_version_id'] != contentVersionId) {
      throw ArgumentError(
        'production Color Sorting session must be server-bound',
      );
    }
  }

  final ActivityEventEmitter emitter;
  final Map<String, dynamic> sessionPayload;
  final List<ColorSortingActivityEvent> _pending = [];
  Future<void>? _draining;
  final Stopwatch _duration = Stopwatch();
  int _hintsUsed = 0;
  int _eligibleFirstAttempts = 0;
  int _correctFirstAttempts = 0;

  @override
  ColorSortingActivityEvent emit({
    required String playSessionId,
    required ColorSortingEventType type,
    Map<String, Object?> payload = const {},
    int? monotonicDurationSeconds,
  }) {
    if (playSessionId != sessionPayload['play_session_id']) {
      throw ArgumentError('Color Sorting session ID mismatch');
    }
    final event = super.emit(
      playSessionId: playSessionId,
      type: type,
      payload: payload,
      monotonicDurationSeconds: monotonicDurationSeconds,
    );
    if (type == ColorSortingEventType.activityStarted && !_duration.isRunning) {
      _duration.start();
    }
    if (type == ColorSortingEventType.activityHintUsed) {
      _hintsUsed++;
    }
    if (type == ColorSortingEventType.activityAttempted) {
      final correct = event.payload['correct'] == true;
      _eligibleFirstAttempts++;
      if (correct) _correctFirstAttempts++;
    }
    _pending.add(event);
    unawaited(drain().catchError((Object _) {}));
    return event;
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
      final durationBearing =
          event.eventType == ColorSortingEventType.activityCompleted.wireName ||
              event.eventType ==
                  ColorSortingEventType.activityAbandoned.wireName;
      await emitter.emit(
        eventType: event.eventType,
        consentScope: ColorSortingProductionConsent.scope,
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

  Map<String, dynamic> _sessionFor(ColorSortingActivityEvent event) {
    final copy = Map<String, dynamic>.from(sessionPayload);
    final finished =
        event.eventType == ColorSortingEventType.activityCompleted.wireName ||
            event.eventType == ColorSortingEventType.activityAbandoned.wireName;
    if (finished) {
      copy['ended_at'] = event.occurredAt.toUtc().toIso8601String();
      copy['completion_status'] =
          event.eventType == ColorSortingEventType.activityCompleted.wireName
              ? 'completed'
              : 'abandoned';
      copy['monotonic_duration_seconds'] =
          event.monotonicDurationSeconds ?? _duration.elapsed.inSeconds;
    }
    return copy;
  }

  Map<String, dynamic> _canonicalPayload(ColorSortingActivityEvent event) {
    return ColorSortingWirePayload.canonicalPayload(
      eventType: event.eventType,
      instrumentPayload: Map<String, dynamic>.from(event.payload),
      hintsUsed: _hintsUsed,
      eligibleFirstAttempts:
          event.eventType == ColorSortingEventType.activityCompleted.wireName
              ? _eligibleFirstAttempts
              : null,
      correctFirstAttempts:
          event.eventType == ColorSortingEventType.activityCompleted.wireName
              ? _correctFirstAttempts
              : null,
    );
  }
}

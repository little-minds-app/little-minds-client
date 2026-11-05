import 'dart:async';

import '../core/canonical_rfc4122_uuid.dart';
import '../offline/activity_event_emitter.dart';
import 'shape_matching_constants.dart';
import 'shape_matching_events.dart';
import 'shape_matching_production_consent.dart';

/// Optional production adapter — construct only with server-bound UUID session ids.
class ShapeMatchingProductionEventBuffer extends ShapeMatchingLocalEventBuffer {
  ShapeMatchingProductionEventBuffer({
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
            ShapeMatchingProductionConsent.purpose ||
        (sessionPayload['consent'] as Map)['consent_scope'] !=
            ShapeMatchingProductionConsent.scope ||
        (sessionPayload['consent'] as Map)['policy_version'] !=
            emitter.consentPolicyVersion ||
        sessionPayload['schema_version'] != '1.0.0' ||
        sessionPayload['device_id'] != deviceId ||
        sessionPayload['content_version_id'] != contentVersionId) {
      throw ArgumentError(
        'production Shape Matching session must be server-bound',
      );
    }
  }

  final ActivityEventEmitter emitter;
  final Map<String, dynamic> sessionPayload;
  final List<ShapeMatchingActivityEvent> _pending = [];
  Future<void>? _draining;
  final Stopwatch _duration = Stopwatch();

  @override
  ShapeMatchingActivityEvent emit({
    required String playSessionId,
    required ShapeMatchingEventType type,
    Map<String, Object?> payload = const {},
    int? monotonicDurationSeconds,
  }) {
    if (playSessionId != sessionPayload['play_session_id']) {
      throw ArgumentError('Shape Matching session ID mismatch');
    }
    final event = super.emit(
      playSessionId: playSessionId,
      type: type,
      payload: payload,
      monotonicDurationSeconds: monotonicDurationSeconds,
    );
    if (type == ShapeMatchingEventType.activityStarted && !_duration.isRunning) {
      _duration.start();
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
          event.eventType == ShapeMatchingEventType.activityCompleted.wireName ||
              event.eventType ==
                  ShapeMatchingEventType.activityAbandoned.wireName;
      await emitter.emit(
        eventType: event.eventType,
        consentScope: ShapeMatchingProductionConsent.scope,
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

  Map<String, dynamic> _sessionFor(ShapeMatchingActivityEvent event) {
    final copy = Map<String, dynamic>.from(sessionPayload);
    final finished =
        event.eventType == ShapeMatchingEventType.activityCompleted.wireName ||
            event.eventType == ShapeMatchingEventType.activityAbandoned.wireName;
    if (finished) {
      copy['ended_at'] = event.occurredAt.toUtc().toIso8601String();
      copy['completion_status'] =
          event.eventType == ShapeMatchingEventType.activityCompleted.wireName
              ? 'completed'
              : 'abandoned';
      copy['monotonic_duration_seconds'] =
          event.monotonicDurationSeconds ?? _duration.elapsed.inSeconds;
    }
    return copy;
  }

  Map<String, dynamic> _canonicalPayload(ShapeMatchingActivityEvent event) {
    final p = event.payload;
    switch (event.eventType) {
      case 'activity_started':
        return {
          'age_months': p['age_months'],
          'activity_variant_id': ShapeMatchingConstants.activityId,
          if (p['restart'] == true) 'restart': true,
        };
      case 'activity_attempted':
        return {
          'shape_id': p['shape_id'],
          'correct': p['correct'],
          'round_index': p['round_index'],
        };
      case 'activity_hint_used':
        return {'hint_level': p['hint_level']};
      case 'activity_completed':
        return {'completion_status': 'completed', 'scoring': 'neutral'};
      case 'activity_abandoned':
        return {'completion_status': 'abandoned'};
      default:
        throw ArgumentError('Shape Matching production event type not mapped');
    }
  }
}

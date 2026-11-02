import 'dart:async';

import '../offline/activity_event_emitter.dart';
import 'near_far_constants.dart';
import 'near_far_events.dart';

/// Optional production adapter for the Near/Far activity. Construct ONLY after
/// the authenticated parent has a server-registered device/child binding and
/// a published UUID content version. The default demo buffer stays local-only.
///
/// The adapter preserves the existing synchronous game event API while
/// serializing durable writes; app lifecycle must await [drain] on exit/pause.
/// Any failed write stays pending in memory and drain surfaces the error.
class NearFarProductionEventBuffer extends NearFarLocalEventBuffer {
  NearFarProductionEventBuffer({
    required this.emitter,
    required this.sessionPayload,
    required String deviceId,
    required String contentVersionId,
  }) : super(deviceId: deviceId, contentVersionId: contentVersionId) {
    // Fail closed on fixture identifiers and mismatched emitter binding.
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[47][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuid.hasMatch(deviceId) ||
        !uuid.hasMatch(contentVersionId) ||
        !uuid.hasMatch(sessionPayload['play_session_id']?.toString() ?? '') ||
        emitter.deviceId != deviceId ||
        emitter.contentVersionId != contentVersionId ||
        sessionPayload['schema_version'] != '1.0.0' ||
        sessionPayload['device_id'] != deviceId ||
        sessionPayload['content_version_id'] != contentVersionId) {
      throw ArgumentError('production Near/Far session must be server-bound');
    }
  }

  final ActivityEventEmitter emitter;
  final Map<String, dynamic> sessionPayload;
  final List<NearFarActivityEvent> _pending = [];
  Future<void>? _draining;
  final Stopwatch _duration = Stopwatch();

  @override
  NearFarActivityEvent emit({
    required String playSessionId,
    required NearFarEventType type,
    Map<String, Object?> payload = const {},
    int? monotonicDurationSeconds,
  }) {
    if (playSessionId != sessionPayload['play_session_id']) {
      throw ArgumentError('Near/Far session ID mismatch');
    }
    final event = super.emit(
      playSessionId: playSessionId,
      type: type,
      payload: payload,
      monotonicDurationSeconds: monotonicDurationSeconds,
    );
    if (type == NearFarEventType.activityStarted && !_duration.isRunning) {
      _duration.start();
    }
    _pending.add(event);
    // Production writes must not generate uncaught async errors during gameplay.
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
      final parentOnly =
          event.eventType == NearFarEventType.missionFeedbackSubmitted.wireName;
      final durationBearing = event.eventType == NearFarEventType.activityCompleted.wireName ||
          event.eventType == NearFarEventType.activityAbandoned.wireName;
      await emitter.emit(
        eventType: event.eventType,
        consentScope: 'essential_play_events',
        payload: _canonicalPayload(event),
        source: parentOnly ? 'caregiver_report' : 'instrumented',
        emitter: parentOnly ? 'parent_dashboard' : 'kids_mode_client',
        playSessionId: parentOnly ? null : event.playSessionId,
        sessionPayload: parentOnly ? null : _sessionFor(event),
        durationSeconds: durationBearing
            ? (event.monotonicDurationSeconds ?? _duration.elapsed.inSeconds)
            : null,
      );
      _pending.removeAt(0);
    }
  }

  Map<String, dynamic> _sessionFor(NearFarActivityEvent event) {
    final copy = Map<String, dynamic>.from(sessionPayload);
    final finished = event.eventType == NearFarEventType.activityCompleted.wireName ||
        event.eventType == NearFarEventType.activityAbandoned.wireName;
    if (finished) {
      copy['ended_at'] = event.occurredAt.toUtc().toIso8601String();
      copy['completion_status'] =
          event.eventType == NearFarEventType.activityCompleted.wireName
              ? 'completed' : 'abandoned';
      copy['monotonic_duration_seconds'] =
          event.monotonicDurationSeconds ?? _duration.elapsed.inSeconds;
    }
    return copy;
  }

  Map<String, dynamic> _canonicalPayload(NearFarActivityEvent event) {
    final p = event.payload;
    switch (event.eventType) {
      case 'activity_started':
        return {
          'age_months': p['age_months'],
          if (p['restart'] == true) 'restart': true,
        };
      case 'activity_attempted':
        final raw = p['prompt'];
        return {
          'relation': p['relation'],
          'prompt': raw == 'makeNear' ? 'place_near' :
              raw == 'makeFar' ? 'place_far' : 'other',
        };
      case 'activity_hint_used':
        return {'hint_level': p['hint_level']};
      case 'activity_completed':
        return {'completion_status': 'completed', 'scoring': 'neutral'};
      case 'activity_abandoned':
        return {'completion_status': 'abandoned'};
      case 'real_world_mission_offered':
        return {
          'mission_id': p['mission_id'] ?? NearFarConstants.missionId,
          'mentor_card_id': NearFarConstants.mentorCardId,
          'material_codes': const ['sock', 'soft_toy'],
        };
      case 'real_world_mission_opened':
        return {
          'mission_id': p['mission_id'] ?? NearFarConstants.missionId,
          'mentor_card_id': NearFarConstants.mentorCardId,
        };
      case 'mission_feedback_submitted':
        return {
          'mission_id': p['mission_id'] ?? NearFarConstants.missionId,
          'status': p['status'] == 'tried_together' ? 'tried_together' : 'skipped',
          'proof_required': false,
        };
      default:
        throw ArgumentError('Near/Far production event type not mapped');
    }
  }
}
,
      caseSensitive: false,
    );
    if (!uuid.hasMatch(deviceId) || !uuid.hasMatch(contentVersionId) ||
        !uuid.hasMatch(sessionPayload['play_session_id']?.toString() ?? '') ||
        emitter.deviceId != deviceId ||
        emitter.contentVersionId != contentVersionId) {
      throw ArgumentError('production Near/Far identifiers must match emitter');
    }
    if (sessionPayload['schema_version'] != '1.0.0' ||
        sessionPayload['device_id'] != deviceId ||
        sessionPayload['content_version_id'] != contentVersionId ||
        sessionPayload['play_session_id'] is! String) {
      throw ArgumentError('production Near/Far session must be server-bound');
    }
  }

  final ActivityEventEmitter emitter;
  final Map<String, dynamic> sessionPayload;
  final List<NearFarActivityEvent> _pending = [];
  Future<void>? _draining;
  final Stopwatch _duration = Stopwatch();

  @override
  NearFarActivityEvent emit({
    required String playSessionId,
    required NearFarEventType type,
    Map<String, Object?> payload = const {},
    int? monotonicDurationSeconds,
  }) {
    if (playSessionId != sessionPayload['play_session_id']) {
      throw ArgumentError('Near/Far session ID mismatch');
    }
    final event = super.emit(
      playSessionId: playSessionId,
      type: type,
      payload: payload,
      monotonicDurationSeconds: monotonicDurationSeconds,
    );
    if (type == NearFarEventType.activityStarted && !_duration.isRunning) {
      _duration.start();
    }
    _pending.add(event);
    // Production writes must not generate uncaught async errors during gameplay.
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
      final parentOnly =
          event.eventType == NearFarEventType.missionFeedbackSubmitted.wireName;
      final durationBearing = event.eventType == NearFarEventType.activityCompleted.wireName ||
          event.eventType == NearFarEventType.activityAbandoned.wireName;
      await emitter.emit(
        eventType: event.eventType,
        consentScope: 'essential_play_events',
        payload: _canonicalPayload(event),
        source: parentOnly ? 'caregiver_report' : 'instrumented',
        emitter: parentOnly ? 'parent_dashboard' : 'kids_mode_client',
        playSessionId: parentOnly ? null : event.playSessionId,
        sessionPayload: parentOnly ? null : _sessionFor(event),
        durationSeconds: durationBearing
            ? (event.monotonicDurationSeconds ?? _duration.elapsed.inSeconds)
            : null,
      );
      _pending.removeAt(0);
    }
  }

  Map<String, dynamic> _sessionFor(NearFarActivityEvent event) {
    final copy = Map<String, dynamic>.from(sessionPayload);
    final finished = event.eventType == NearFarEventType.activityCompleted.wireName ||
        event.eventType == NearFarEventType.activityAbandoned.wireName;
    if (finished) {
      copy['ended_at'] = event.occurredAt.toUtc().toIso8601String();
      copy['completion_status'] =
          event.eventType == NearFarEventType.activityCompleted.wireName
              ? 'completed' : 'abandoned';
      copy['monotonic_duration_seconds'] =
          event.monotonicDurationSeconds ?? _duration.elapsed.inSeconds;
    }
    return copy;
  }

  Map<String, dynamic> _canonicalPayload(NearFarActivityEvent event) {
    final p = event.payload;
    switch (event.eventType) {
      case 'activity_started':
        return {
          'age_months': p['age_months'],
          if (p['restart'] == true) 'restart': true,
        };
      case 'activity_attempted':
        final raw = p['prompt'];
        return {
          'relation': p['relation'],
          'prompt': raw == 'makeNear' ? 'place_near' :
              raw == 'makeFar' ? 'place_far' : 'other',
        };
      case 'activity_hint_used':
        return {'hint_level': p['hint_level']};
      case 'activity_completed':
        return {'completion_status': 'completed', 'scoring': 'neutral'};
      case 'activity_abandoned':
        return {'completion_status': 'abandoned'};
      case 'real_world_mission_offered':
        return {
          'mission_id': p['mission_id'] ?? NearFarConstants.missionId,
          'mentor_card_id': NearFarConstants.mentorCardId,
          'material_codes': const ['sock', 'soft_toy'],
        };
      case 'real_world_mission_opened':
        return {
          'mission_id': p['mission_id'] ?? NearFarConstants.missionId,
          'mentor_card_id': NearFarConstants.mentorCardId,
        };
      case 'mission_feedback_submitted':
        return {
          'mission_id': p['mission_id'] ?? NearFarConstants.missionId,
          'status': p['status'] == 'tried_together' ? 'tried_together' : 'skipped',
          'proof_required': false,
        };
      default:
        throw ArgumentError('Near/Far production event type not mapped');
    }
  }
}

import 'package:uuid/uuid.dart';

import '../auth/auth_session.dart';
import 'activity_file_outbox.dart';

/// Builds a valid LMP-50 v1 envelope from instrumented activity events.
/// Unlike NearFarLocalEventBuffer, this never uploads fixture identifiers.
/// Parent/child IDs are deliberately absent; server derives ownership.
class ActivityEventEmitter {
  ActivityEventEmitter({
    required this.outbox,
    required this.session,
    required this.deviceId,
    required this.contentVersionId,
    required this.consentPolicyVersion,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now {
    for (final id in [deviceId, contentVersionId]) {
      if (!_id.hasMatch(id)) throw ArgumentError('expected UUID v4/v7');
    }
    if (consentPolicyVersion.isEmpty) {
      throw ArgumentError('missing consent policy');
    }
  }

  final ActivityFileOutbox outbox;
  final AuthSession session;
  final String deviceId;
  final String contentVersionId;
  final String consentPolicyVersion;
  final Uuid _uuid;
  final DateTime Function() _clock;
  static final _id = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[47][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static const childTypes = {
    'activity_started', 'activity_attempted', 'activity_hint_used',
    'activity_completed', 'activity_abandoned',
    'child_mode_foreground_started', 'child_mode_foreground_ended',
    'real_world_mission_offered', 'real_world_mission_opened',
    'screen_limit_reached', 'content_pack_downloaded',
  };
  static const parentTypes = {'mission_feedback_submitted', 'mentor_card_opened'};
  static const scopes = {
    'essential_play_events', 'essential_service_telemetry',
    'optional_product_analytics',
  };

  static const forbiddenKeys = {
    'parent_id', 'child_id', 'child_name', 'parent_name',
    'raw_touch', 'touch_path', 'coordinates', 'pointer_x', 'pointer_y',
    'photo', 'microphone', 'precise_location', 'advertising_id',
    'email', 'phone', 'token', 'access_token', 'refresh_token',
  };

  static bool _isSafe(dynamic value, {int depth = 0}) {
    if (depth > 3) return false;
    if (value is Map) {
      for (final item in value.entries) {
        if (item.key is! String) return false;
        final key = (item.key as String).toLowerCase();
        if (forbiddenKeys.contains(key) || key.contains('touch') ||
            key.contains('coordinate') || key.contains('pointer')) {
          return false;
        }
        if (!_isSafe(item.value, depth: depth + 1)) return false;
      }
      return true;
    }
    if (value is List) {
      return value.length <= 32 &&
          value.every((v) => _isSafe(v, depth: depth + 1));
    }
    return value == null || value is String || value is num || value is bool;
  }

  /// Returns a stable UUID only after the event is durably queued.
  /// It does not send HTTP, so playback is unaffected by network failures.
  Future<String> emit({
    required String eventType,
    required String consentScope,
    required Map<String, dynamic> payload,
    required String source,
    required String emitter,
    String? playSessionId,
    Map<String, dynamic>? sessionPayload,
    int? durationSeconds,
  }) async {
    final parentOnly = parentTypes.contains(eventType);
    if (!parentOnly && !childTypes.contains(eventType)) {
      throw ArgumentError('event type not allowlisted');
    }
    if (!scopes.contains(consentScope)) {
      throw ArgumentError('consent scope not allowlisted');
    }
    if ((parentOnly && playSessionId != null) ||
        (!parentOnly && (playSessionId == null || !_id.hasMatch(playSessionId)))) {
      throw ArgumentError('invalid play session relation');
    }
    if (!parentOnly && sessionPayload == null) {
      throw ArgumentError('child event requires session metadata');
    }
    if (parentOnly && sessionPayload != null) {
      throw ArgumentError('parent event cannot contain session metadata');
    }
    if (sessionPayload != null && !_isSafe(sessionPayload)) {
      throw ArgumentError('session contains forbidden fields');
    }
    if (parentOnly && emitter != 'parent_dashboard') {
      throw ArgumentError('parent event must be emitted from parent UI');
    }
    if (!parentOnly && emitter != 'kids_mode_client') {
      throw ArgumentError('child event must be emitted from kids mode');
    }
    if (parentOnly && source != 'caregiver_report' && eventType == 'mission_feedback_submitted') {
      throw ArgumentError('parent mission feedback requires caregiver report');
    }
    if (!_isSafe(payload)) throw ArgumentError('event contains forbidden fields');
    final id = _uuid.v4();
    final now = _clock().toUtc();
    final wire = <String, dynamic>{
      'schema_version': '1.0.0',
      'event_id': id,
      'event_type': eventType,
      'play_session_id': ?playSessionId,
      'device_id': deviceId,
      'content_version_id': contentVersionId,
      'occurred_at': now.toIso8601String().replaceFirst('+00:00', 'Z'),
      if (durationSeconds != null) 'monotonic_duration_seconds': durationSeconds,
      'consent_scope': consentScope,
      'consent_policy_version': consentPolicyVersion,
      'provenance': {
        'emitter': emitter,
        'actor_scope': parentOnly ? 'parent' : 'child_play',
        'source': source,
        'clock_trust': 'wall_clock_only',
      },
      'payload': payload,
    };
    await outbox.enqueue(PendingActivityEvent(
      parentId: session.parentId,
      eventId: id,
      payload: wire,
      sessionPayload: sessionPayload,
      createdAt: now,
    ));
    return id;
  }
}

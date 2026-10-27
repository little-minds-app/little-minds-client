import 'near_far_constants.dart';

/// Allowlisted Blueprint §14.1 event types used by the Near/Far local demo.
enum NearFarEventType {
  activityStarted('activity_started'),
  activityAttempted('activity_attempted'),
  activityHintUsed('activity_hint_used'),
  activityCompleted('activity_completed'),
  activityAbandoned('activity_abandoned'),
  realWorldMissionOffered('real_world_mission_offered'),
  realWorldMissionOpened('real_world_mission_opened'),
  /// Local fixture for optional skip / tried-together (Blueprint §14 parent
  /// feedback name). No production upload (LMP-50); no photo proof.
  missionFeedbackSubmitted('mission_feedback_submitted');

  const NearFarEventType(this.wireName);
  final String wireName;

  static const Set<String> allowlist = {
    'activity_started',
    'activity_attempted',
    'activity_hint_used',
    'activity_completed',
    'activity_abandoned',
    'child_mode_foreground_started',
    'child_mode_foreground_ended',
    'real_world_mission_offered',
    'real_world_mission_opened',
    'mission_feedback_submitted',
    'mentor_card_opened',
    'screen_limit_reached',
    'content_pack_downloaded',
  };

  static bool isAllowlisted(String eventType) => allowlist.contains(eventType);
}

/// Local-only versioned activity event envelope (Blueprint §14 / §38.4).
///
/// **Not** production Nest ingestion (LMP-50). No child PII, no raw touch
/// coordinates, no network upload from this fixture buffer.
class NearFarActivityEvent {
  NearFarActivityEvent({
    required this.eventId,
    required this.eventType,
    required this.playSessionId,
    required this.deviceId,
    required this.contentVersionId,
    required this.occurredAt,
    required this.payload,
    this.schemaVersion = NearFarConstants.eventSchemaVersion,
    this.monotonicDurationSeconds,
  });

  final String eventId;
  final int schemaVersion;
  final String eventType;
  final String playSessionId;
  final String deviceId;
  final String contentVersionId;
  final DateTime occurredAt;
  final Map<String, Object?> payload;
  final int? monotonicDurationSeconds;

  Map<String, Object?> toJson() => {
        'event_id': eventId,
        'schema_version': schemaVersion,
        'event_type': eventType,
        'play_session_id': playSessionId,
        'device_id': deviceId,
        'content_version_id': contentVersionId,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        if (monotonicDurationSeconds != null)
          'monotonic_duration_seconds': monotonicDurationSeconds,
        'payload': payload,
      };
}

/// Forbidden payload keys for local fixture validation (ADR-017 / §14).
abstract final class NearFarEventPrivacy {
  static const forbiddenPayloadKeys = {
    'child_id',
    'child_name',
    'raw_touch',
    'touch_path',
    'coordinates',
    'pointer_x',
    'pointer_y',
    'photo',
    'microphone',
    'precise_location',
    'advertising_id',
  };

  static bool payloadLooksSafe(Map<String, Object?> payload) {
    for (final key in payload.keys) {
      final lower = key.toLowerCase();
      if (forbiddenPayloadKeys.contains(lower)) {
        return false;
      }
      if (lower.contains('touch') ||
          lower.contains('coord') ||
          lower.contains('pointer')) {
        return false;
      }
    }
    return true;
  }
}

/// In-memory offline event buffer for the Near/Far demo (no telemetry upload).
class NearFarLocalEventBuffer {
  NearFarLocalEventBuffer({
    this.deviceId = 'local-demo-device',
    this.contentVersionId = NearFarConstants.contentVersionId,
    String Function()? idFactory,
    DateTime Function()? clock,
  })  : _idFactory = idFactory ?? _defaultId,
        _clock = clock ?? DateTime.now;

  final String deviceId;
  final String contentVersionId;
  final String Function() _idFactory;
  final DateTime Function() _clock;
  final List<NearFarActivityEvent> _events = <NearFarActivityEvent>[];
  var _seq = 0;

  List<NearFarActivityEvent> get events =>
      List<NearFarActivityEvent>.unmodifiable(_events);

  /// Emits an allowlisted event or throws [ArgumentError] for unknown types /
  /// unsafe payloads. Never invents schemas beyond Blueprint §14 names.
  NearFarActivityEvent emit({
    required String playSessionId,
    required NearFarEventType type,
    Map<String, Object?> payload = const {},
    int? monotonicDurationSeconds,
  }) {
    if (!NearFarEventType.isAllowlisted(type.wireName)) {
      throw ArgumentError.value(type.wireName, 'eventType', 'not allowlisted');
    }
    if (!NearFarEventPrivacy.payloadLooksSafe(payload)) {
      throw ArgumentError('payload contains forbidden fields');
    }
    final event = NearFarActivityEvent(
      eventId: _idFactory(),
      eventType: type.wireName,
      playSessionId: playSessionId,
      deviceId: deviceId,
      contentVersionId: contentVersionId,
      occurredAt: _clock().toUtc(),
      payload: Map<String, Object?>.unmodifiable(payload),
      monotonicDurationSeconds: monotonicDurationSeconds,
    );
    _events.add(event);
    return event;
  }

  void clear() => _events.clear();

  static String _defaultId() {
    // Local fixture ids — not cryptographic; stable-enough for offline buffer.
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'nf-local-${stamp.toRadixString(16)}';
  }

  /// Test helper with deterministic ids.
  String nextDeterministicId() => 'nf-test-${_seq++}';
}

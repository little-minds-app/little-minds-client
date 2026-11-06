import 'color_sorting_constants.dart';

enum ColorSortingEventType {
  activityStarted('activity_started'),
  activityAttempted('activity_attempted'),
  activityHintUsed('activity_hint_used'),
  activityCompleted('activity_completed'),
  activityAbandoned('activity_abandoned');

  const ColorSortingEventType(this.wireName);
  final String wireName;

  static const Set<String> allowlist = {
    'activity_started',
    'activity_attempted',
    'activity_hint_used',
    'activity_completed',
    'activity_abandoned',
    'child_mode_foreground_started',
    'child_mode_foreground_ended',
    'screen_limit_reached',
    'content_pack_downloaded',
  };

  static bool isAllowlisted(String eventType) => allowlist.contains(eventType);
}

class ColorSortingActivityEvent {
  ColorSortingActivityEvent({
    required this.eventId,
    required this.eventType,
    required this.playSessionId,
    required this.deviceId,
    required this.contentVersionId,
    required this.occurredAt,
    required this.payload,
    this.schemaVersion = ColorSortingConstants.eventSchemaVersion,
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

abstract final class ColorSortingEventPrivacy {
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

/// In-memory offline event buffer (no network upload).
class ColorSortingLocalEventBuffer {
  ColorSortingLocalEventBuffer({
    this.deviceId = 'local-demo-device',
    this.contentVersionId = ColorSortingConstants.contentVersionId,
    String Function()? idFactory,
    DateTime Function()? clock,
  })  : _idFactory = idFactory ?? _defaultId,
        _clock = clock ?? DateTime.now;

  final String deviceId;
  final String contentVersionId;
  final String Function() _idFactory;
  final DateTime Function() _clock;

  final List<ColorSortingActivityEvent> events = [];

  static String _defaultId() =>
      'evt-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  ColorSortingActivityEvent emit({
    required String playSessionId,
    required ColorSortingEventType type,
    Map<String, Object?> payload = const {},
    int? monotonicDurationSeconds,
  }) {
    if (!ColorSortingEventPrivacy.payloadLooksSafe(payload)) {
      throw ArgumentError('event payload contains forbidden fields');
    }
    if (!ColorSortingEventType.isAllowlisted(type.wireName)) {
      throw ArgumentError('event type not allowlisted');
    }
    final event = ColorSortingActivityEvent(
      eventId: _idFactory(),
      eventType: type.wireName,
      playSessionId: playSessionId,
      deviceId: deviceId,
      contentVersionId: contentVersionId,
      occurredAt: _clock(),
      payload: payload,
      monotonicDurationSeconds: monotonicDurationSeconds,
    );
    events.add(event);
    return event;
  }
}

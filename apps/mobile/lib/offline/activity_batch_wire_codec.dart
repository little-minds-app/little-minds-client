import 'package:little_minds_api/api.dart';

/// JSON-serializable LMP-51 batch body from pinned OpenAPI models.
///
/// [IngestActivityEventBatchRequest.toJson] leaves nested model instances in the
/// map; [jsonEncode] cannot encode those directly when sessions are present.
Map<String, dynamic> encodeActivityBatchWire(
  IngestActivityEventBatchRequest request,
) {
  return <String, dynamic>{
    'sessions': request.sessions.map(_encodeSessionWire).toList(),
    'events': request.events.map(_encodeEventWire).toList(),
  };
}

Map<String, dynamic> _encodeSessionWire(ActivitySessionV1 session) {
  final json = session.toJson().map(
    (key, value) => MapEntry(key, _encodeWireValue(value)),
  );
  json.removeWhere(
    (key, value) =>
        value == null &&
        (key == 'ended_at' ||
            key == 'monotonic_duration_seconds' ||
            key == 'app_build' ||
            key == 'locale'),
  );
  return json;
}

Map<String, dynamic> _encodeEventWire(ActivityEventV1 event) {
  final json = event.toJson().map(
    (key, value) => MapEntry(key, _encodeWireValue(value)),
  );
  json.removeWhere(
    (key, value) =>
        value == null &&
        (key == 'play_session_id' || key == 'monotonic_duration_seconds'),
  );
  return json;
}

Object? _encodeWireValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, nested) => MapEntry(key, _encodeWireValue(nested)),
    );
  }
  if (value is List) {
    return value.map(_encodeWireValue).toList();
  }
  final encoded = (value as dynamic).toJson();
  if (encoded is Map) {
    return encoded.map(
      (key, nested) => MapEntry(key, _encodeWireValue(nested)),
    );
  }
  return encoded;
}

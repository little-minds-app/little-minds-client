import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Immutable, account-bound record. No tokens or child PII are persisted.
class PendingActivityEvent {
  const PendingActivityEvent({
    required this.parentId,
    required this.eventId,
    required this.payload,
    this.sessionPayload,
    required this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final String parentId;
  final String eventId;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? sessionPayload;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextAttemptAt;

  PendingActivityEvent retryAfter(DateTime instant) => PendingActivityEvent(
    parentId: parentId,
    eventId: eventId,
    payload: payload,
    sessionPayload: sessionPayload,
    createdAt: createdAt,
    attempts: attempts + 1,
    nextAttemptAt: instant,
  );

  Map<String, dynamic> toJson() => {
    'parent_id': parentId,
    'event_id': eventId,
    'payload': payload,
    if (sessionPayload != null) 'session_payload': sessionPayload,
    'created_at': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
    if (nextAttemptAt != null)
      'next_attempt_at': nextAttemptAt!.toUtc().toIso8601String(),
  };

  factory PendingActivityEvent.fromJson(Map<String, dynamic> json) {
    return PendingActivityEvent(
      parentId: json['parent_id'] as String,
      eventId: json['event_id'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      sessionPayload: json['session_payload'] == null ? null :
          Map<String, dynamic>.from(json['session_payload'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      attempts: json['attempts'] as int? ?? 0,
      nextAttemptAt: json['next_attempt_at'] == null
          ? null
          : DateTime.parse(json['next_attempt_at'] as String).toUtc(),
    );
  }
}

/// Crash-resilient file outbox, using one atomic rename per record.
/// No in-memory-only ACK or "in flight" deletion: a lost HTTP ACK replays
/// the same UUID after a restart. Each record is isolated by parent account.
///
/// Scope: mobile platforms with atomic same-volume rename. This is a durable
/// initial outbox implementation, NOT a SQLite multi-record transaction.
/// A production quota/retention policy and encrypted storage require review.
class ActivityFileOutbox {
  // ignore: prefer_initializing_formals
  ActivityFileOutbox({required Directory root}) : _root = root;

  factory ActivityFileOutbox.forTesting(Directory root) =>
      ActivityFileOutbox(root: root);

  static Future<ActivityFileOutbox> open() async {
    final directory = await getApplicationSupportDirectory();
    return ActivityFileOutbox(
      root: Directory('${directory.path}/activity_outbox_v1'),
    );
  }

  final Directory _root;
  /// Safety caps: exceed -> visible storage error; never silently drop a child event.
  static const maxRecordsPerParent = 2000;
  static const maxEventBytes = 16384;
  Future<void> _tail = Future<void>.value();

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[47][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  // Serializes local read-modify-write operations within one outbox instance.
  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    await previous;
    try {
      return await operation();
    } finally {
      gate.complete();
    }
  }

  Directory _partition(String parentId) {
    if (!_uuid.hasMatch(parentId)) throw ArgumentError('invalid parent ID');
    return Directory('${_root.path}/${parentId.toLowerCase()}');
  }

  File _entry(String parentId, String eventId) {
    if (!_uuid.hasMatch(eventId)) throw ArgumentError('invalid event ID');
    return File('${_partition(parentId).path}/${eventId.toLowerCase()}.json');
  }

  Future<void> enqueue(PendingActivityEvent event) => _serialized(() async {
    if (event.payload['event_id'] != event.eventId ||
        event.payload['schema_version'] != '1.0.0' ||
        event.payload.containsKey('child_id') ||
        event.payload.containsKey('parent_id') ||
        event.payload.containsKey('received_at')) {
      throw ArgumentError('event is not valid for offline persistence');
    }
    final session = event.sessionPayload;
    if (event.payload['play_session_id'] != null) {
      if (session == null ||
          session['play_session_id'] != event.payload['play_session_id'] ||
          session['device_id'] != event.payload['device_id'] ||
          session['content_version_id'] != event.payload['content_version_id'] ||
          session['schema_version'] != '1.0.0' ||
          session.containsKey('child_id') ||
          session.containsKey('parent_id')) {
        throw ArgumentError('child event requires matching session envelope');
      }
    } else if (session != null) {
      throw ArgumentError('parent-only event must not include session');
    }
    final file = _entry(event.parentId, event.eventId);
    final bytes = utf8.encode(jsonEncode(event.toJson())).length;
    if (bytes > maxEventBytes) throw StateError('outbox.event_too_large');
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      final existing = PendingActivityEvent.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      if (jsonEncode(existing.payload) != jsonEncode(event.payload) ||
          jsonEncode(existing.sessionPayload) != jsonEncode(event.sessionPayload)) {
        throw StateError('same event ID has different content');
      }
      return; // Never reset retry metadata on accidental re-enqueue.
    }
    final existing = await file.parent.list(followLinks: false).toList();
    if (existing.whereType<File>().where((f) => f.path.endsWith('.json')).length >=
        maxRecordsPerParent) {
      throw StateError('outbox.capacity_exceeded');
    }
    await _atomicWrite(file, event.toJson());
  });

  Future<List<PendingActivityEvent>> pending(
    String parentId, {
    DateTime? now,
    int limit = 50,
  }) => _serialized(() async {
    if (limit < 1 || limit > 50) throw RangeError.range(limit, 1, 50);
    final dir = _partition(parentId);
    if (!await dir.exists()) return <PendingActivityEvent>[];
    final result = <PendingActivityEvent>[];
    final files = (await dir.list(followLinks: false).toList())
      .whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final event = PendingActivityEvent.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      if (event.parentId != parentId ||
          event.eventId.toLowerCase() != file.uri.pathSegments.last.replaceFirst('.json', '')) {
        throw StateError('outbox account binding corrupted');
      }
      if (event.nextAttemptAt == null ||
          !event.nextAttemptAt!.isAfter(now ?? DateTime.now().toUtc())) {
        result.add(event);
        if (result.length == limit) break;
      }
    }
    return result;
  });

  Future<void> acknowledge(String parentId, String eventId) =>
      _serialized(() async {
        final file = _entry(parentId, eventId);
        if (await file.exists()) await file.delete();
      });

  Future<void> postpone(
    PendingActivityEvent event,
    DateTime nextAttemptAt,
  ) => _serialized(() async {
    final file = _entry(event.parentId, event.eventId);
    if (!await file.exists()) return;
    final current = PendingActivityEvent.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    if (current.parentId != event.parentId) throw StateError('account mismatch');
    await _atomicWrite(file, current.retryAfter(nextAttemptAt).toJson());
  });

  Future<void> purgePartition(String parentId) => _serialized(() async {
    final dir = _partition(parentId);
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> _atomicWrite(File destination, Map<String, dynamic> value) async {
    final temp = File('${destination.path}.${const Uuid().v4()}.tmp');
    try {
      await temp.writeAsString(jsonEncode(value), flush: true);
      await temp.rename(destination.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}

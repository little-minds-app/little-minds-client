import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/canonical_rfc4122_uuid.dart';

import 'activity_payload_codec.dart';

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
/// Production uses AES-GCM ciphertext with a Keychain/Keystore managed key.
typedef ActivityOutboxPersistedHook = void Function(int partitionPendingHint);

class ActivityFileOutbox {
  ActivityFileOutbox._(this._root, this._codec);

  factory ActivityFileOutbox.forTesting(
    Directory root, {
    ActivityPayloadCodec codec = const TestPlainActivityPayloadCodec(),
    ActivityOutboxPersistedHook? onEventPersisted,
  }) =>
      ActivityFileOutbox._(root, codec)..onEventPersisted = onEventPersisted;

  static Future<ActivityFileOutbox> open() async {
    final directory = await getApplicationSupportDirectory();
    return ActivityFileOutbox._(
      Directory('${directory.path}/activity_outbox_v1'),
      SecureActivityPayloadCodec(),
    );
  }

  final Directory _root;
  final ActivityPayloadCodec _codec;

  /// Invoked after a new event record is atomically persisted (not on dedupe hits).
  ActivityOutboxPersistedHook? onEventPersisted;

  /// Hard per-parent outbox limits (encrypted bytes on disk, including quarantine).
  /// At quota, evict oldest COMPLETE session as a unit; never evict an active
  /// session or a session whose events are reserved by an in-flight batch.
  static const maxRecordsPerParent = 500;
  static const maxPartitionBytes = 5 * 1024 * 1024;
  static const maxEventBytes = 16384;
  final Set<String> _reservedEventIds = <String>{};
  int droppedEventsAtCapacity = 0;
  int droppedSessionsAtCapacity = 0;
  Future<void> _tail = Future<void>.value();

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
    if (!CanonicalRfc4122Uuid.isValid(parentId)) {
      throw ArgumentError('invalid parent ID');
    }
    return Directory('${_root.path}/${parentId.toLowerCase()}');
  }

  File _entry(String parentId, String eventId) {
    if (!CanonicalRfc4122Uuid.isValid(eventId)) {
      throw ArgumentError('invalid event ID');
    }
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
        await _codec.open(event.parentId, await file.readAsString()));
      if (jsonEncode(existing.payload) != jsonEncode(event.payload) ||
          jsonEncode(existing.sessionPayload) != jsonEncode(event.sessionPayload)) {
        throw StateError('same event ID has different content');
      }
      return; // Never reset retry metadata on accidental re-enqueue.
    }
    // Seal once so quota measures the actual encrypted bytes on disk.
    final sealed = await _codec.seal(event.parentId, event.toJson());
    await _makeSpaceFor(event.parentId, utf8.encode(sealed).length);
    await _atomicWriteSealed(file, sealed);
    final hook = onEventPersisted;
    if (hook != null) {
      final files = await file.parent
          .list(followLinks: false)
          .where((e) => e is File && e.path.endsWith('.json'))
          .length;
      hook(files);
    }
  });

  Future<List<PendingActivityEvent>> pending(
    String parentId, {
    DateTime? now,
    int limit = 50,
    bool reserve = false,
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
        await _codec.open(parentId, await file.readAsString()));
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
    if (reserve) {
      _reservedEventIds.addAll(result.map((e) => e.eventId));
    }
    return result;
  });

  /// Ends the lease established for an HTTP batch; safe even after ACK/deletion.
  Future<void> releaseReserved(List<PendingActivityEvent> events) =>
      _serialized(() async {
        _reservedEventIds.removeAll(events.map((e) => e.eventId));
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
      await _codec.open(event.parentId, await file.readAsString()));
    if (current.parentId != event.parentId) throw StateError('account mismatch');
    await _atomicWrite(file, current.retryAfter(nextAttemptAt).toJson());
  });

  /// Permanently rejected events are retained for explicit diagnostics or
  /// deletion, but never automatically resent after a server rejection.
  Future<void> quarantine(
    String parentId,
    String eventId,
    String reasonCode,
  ) => _serialized(() async {
    final safeReason = RegExp(r'^[a-z0-9_.-]{1,100}$');
    if (!safeReason.hasMatch(reasonCode)) {
      throw ArgumentError('invalid rejection reason');
    }
    final file = _entry(parentId, eventId);
    if (!await file.exists()) return;
    final rejected = File(
      '${file.parent.path}/${eventId.toLowerCase()}.json.rejected',
    );
    if (await rejected.exists()) {
      throw StateError('quarantine destination already exists');
    }
    // Same-volume rename to *.json.rejected can fail with EINVAL on some
    // platforms; copy-then-delete preserves the sealed bytes without loss.
    await rejected.writeAsBytes(await file.readAsBytes(), flush: true);
    await file.delete();
  });

  /// Re-enqueue quarantined events for a consent scope without touching
  /// `*.json.rejected` archives (copy-then-enqueue). Skips when the same
  /// [event_id] is already pending. Safe to call after server grant (LMP-134).
  Future<int> requeueQuarantinedConsentScope(
    String parentId,
    String scope,
  ) =>
      _serialized(() async {
        final dir = _partition(parentId);
        if (!await dir.exists()) return 0;
        final pendingIds = <String>{};
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.json')) {
            continue;
          }
          final data = PendingActivityEvent.fromJson(
            await _codec.open(parentId, await entity.readAsString()),
          );
          pendingIds.add(data.eventId.toLowerCase());
        }
        var requeued = 0;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.json.rejected')) {
            continue;
          }
          final data = PendingActivityEvent.fromJson(
            await _codec.open(parentId, await entity.readAsString()),
          );
          if (data.parentId != parentId ||
              data.payload['consent_scope'] != scope) {
            continue;
          }
          final id = data.eventId.toLowerCase();
          if (pendingIds.contains(id)) {
            continue;
          }
          final destination = _entry(parentId, data.eventId);
          if (await destination.exists()) {
            pendingIds.add(id);
            continue;
          }
          final fresh = PendingActivityEvent(
            parentId: data.parentId,
            eventId: data.eventId,
            payload: data.payload,
            sessionPayload: data.sessionPayload,
            createdAt: data.createdAt,
          );
          await _atomicWrite(destination, fresh.toJson());
          pendingIds.add(id);
          requeued++;
          onEventPersisted?.call(pendingIds.length);
        }
        return requeued;
      });

  /// Purge unacknowledged optional analytics when consent is withdrawn.
  Future<int> purgeConsentScope(String parentId, String scope) =>
      _serialized(() async {
        final dir = _partition(parentId);
        if (!await dir.exists()) return 0;
        var removed = 0;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.json')) {
            continue;
          }
          final data = PendingActivityEvent.fromJson(
            await _codec.open(parentId, await entity.readAsString()));
          if (data.parentId == parentId &&
              data.payload['consent_scope'] == scope) {
            await entity.delete();
            removed++;
          }
        }
        return removed;
      });

  /// Apply an explicit policy cutoff to quarantined records. Does not touch
  /// active essential events, and does not invent a retention deadline.
  Future<int> purgeQuarantineBefore(String parentId, DateTime cutoff) =>
      _serialized(() async {
        final dir = _partition(parentId);
        if (!await dir.exists()) return 0;
        var removed = 0;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.json.rejected')) {
            continue;
          }
          final modified = (await entity.stat()).modified.toUtc();
          if (modified.isBefore(cutoff.toUtc())) {
            await entity.delete();
            removed++;
          }
        }
        return removed;
      });

  Future<void> purgePartition(String parentId) => _serialized(() async {
    final dir = _partition(parentId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _codec.forgetParent(parentId);
  });

  Future<void> _makeSpaceFor(String parentId, int incomingBytes) async {
    if (incomingBytes > maxPartitionBytes) {
      throw StateError('outbox.event_too_large');
    }
    final dir = _partition(parentId);
    final files = (await dir.list(followLinks: false).toList())
        .whereType<File>().toList();
    final active = files.where((f) => f.path.endsWith('.json')).toList();
    final quarantine = files.where((f) => f.path.endsWith('.json.rejected')).toList();
    var used = 0;
    for (final file in [...active, ...quarantine]) {
      used += await file.length();
    }
    if (active.length < maxRecordsPerParent &&
        used + incomingBytes <= maxPartitionBytes) return;

    // Old quarantined records have no retry path until explicit user action.
    // Remove them before risking unsent telemetry, keeping storage bounded.
    quarantine.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    for (final file in quarantine) {
      if (active.length < maxRecordsPerParent &&
          used + incomingBytes <= maxPartitionBytes) break;
      final size = await file.length();
      await file.delete();
      used -= size;
    }

    final groups = <String, List<({File file, PendingActivityEvent item, int size})>>{};
    for (final file in active) {
      final item = PendingActivityEvent.fromJson(
          await _codec.open(parentId, await file.readAsString()));
      if (item.parentId != parentId) throw StateError('outbox account binding corrupted');
      final sessionId = item.payload['play_session_id'];
      final groupId = sessionId is String ? sessionId : 'event:${item.eventId}';
      groups.putIfAbsent(groupId, () => []).add(
          (file: file, item: item, size: await file.length()));
    }
    final candidates = groups.entries.where((group) {
      final items = group.value;
      if (items.any((row) => _reservedEventIds.contains(row.item.eventId))) return false;
      if (group.key.startsWith('event:')) return true;
      return items.any((row) =>
          row.item.payload['event_type'] == 'activity_completed' ||
          row.item.payload['event_type'] == 'activity_abandoned');
    }).toList()..sort((a, b) {
      DateTime oldest(List<({File file, PendingActivityEvent item, int size})> entries) =>
          entries.map((e) => e.item.createdAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
      return oldest(a.value).compareTo(oldest(b.value));
    });
    var remaining = active.length;
    for (final group in candidates) {
      if (remaining < maxRecordsPerParent &&
          used + incomingBytes <= maxPartitionBytes) break;
      for (final row in group.value) {
        await row.file.delete();
        used -= row.size;
        remaining--;
        droppedEventsAtCapacity++;
      }
      droppedSessionsAtCapacity++;
    }
    // If only active/in-flight sessions remain, refuse to lose half a session.
    if (remaining >= maxRecordsPerParent ||
        used + incomingBytes > maxPartitionBytes) {
      throw StateError('outbox.capacity_exceeded');
    }
  }

  Future<void> _atomicWriteSealed(File destination, String sealed) async {
    final temp = File('${destination.path}.${const Uuid().v4()}.tmp');
    try {
      await temp.writeAsString(sealed, flush: true);
      await temp.rename(destination.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<void> _atomicWrite(File destination, Map<String, dynamic> value) async {
    final parentId = destination.parent.uri.pathSegments.where((x) => x.isNotEmpty).last;
    await _atomicWriteSealed(destination, await _codec.seal(parentId, value));
  }
}

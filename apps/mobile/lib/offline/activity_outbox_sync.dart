import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:little_minds_api/api.dart';

import '../auth/auth_session.dart';
import 'activity_file_outbox.dart';

typedef EventBatchSender = Future<Map<String, dynamic>> Function(
  AuthSession session, List<Map<String, dynamic>> events,
  List<Map<String, dynamic>> sessions);

/// Uses the LMP-51 API wire contract. Auth token stays only in request header.
class ActivityHttpBatchSender {
  ActivityHttpBatchSender({required Uri apiBaseUrl, HttpClient? client})
      : _endpoint = apiBaseUrl.resolve('/v1/events/batch'),
        _client = client ?? HttpClient();
  final Uri _endpoint;
  final HttpClient _client;

  Future<Map<String, dynamic>> send(
    AuthSession session,
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> sessions,
  ) async {
    // Parse through the pinned generated OpenAPI models, not an independent
    // hand-maintained envelope. Preserve the HTTP transport for Retry-After.
    final typedSessions = <ActivitySessionV1>[];
    final typedEvents = <ActivityEventV1>[];
    for (final json in sessions) {
      final parsed = ActivitySessionV1.fromJson(json);
      if (parsed == null) throw const FormatException('batch.invalid_session');
      typedSessions.add(parsed);
    }
    for (final json in events) {
      final parsed = ActivityEventV1.fromJson(json);
      if (parsed == null) throw const FormatException('batch.invalid_event');
      typedEvents.add(parsed);
    }
    final request = IngestActivityEventBatchRequest(
        sessions: typedSessions, events: typedEvents);
    final encoded = utf8.encode(jsonEncode(request.toJson()));
    if (encoded.length > 256 * 1024) {
      throw const ActivityRequestTooLarge();
    }
    final req = await _client.postUrl(_endpoint).timeout(
      const Duration(seconds: 15));
    req.headers.contentType = ContentType.json;
    req.headers.set(HttpHeaders.authorizationHeader,
        'Bearer ${session.accessToken}');
    req.add(encoded);
    final response = await req.close().timeout(const Duration(seconds: 20));
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode == 200) {
      final body = jsonDecode(responseBody);
      if (body is! Map<String, dynamic> || body['results'] is! List) {
        throw const FormatException('batch.invalid_response');
      }
      // Fail closed on a response that no longer conforms to the pinned
      // generated batch acknowledgment schema.
      final typedAck = IngestActivityEventBatch200Response.fromJson(body);
      if (typedAck == null) {
        throw const FormatException('batch.invalid_response');
      }
      return body;
    }
    if (response.statusCode == 401) throw const ActivityAuthExpired();
    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw ActivityRetryableHttp(response.statusCode,
          retryAfter: parseActivityRetryAfter(
              response.headers.value('retry-after')));
    }
    throw ActivityPermanentHttp(response.statusCode);
  }
}

/// RFC 9110 Retry-After supports delta-seconds and an HTTP-date.
Duration? parseActivityRetryAfter(String? value, {DateTime? now}) {
  if (value == null) return null;
  final seconds = int.tryParse(value.trim());
  if (seconds != null) {
    return Duration(seconds: seconds.clamp(1, 3600));
  }
  try {
    final until = HttpDate.parse(value).toUtc();
    final remaining = until.difference((now ?? DateTime.now()).toUtc());
    if (remaining <= Duration.zero) return const Duration(seconds: 1);
    return remaining > const Duration(hours: 1)
        ? const Duration(hours: 1) : remaining;
  } on FormatException {
    return null;
  }
}

class ActivityAuthExpired implements Exception {
  const ActivityAuthExpired();
}
class ActivityRetryableHttp implements Exception {
  const ActivityRetryableHttp(this.status, {this.retryAfter});
  final int status;
  final Duration? retryAfter;
}
class ActivityRequestTooLarge implements Exception {
  const ActivityRequestTooLarge();
}
class ActivityPermanentHttp implements Exception {
  const ActivityPermanentHttp(this.status);
  final int status;
}

/// Avoids overlapping flushes; each call acts only on the currently signed-in
/// parent's partition. No processing on logout, expiry or parent switch.
class ActivityOutboxSync {
  ActivityOutboxSync({
    required this.outbox,
    required this.send,
    required this.currentSession,
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final ActivityFileOutbox outbox;
  final EventBatchSender send;
  final AuthSession? Function() currentSession;
  final DateTime Function() _clock;
  final Random _random;
  bool _running = false;

  Future<void> flush() async {
    if (_running) return;
    final initial = currentSession();
    if (initial == null) return;
    _running = true;
    try {
      // Each persisted record is capped at 16 KiB (including its session).
      // Twelve records plus the batch envelope fit under the 256 KiB cap.
      // A bounded prefix avoids one oversized batch blocking the entire queue.
      final pending = await outbox.pending(initial.parentId,
          now: _clock().toUtc(), limit: 12);
      if (pending.isEmpty) return;
      if (!_sameAccount(initial)) return;
      Map<String, dynamic> result;
      try {
        final uniqueSessions = <String, Map<String, dynamic>>{};
        for (final item in pending) {
          if (item.sessionPayload != null) {
            final sessionId = item.sessionPayload!['play_session_id'];
            if (sessionId is! String) {
              return;
            }
            // Prefer the terminal metadata if the same session was completed.
            if (!uniqueSessions.containsKey(sessionId) ||
                item.sessionPayload!['ended_at'] != null) {
              uniqueSessions[sessionId] = item.sessionPayload!;
            }
          }
        }
        result = await send(initial, pending.map((e) => e.payload).toList(),
            uniqueSessions.values.toList());
      } on ActivityAuthExpired {
        // No token refresh inside worker; caller must reauthenticate first.
        return;
      } on ActivityRequestTooLarge {
        // Retain safely; batch split policy is a separate contract decision.
        return;
      } on ActivityRetryableHttp catch (error) {
        if (!_sameAccount(initial)) return;
        for (final item in pending) {
          await outbox.postpone(item, error.retryAfter == null
              ? _nextRetry(item.attempts)
              : _clock().toUtc().add(error.retryAfter!));
        }
        return;
      } on ActivityPermanentHttp {
        // Do not delete or silently lose events for ambiguous batch failures.
        return;
      } catch (_) {
        if (!_sameAccount(initial)) return;
        for (final item in pending) {
          await outbox.postpone(item, _nextRetry(item.attempts));
        }
        return;
      }
      if (!_sameAccount(initial)) return;
      final rows = result['results'];
      if (rows is! List) {
        return;
      }
      final acked = <String, ({String status, String? reason})>{};
      for (final entry in rows) {
        if (entry is! Map || entry['event_id'] is! String ||
            entry['status'] is! String) {
          return;
        }
        final id = entry['event_id'] as String;
        if (acked.containsKey(id)) {
          return;
        }
        acked[id] = (status: entry['status'] as String,
            reason: entry['reason_code'] as String?);
      }
      // Validate the full ACK before acknowledging any record.
      if (acked.length != pending.length ||
          pending.any((e) => !acked.containsKey(e.eventId)) ||
          acked.values.any((v) => !{
            'accepted', 'duplicate_noop', 'rejected', 'retryable'
          }.contains(v.status))) {
        return;
      }
      for (final item in pending) {
        if (!_sameAccount(initial)) return;
        final ack = acked[item.eventId]!;
        if (ack.status == 'accepted' || ack.status == 'duplicate_noop') {
          await outbox.acknowledge(initial.parentId, item.eventId);
        } else if (ack.status == 'rejected') {
          if (ack.reason == 'consent.not_authorized' &&
              item.payload['consent_scope'] == 'optional_product_analytics') {
            await outbox.acknowledge(initial.parentId, item.eventId);
          } else {
            await outbox.quarantine(initial.parentId, item.eventId,
                ack.reason ?? 'server.rejected');
          }
        } else {
          await outbox.postpone(item, _nextRetry(item.attempts));
        }
      }
    } finally {
      _running = false;
    }
  }

  bool _sameAccount(AuthSession original) {
    final active = currentSession();
    return active != null && active.parentId == original.parentId &&
        active.sessionId == original.sessionId;
  }

  DateTime _nextRetry(int attempts) {
    final capped = min(attempts, 8);
    final maximum = min(300, 2 * (1 << capped));
    return _clock().toUtc().add(
      Duration(milliseconds: 1000 + _random.nextInt(maximum * 1000)));
  }
}

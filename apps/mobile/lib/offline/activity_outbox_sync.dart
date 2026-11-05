import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:little_minds_api/api.dart';

import '../auth/auth_session.dart';
import 'activity_batch_http_error.dart';
import 'activity_batch_wire_codec.dart';
import 'activity_event_outbox_wire_repair.dart';
import 'activity_file_outbox.dart';
import 'activity_telemetry_diagnostics.dart';

typedef EventBatchSender = Future<Map<String, dynamic>> Function(
  AuthSession session,
  List<Map<String, dynamic>> events,
  List<Map<String, dynamic>> sessions,
);

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
    for (final raw in events) {
      final json = repairActivityEventOutboxWire(
        Map<String, dynamic>.from(raw),
      );
      final parsed = ActivityEventV1.fromJson(json);
      if (parsed == null) throw const FormatException('batch.invalid_event');
      typedEvents.add(parsed);
    }
    final request = IngestActivityEventBatchRequest(
      sessions: typedSessions,
      events: typedEvents,
    );
    late final Map<String, dynamic> wire;
    try {
      wire = encodeActivityBatchWire(request);
    } on FormatException {
      ActivityTelemetryDiagnostics.batchSerializeFailed('model_parse');
      rethrow;
    } catch (_) {
      ActivityTelemetryDiagnostics.batchSerializeFailed('wire_build');
      throw const FormatException('batch.wire_encode');
    }
    late final List<int> encoded;
    try {
      encoded = utf8.encode(jsonEncode(wire));
    } on JsonUnsupportedObjectError {
      ActivityTelemetryDiagnostics.batchSerializeFailed('json_encode');
      throw const FormatException('batch.wire_encode');
    }
    ActivityTelemetryDiagnostics.batchEndpoint(
      host: _endpoint.host,
      port: _endpoint.port,
    );
    if (encoded.length > 256 * 1024) {
      throw const ActivityRequestTooLarge();
    }
    late final HttpClientRequest req;
    try {
      req = await _client
          .postUrl(_endpoint)
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      ActivityTelemetryDiagnostics.batchTransportFailed('socket');
      rethrow;
    } on TimeoutException {
      ActivityTelemetryDiagnostics.batchTransportFailed('timeout');
      rethrow;
    }
    req.headers.contentType = ContentType.json;
    req.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${session.accessToken}',
    );
    req.add(encoded);
    late final HttpClientResponse response;
    try {
      response = await req.close().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      ActivityTelemetryDiagnostics.batchTransportFailed('timeout');
      rethrow;
    } on SocketException {
      ActivityTelemetryDiagnostics.batchTransportFailed('socket');
      rethrow;
    }
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode == 200) {
      final body = jsonDecode(responseBody);
      if (body is! Map<String, dynamic> || body['results'] is! List) {
        ActivityTelemetryDiagnostics.batchInvalidAck('response_shape');
        throw const FormatException('batch.invalid_response');
      }
      // Fail closed on a response that no longer conforms to the pinned
      // generated batch acknowledgment schema.
      final typedAck = IngestActivityEventBatch200Response.fromJson(body);
      if (typedAck == null) {
        ActivityTelemetryDiagnostics.batchInvalidAck('response_schema');
        throw const FormatException('batch.invalid_response');
      }
      return body;
    }
    if (response.statusCode == 401) {
      ActivityTelemetryDiagnostics.batchHttpFailed(status: 401);
      throw const ActivityAuthExpired();
    }
    if (response.statusCode == 429 || response.statusCode >= 500) {
      ActivityTelemetryDiagnostics.batchHttpFailed(status: response.statusCode);
      throw ActivityRetryableHttp(
        response.statusCode,
        retryAfter: parseActivityRetryAfter(
          response.headers.value('retry-after'),
        ),
      );
    }
    final httpError = parseActivityBatchHttpError(
      status: response.statusCode,
      body: responseBody,
    );
    ActivityTelemetryDiagnostics.batchHttpFailed(
      status: response.statusCode,
      errorCode: httpError.topLevelCode,
      fieldPaths: httpError.fieldPaths,
      validationCategories: httpError.validationCategories,
    );
    final errorCode = httpError.topLevelCode;
    throw ActivityPermanentHttp(response.statusCode, errorCode: errorCode);
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
        ? const Duration(hours: 1)
        : remaining;
  } on FormatException {
    return null;
  } on HttpException {
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
  const ActivityPermanentHttp(this.status, {this.errorCode});
  final int status;
  final String? errorCode;
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
  bool _disposed = false;
  bool _flushRunning = false;
  bool _followUpRequested = false;
  Completer<void>? _whenIdle;

  /// Stops scheduling new flushes (tests and app teardown).
  void dispose() {
    _disposed = true;
    _followUpRequested = false;
    final idle = _whenIdle;
    _whenIdle = null;
    idle?.complete();
  }

  /// Schedules a bounded, non-overlapping flush (coalesces concurrent requests).
  void scheduleFlush() {
    if (_disposed) return;
    final coalesced = _flushRunning || _followUpRequested;
    ActivityTelemetryDiagnostics.syncScheduled(coalesced: coalesced);
    unawaited(flush());
  }

  /// Waits until any in-flight batch and coalesced follow-ups finish.
  Future<void> flush() {
    if (_disposed) return Future<void>.value();
    final idle = _whenIdle ??= Completer<void>();
    _followUpRequested = true;
    _kickFlush();
    return idle.future;
  }

  void _kickFlush() {
    if (_flushRunning || _disposed) return;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    _flushRunning = true;
    try {
      while (_followUpRequested && !_disposed) {
        _followUpRequested = false;
        final active = currentSession();
        if (active == null) {
          ActivityTelemetryDiagnostics.syncSkipped('no_session');
          break;
        }
        await _flushOnce(active);
      }
    } finally {
      _flushRunning = false;
      if (_followUpRequested && !_disposed) {
        _kickFlush();
      } else {
        final idle = _whenIdle;
        _whenIdle = null;
        idle?.complete();
      }
    }
  }

  Future<void> _flushOnce(AuthSession initial) async {
      // Each persisted record is capped at 16 KiB (including its session).
      // Twelve records plus the batch envelope fit under the 256 KiB cap.
      // A bounded prefix avoids one oversized batch blocking the entire queue.
      final pending = await outbox.pending(
        initial.parentId,
        now: _clock().toUtc(),
        limit: 12,
      );
      if (pending.isEmpty) {
        ActivityTelemetryDiagnostics.syncSkipped('outbox_empty');
        return;
      }
      if (!_sameAccount(initial)) {
        ActivityTelemetryDiagnostics.syncSkipped('session_changed');
        return;
      }
      ActivityTelemetryDiagnostics.syncStarted(batchSize: pending.length);
      Map<String, dynamic> result;
      try {
        final uniqueSessions = <String, Map<String, dynamic>>{};
        for (final item in pending) {
          if (item.sessionPayload != null) {
            final sessionId = item.sessionPayload!['play_session_id'];
            if (sessionId is! String) {
              ActivityTelemetryDiagnostics.batchInvalidAck(
                'session_play_session_id',
              );
              await _postponeBatch(
                initial,
                pending,
                reason: 'invalid_session_payload',
              );
              return;
            }
            // Prefer the terminal metadata if the same session was completed.
            if (!uniqueSessions.containsKey(sessionId) ||
                item.sessionPayload!['ended_at'] != null) {
              uniqueSessions[sessionId] = item.sessionPayload!;
            }
          }
        }
        result = await send(
          initial,
          pending.map((e) => e.payload).toList(),
          uniqueSessions.values.toList(),
        );
      } on ActivityAuthExpired {
        // No token refresh inside worker; caller must reauthenticate first.
        ActivityTelemetryDiagnostics.syncSkipped('auth_expired');
        return;
      } on ActivityRequestTooLarge {
        // Keep the original immutable events. Avoid a tight retry loop until
        // the request-size policy is reviewed or the batch is split.
        await _postponeBatch(
          initial,
          pending,
          reason: 'request_too_large',
        );
        return;
      } on ActivityRetryableHttp catch (error) {
        await _postponeBatch(
          initial,
          pending,
          reason: 'http_retryable_${error.status}',
          retryAfter: error.retryAfter,
        );
        return;
      } on ActivityPermanentHttp catch (error) {
        // Unknown batch-level rejection: preserve events for investigation,
        // but back off rather than retrying on every foreground tick.
        await _postponeBatch(
          initial,
          pending,
          reason: error.errorCode ?? 'http_permanent_${error.status}',
        );
        return;
      } on FormatException catch (error) {
        ActivityTelemetryDiagnostics.batchUnexpectedFailure(
          _sanitizeFailureKind(error.message),
        );
        await _postponeBatch(
          initial,
          pending,
          reason: 'wire_or_response_format',
        );
        return;
      } on SocketException {
        await _postponeBatch(initial, pending, reason: 'transport_socket');
        return;
      } on TimeoutException {
        await _postponeBatch(initial, pending, reason: 'transport_timeout');
        return;
      } catch (error) {
        ActivityTelemetryDiagnostics.batchUnexpectedFailure(
          _sanitizeFailureKind(error.runtimeType.toString()),
        );
        await _postponeBatch(initial, pending, reason: 'unexpected');
        return;
      }
      if (!_sameAccount(initial)) return;
      final rows = result['results'];
      if (rows is! List) {
        ActivityTelemetryDiagnostics.batchInvalidAck('results_not_list');
        return;
      }
      final acked = <String, ({String status, String? reason})>{};
      for (final entry in rows) {
        if (entry is! Map ||
            entry['event_id'] is! String ||
            entry['status'] is! String) {
          ActivityTelemetryDiagnostics.batchInvalidAck('result_row_shape');
          return;
        }
        final id = entry['event_id'] as String;
        if (acked.containsKey(id)) {
          ActivityTelemetryDiagnostics.batchInvalidAck('duplicate_event_id');
          return;
        }
        acked[id] = (
          status: entry['status'] as String,
          reason: entry['reason_code'] as String?,
        );
      }
      // Validate the full ACK before acknowledging any record.
      if (acked.length != pending.length ||
          pending.any((e) => !acked.containsKey(e.eventId)) ||
          acked.values.any(
            (v) => !{
              'accepted',
              'duplicate_noop',
              'rejected',
              'retryable',
            }.contains(v.status),
          )) {
        ActivityTelemetryDiagnostics.batchInvalidAck('ack_mismatch');
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
            await outbox.quarantine(
              initial.parentId,
              item.eventId,
              ack.reason ?? 'server.rejected',
            );
          }
        } else {
          await outbox.postpone(item, _nextRetry(item.attempts));
        }
      }
      var accepted = 0;
      var duplicate = 0;
      var rejected = 0;
      var retryable = 0;
      for (final ack in acked.values) {
        switch (ack.status) {
          case 'accepted':
            accepted++;
          case 'duplicate_noop':
            duplicate++;
          case 'rejected':
            rejected++;
          case 'retryable':
            retryable++;
        }
      }
      ActivityTelemetryDiagnostics.syncAckSummary(
        accepted: accepted,
        duplicate: duplicate,
        rejected: rejected,
        retryable: retryable,
      );
  }

  bool _sameAccount(AuthSession original) {
    final active = currentSession();
    return active != null &&
        active.parentId == original.parentId &&
        active.sessionId == original.sessionId;
  }

  Future<void> _postponeBatch(
    AuthSession initial,
    List<PendingActivityEvent> pending, {
    required String reason,
    Duration? retryAfter,
  }) async {
    if (!_sameAccount(initial)) return;
    if (pending.isEmpty) return;
    final sample = pending.first;
    final sampleNextAt = retryAfter == null
        ? _nextRetry(sample.attempts)
        : _clock().toUtc().add(retryAfter);
    ActivityTelemetryDiagnostics.syncRetryScheduled(
      reason: reason,
      attempt: sample.attempts + 1,
      backoffSeconds: max(
        1,
        sampleNextAt.difference(_clock().toUtc()).inSeconds,
      ),
    );
    for (final item in pending) {
      final nextAt = retryAfter == null
          ? _nextRetry(item.attempts)
          : _clock().toUtc().add(retryAfter);
      await outbox.postpone(item, nextAt);
    }
  }

  static String _sanitizeFailureKind(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'unknown';
    final safe = RegExp(r'^[a-z][a-z0-9_.-]{0,100}$');
    if (safe.hasMatch(trimmed)) return trimmed;
    return 'sanitized';
  }

  DateTime _nextRetry(int attempts) {
    final capped = min(attempts, 8);
    final maximum = min(300, 2 * (1 << capped));
    return _clock().toUtc().add(
      Duration(milliseconds: 1000 + _random.nextInt(maximum * 1000)),
    );
  }
}

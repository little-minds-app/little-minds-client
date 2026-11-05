import 'package:flutter/foundation.dart';

/// Dev-only LMP-134 / LMP-51 telemetry pipeline logs — no PII, tokens, or payloads.
abstract final class ActivityTelemetryDiagnostics {
  static void gateBlocked(String reason) {
    if (!kDebugMode) return;
    debugPrint('LMP-134 telemetry gate=blocked reason=$reason');
  }

  static void bufferMode({required bool production}) {
    if (!kDebugMode) return;
    debugPrint(
      'LMP-134 telemetry buffer=${production ? 'production' : 'local_only'}',
    );
  }

  static void outboxEnqueued({required int pendingHint}) {
    if (!kDebugMode) return;
    debugPrint('LMP-134 telemetry outbox_enqueue pending_hint=$pendingHint');
  }

  static void syncScheduled({required bool coalesced}) {
    if (!kDebugMode) return;
    debugPrint(
      'LMP-134 telemetry sync_scheduled coalesced=$coalesced',
    );
  }

  static void syncStarted({required int batchSize}) {
    if (!kDebugMode) return;
    debugPrint('LMP-134 telemetry sync_start batch_size=$batchSize');
  }

  static void syncAckSummary({
    required int accepted,
    required int duplicate,
    required int rejected,
    required int retryable,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'LMP-134 telemetry sync_ack '
      'accepted=$accepted duplicate=$duplicate '
      'rejected=$rejected retryable=$retryable',
    );
  }

  static void syncSkipped(String reason) {
    if (!kDebugMode) return;
    debugPrint('LMP-134 telemetry sync_skipped reason=$reason');
  }

  static void batchSerializeFailed(String reason) {
    if (!kDebugMode) return;
    debugPrint('LMP-134 telemetry batch_serialize_failed reason=$reason');
  }

  static void batchTransportFailed(String kind) {
    if (!kDebugMode) return;
    debugPrint('LMP-134 telemetry batch_transport_failed kind=$kind');
  }

  static void batchHttpFailed({
    required int status,
    String? errorCode,
    List<String> fieldPaths = const [],
    List<String> validationCategories = const [],
  }) {
    if (!kDebugMode) return;
    final code = errorCode == null ? '' : ' error_code=$errorCode';
    final paths = fieldPaths.isEmpty
        ? ''
        : ' field_paths=${fieldPaths.join(',')}';
    final categories = validationCategories.isEmpty
        ? ''
        : ' validation_categories=${validationCategories.join(',')}';
    debugPrint(
      'LMP-134 telemetry batch_http_failed status=$status$code$paths$categories',
    );
  }

  static void batchInvalidAck(String reason) {
    if (!kDebugMode) return;
    debugPrint('LMP-134 telemetry batch_invalid_ack reason=$reason');
  }

  static void syncRetryScheduled({
    required String reason,
    required int attempt,
    required int backoffSeconds,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'LMP-134 telemetry sync_retry_scheduled '
      'reason=$reason attempt=$attempt backoff_seconds=$backoffSeconds',
    );
  }

  static void batchEndpoint({required String host, required int port}) {
    if (!kDebugMode) return;
    debugPrint(
      'LMP-134 telemetry batch_endpoint host=$host port=$port',
    );
  }

  static void batchUnexpectedFailure(String kind) {
    if (!kDebugMode) return;
    debugPrint('LMP-134 telemetry batch_unexpected_failure kind=$kind');
  }
}

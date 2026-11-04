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
}

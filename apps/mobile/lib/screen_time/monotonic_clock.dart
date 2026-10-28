/// Platform-native (or fake) monotonic elapsed-time source.
///
/// ADR-016 §35.3: active Kids Mode duration MUST be measured with monotonic
/// elapsed time, not [DateTime.now] deltas. A reboot resets some monotonic
/// counters; [epochId] changes when continuity is broken.
///
/// **Offline / tamper limits:** a device owner who can rewrite local storage or
/// spoof native clocks is outside the V1 threat model. This clock is best-effort
/// integrity for casual skew, **not** tamper-proof.
abstract class MonotonicClock {
  /// Opaque identity of the current monotonic epoch (e.g. boot generation).
  ///
  /// Changes after reboot / process epoch reset so accountants refuse to assume
  /// continuity across the discontinuity.
  String get epochId;

  /// Elapsed time since the start of this [epochId] (never decreases within
  /// an epoch).
  Duration elapsed();
}

/// Production-oriented wrapper around Dart [Stopwatch].
///
/// [epochId] is fixed for the process lifetime unless the caller constructs a
/// new instance after detecting a native boot-id change (future platform hook).
final class StopwatchMonotonicClock implements MonotonicClock {
  StopwatchMonotonicClock({String? epochId})
      : epochId = epochId ?? 'process-${DateTime.now().microsecondsSinceEpoch}',
        _stopwatch = Stopwatch()..start();

  @override
  final String epochId;

  final Stopwatch _stopwatch;

  @override
  Duration elapsed() => _stopwatch.elapsed;
}

/// Deterministic test double — advance with [elapse]; simulate reboot with
/// [reboot].
final class FakeMonotonicClock implements MonotonicClock {
  FakeMonotonicClock({
    this.epochId = 'boot-0',
    this._elapsed = Duration.zero,
  });

  @override
  String epochId;

  Duration _elapsed;

  @override
  Duration elapsed() => _elapsed;

  void elapse(Duration delta) {
    if (delta.isNegative) {
      throw ArgumentError.value(delta, 'delta', 'must be non-negative');
    }
    _elapsed += delta;
  }

  void setElapsed(Duration value) {
    if (value.isNegative) {
      throw ArgumentError.value(value, 'value', 'must be non-negative');
    }
    _elapsed = value;
  }

  /// Simulates reboot: new [epochId], elapsed resets to zero.
  void reboot({String? newEpochId}) {
    epochId = newEpochId ?? 'boot-${DateTime.now().microsecondsSinceEpoch}';
    _elapsed = Duration.zero;
  }
}

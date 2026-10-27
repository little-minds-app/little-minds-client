/// Wall / calendar clock used only for local day identity and skew detection.
///
/// Active duration MUST NOT be derived from wall deltas (ADR-016 §35.3).
///
/// **Offline / tamper limits:** wall time is untrusted offline. Forward jumps
/// alone must not grant a fresh daily budget; backward jumps must not reset
/// usage. See [ScreenTimeAccountant] rollover policy. Not tamper-proof.
abstract class WallClock {
  /// Current wall instant. Implementations used with [DailyPolicy] should
  /// return a clock already expressed in the household local timezone (or UTC
  /// when the policy timezone is UTC scaffolding).
  DateTime now();
}

/// System wall clock (device local by default via [DateTime.now]).
final class SystemWallClock implements WallClock {
  const SystemWallClock();

  @override
  DateTime now() => DateTime.now();
}

/// Deterministic test double.
final class FakeWallClock implements WallClock {
  FakeWallClock(DateTime initial) : _now = initial;

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;

  void advance(Duration delta) => _now = _now.add(delta);
}

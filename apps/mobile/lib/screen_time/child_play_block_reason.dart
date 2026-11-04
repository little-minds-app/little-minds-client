/// Why Kids Mode child play is blocked (LMP-49 / F-010 / ADR-016).
///
/// Used to differentiate calm-boundary copy: daily cap exhaustion must not
/// look identical to clock-integrity / trust / storage fail-closed blocks
/// when remaining budget may still be > 0.
enum ChildPlayBlockReason {
  /// Local daily screen-time cap reached (remaining == 0).
  dailyCap,

  /// Trust degraded (uncertain/guarded), corrupt persistence, or storage
  /// fail-closed — child play blocked until explicit recovery.
  trustOrStorage,
}

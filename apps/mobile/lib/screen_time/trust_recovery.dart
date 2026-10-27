/// Explicit recovery choice when [TrustState] is degraded.
///
/// Never applied implicitly — product/parent flow (later steps) must choose.
enum TrustRecovery {
  /// Keep persisted [dayKey] + accumulated seconds; clear degraded flag to
  /// [TrustState.trusted] for continued enforcement of that budget.
  keepPersistedBudget,

  /// Force rollover to the current wall calendar day with a fresh budget.
  /// Intended for authenticated parent override / reconciliation — not auto.
  forceNewLocalDay,
}

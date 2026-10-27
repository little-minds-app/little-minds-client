/// Explicit recovery choice when [TrustState] is degraded.
///
/// ## Auth / product boundaries (LMP-49 Step 1.1)
/// - **Never automatic.** Neither [keepPersistedBudget] nor [forceNewLocalDay]
///   is applied by restore, tick, persist, start, or clock reconciliation.
/// - **Child surfaces must not invoke this.** Kids Mode has no reset control;
///   calling [ScreenTimeAccountant.recoverTrust] from a child UI is a product
///   bug. Wire only behind a future Parent Gate / authenticated parent flow.
/// - [keepPersistedBudget]: safe local acknowledgment — continue enforcing the
///   persisted day + accumulated seconds (or fail-closed corrupt budget). Does
///   **not** require granting a new day. Still not child-callable.
/// - [forceNewLocalDay]: **parent-authorized only** (re-auth / Parent Gate in a
///   later step). Grants a fresh local calendar day budget. Must never run as a
///   silent side effect of corrupt data, midnight, skew, or restart.
/// - This API does **not** perform authentication itself; callers are
///   responsible for gating. Step 1.1 only documents and enforces non-automatic
///   application inside the accountant.
enum TrustRecovery {
  /// Keep persisted [dayKey] + accumulated seconds; clear degraded flag to
  /// [TrustState.trusted] for continued enforcement of that budget.
  keepPersistedBudget,

  /// Force rollover to the current wall calendar day with a fresh budget.
  /// Parent-authorized override / reconciliation only — never automatic.
  forceNewLocalDay,
}

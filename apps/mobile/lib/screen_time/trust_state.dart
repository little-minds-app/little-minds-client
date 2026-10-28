/// Local trust / quality flag for offline daily budget (ADR-016 §35.3).
///
/// Fail closed: [uncertain] and [guarded] must not silently grant a fresh
/// 30-minute day. Recovery is explicit via [ScreenTimeAccountant.recoverTrust]
/// only (never automatic; child surfaces must not call it — see [TrustRecovery]).
enum TrustState {
  /// Day identity and budget are consistent with monotonic + calendar evidence.
  trusted('trusted'),

  /// Continuity broken (e.g. restart across a calendar change) — budget kept,
  /// no automatic rollover.
  uncertain('uncertain'),

  /// Suspicious wall skew (rollback or forward jump without monotonic proof).
  /// Budget kept for the persisted day; no automatic rollover.
  guarded('guarded');

  const TrustState(this.wireName);
  final String wireName;

  static TrustState? fromWire(String? raw) {
    for (final value in TrustState.values) {
      if (value.wireName == raw) return value;
    }
    return null;
  }

  bool get allowsAutomaticRollover => this == TrustState.trusted;

  bool get isDegraded => this == TrustState.uncertain || this == TrustState.guarded;
}

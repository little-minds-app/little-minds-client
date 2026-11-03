/// Product surfaces that carry an ADR-018 orientation policy.
enum AppSurface {
  /// Kids Mode home hub — landscape-only (ADR-018).
  childHub,

  /// Educational mini-game host — landscape-only (ADR-018).
  miniGame,

  /// Results / rewards — landscape-only (ADR-018).
  gameResults,

  /// Child profile selection — landscape-only (ADR-018).
  profileSelection,

  /// Native Parent Gate — portrait + landscape (ADR-018).
  parentGate,

  /// Native Parent Settings — portrait + landscape (ADR-018).
  parentSettings,

  /// Mobile parent dashboard overview — portrait + landscape (ADR-018).
  parentDashboard,
}

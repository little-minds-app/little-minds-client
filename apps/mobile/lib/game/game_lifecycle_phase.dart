/// Canonical Flame activity session phases (LMP-44 / Blueprint OCP lifecycle).
///
/// Shared by all six future mini-game engines. Mechanics must not invent
/// parallel phase machines in game-specific hosts.
enum GameLifecyclePhase {
  /// No active session.
  idle,

  /// Offline [LearningActivity.prepare] in flight.
  preparing,

  /// Actively playing (engine ticking).
  running,

  /// Explicit pause (in-game pause / break) — engine paused.
  paused,

  /// App backgrounded / inactive — engine paused; distinct from [paused].
  backgrounded,

  /// Scoring-neutral completion reached; awaiting exit.
  completed,

  /// Session torn down; resources released.
  disposed,
}

extension GameLifecyclePhaseX on GameLifecyclePhase {
  bool get isActive =>
      this == GameLifecyclePhase.preparing ||
      this == GameLifecyclePhase.running ||
      this == GameLifecyclePhase.paused ||
      this == GameLifecyclePhase.backgrounded ||
      this == GameLifecyclePhase.completed;

  bool get allowsEngineTick => this == GameLifecyclePhase.running;

  bool get canPause =>
      this == GameLifecyclePhase.running ||
      this == GameLifecyclePhase.backgrounded;

  bool get canResume =>
      this == GameLifecyclePhase.paused ||
      this == GameLifecyclePhase.backgrounded;

  bool get canRestart =>
      this == GameLifecyclePhase.running ||
      this == GameLifecyclePhase.paused ||
      this == GameLifecyclePhase.backgrounded ||
      this == GameLifecyclePhase.completed;
}

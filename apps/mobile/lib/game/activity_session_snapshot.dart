import 'game_lifecycle_phase.dart';

/// Preservable session state across orientation / window-size changes (ADR-018).
class ActivitySessionSnapshot {
  const ActivitySessionSnapshot({
    required this.sessionGeneration,
    required this.activityId,
    required this.phase,
    required this.playState,
    this.pausedBeforeBackground = false,
  });

  /// Monotonic generation that invalidates stale async callbacks.
  final int sessionGeneration;

  final String activityId;
  final GameLifecyclePhase phase;

  /// Opaque activity-owned play state (no child PII).
  final Map<String, Object?> playState;

  /// If true, restoring from background should stay paused.
  final bool pausedBeforeBackground;

  ActivitySessionSnapshot copyWith({
    int? sessionGeneration,
    String? activityId,
    GameLifecyclePhase? phase,
    Map<String, Object?>? playState,
    bool? pausedBeforeBackground,
  }) {
    return ActivitySessionSnapshot(
      sessionGeneration: sessionGeneration ?? this.sessionGeneration,
      activityId: activityId ?? this.activityId,
      phase: phase ?? this.phase,
      playState: playState ?? this.playState,
      pausedBeforeBackground:
          pausedBeforeBackground ?? this.pausedBeforeBackground,
    );
  }
}

/// Developer-owned learning activity contract (ADR-015 / Blueprint OCP).
///
/// LMP-24 ships an empty stub only — no real mini-game mechanics.
abstract class LearningActivity {
  String get id;
  String get displayName;

  /// Lifecycle hook placeholder for a future Flame-backed activity.
  Future<void> prepare();
}

/// Developer-owned learning activity contract (ADR-015 / Blueprint OCP).
///
/// Real mini-game mechanics land in later E03 tasks. Hub v1 (LMP-43) only
/// launches activities where [isPlayable] is true.
abstract class LearningActivity {
  String get id;

  /// Developer-facing English fallback name (UI prefers localized catalog).
  String get displayName;

  /// True only when real, reviewed mechanics exist and may start offline.
  ///
  /// Unimplemented / draft activities MUST remain false so the Child Hub
  /// shows them as passive tiles (no fake games).
  bool get isPlayable => false;

  /// Lifecycle hook placeholder for a future Flame-backed activity.
  Future<void> prepare();
}

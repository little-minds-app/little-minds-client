import 'scoring_neutral_outcome.dart';

/// Developer-owned learning activity contract (ADR-015 / Blueprint OCP).
///
/// Real mini-game mechanics land in later E03 tasks. Hub v1 (LMP-43) only
/// launches activities where [isPlayable] is true. LMP-44 adds the shared
/// Flame session lifecycle hooks used by all six future engines.
abstract class LearningActivity {
  String get id;

  /// Developer-facing English fallback name (UI prefers localized catalog).
  String get displayName;

  /// True only when real, reviewed mechanics exist and may start offline.
  ///
  /// Unimplemented / draft activities MUST remain false so the Child Hub
  /// shows them as passive tiles (no fake games).
  bool get isPlayable => false;

  /// Offline asset / fixture readiness. Must succeed before session enter.
  Future<void> prepare();

  /// Called once after successful [prepare], before the engine ticks.
  Future<void> onEnter() async {}

  /// Explicit in-game pause (child or system break UI).
  Future<void> onPause() async {}

  /// Resume from [onPause] or return from background when appropriate.
  Future<void> onResume() async {}

  /// App moved to inactive / paused / detached / hidden.
  Future<void> onBackground() async {}

  /// App returned to resumed while session still active.
  Future<void> onForeground() async {}

  /// Restart current activity without leaving the host.
  Future<void> onRestart() async {}

  /// Child left the activity (back to hub) before or after completion.
  Future<void> onExit() async {}

  /// Release activity-owned resources. Safe to call more than once.
  Future<void> disposeResources() async {}

  /// Capture opaque play state for orientation / window resize (ADR-018).
  ///
  /// Must not include child PII or raw touch coordinate streams.
  Map<String, Object?> capturePlayState() => const {};

  /// Restore state previously returned by [capturePlayState].
  Future<void> restorePlayState(Map<String, Object?> state) async {}

  /// Receive a scoring-neutral pedagogical outcome.
  void onOutcome(ScoringNeutralOutcome outcome) {}
}

/// Non-punitive, scoring-neutral session outcomes (LMP-44 AC + Blueprint §1).
///
/// No numeric scores, streaks, leaderboards, or shame language. Engines report
/// descriptive pedagogical results only.
sealed class ScoringNeutralOutcome {
  const ScoringNeutralOutcome();
}

/// Child finished the activity calmly — celebration without ranking.
final class ActivityCompletedOutcome extends ScoringNeutralOutcome {
  const ActivityCompletedOutcome({this.encouragementKey = 'completed'});

  /// Stable localization / audio key — never a raw score.
  final String encouragementKey;
}

/// Soft encouragement after an attempt (match or miss) without penalty.
final class EncouragementOutcome extends ScoringNeutralOutcome {
  const EncouragementOutcome({required this.cueKey});

  final String cueKey;
}

/// Graduated hint offered — still scoring-neutral.
final class HintOfferedOutcome extends ScoringNeutralOutcome {
  const HintOfferedOutcome({this.level = 1});

  final int level;
}

/// Child left before completion — no failure framing.
final class ActivityAbandonedOutcome extends ScoringNeutralOutcome {
  const ActivityAbandonedOutcome();
}

import 'animal_sound_matching_logic.dart';

/// LMP-50 / activity-event-v1.schema.json payload allowlists for Animal Sound Matching.
///
/// Instrumentation may carry developer-local keys; production wire MUST match
/// the JSON Schema branches (additionalProperties: false on payload).
///
/// Production sync remains fail-closed until an authoritative published
/// `content_version_id` exists — this mapper never invents one.
abstract final class AnimalSoundMatchingWirePayload {
  /// Task matrix: local instrument keys → schema-safe wire keys.
  static const localInstrumentKeysByType = <String, Set<String>>{
    'activity_started': {
      'age_months',
      'activity_variant_id',
      'choice_count',
      'prompt_mode',
      'restart',
    },
    'activity_attempted': {
      'animal_id',
      'choice_id',
      'correct',
      'round_index',
      'prompt_mode',
    },
    'activity_hint_used': {'hint_level'},
    'activity_completed': {'completion_status', 'scoring', 'prompt_mode'},
    'activity_abandoned': {'completion_status', 'prompt_mode'},
  };

  static const schemaWireKeysByType = <String, Set<String>>{
    'activity_started': {'age_months', 'age_band', 'restart'},
    'activity_attempted': {
      'relation',
      'prompt',
      'attempt_index',
      'eligible_first_attempts',
      'correct_first_attempts',
    },
    'activity_hint_used': {'hint_level'},
    'activity_completed': {
      'completion_status',
      'scoring',
      'hints_used',
      'eligible_first_attempts',
      'correct_first_attempts',
    },
    'activity_abandoned': {'completion_status', 'hints_used'},
  };

  static String? ageBandWire(int? ageMonths) {
    if (ageMonths == null) return null;
    final band = AnimalSoundMatchingBand.forAgeMonths(ageMonths);
    if (band == null) return null;
    if (band.minMonths == 24) return '24_35';
    if (band.minMonths == 36) return '36_47';
    return '48_71';
  }

  /// Canonical payload for batch admission (strip/rename only).
  ///
  /// Local `prompt_mode` is intentionally stripped from production wire —
  /// visual-fallback sessions must not be reported as sound-recognition KPI.
  static Map<String, dynamic> canonicalPayload({
    required String eventType,
    required Map<String, dynamic> instrumentPayload,
    int hintsUsed = 0,
    int? eligibleFirstAttempts,
    int? correctFirstAttempts,
  }) {
    final p = instrumentPayload;
    switch (eventType) {
      case 'activity_started':
        final ageMonths = p['age_months'];
        final band = ageMonths is int ? ageBandWire(ageMonths) : null;
        return {
          if (ageMonths is int) 'age_months': ageMonths,
          'age_band': ?band,
          if (p['restart'] == true) 'restart': true,
        };
      case 'activity_attempted':
        final roundIndex = p['round_index'];
        final wireAttemptIndex = p['attempt_index'];
        final attemptIndex = roundIndex is int
            ? roundIndex
            : (wireAttemptIndex is int ? wireAttemptIndex : null);
        return {
          'attempt_index': ?attemptIndex,
          'eligible_first_attempts': ?eligibleFirstAttempts,
          'correct_first_attempts': ?correctFirstAttempts,
        };
      case 'activity_hint_used':
        return {'hint_level': p['hint_level']};
      case 'activity_completed':
        return {
          'completion_status': 'completed',
          'scoring': 'neutral',
          if (hintsUsed > 0) 'hints_used': hintsUsed,
          'eligible_first_attempts': ?eligibleFirstAttempts,
          'correct_first_attempts': ?correctFirstAttempts,
        };
      case 'activity_abandoned':
        return {
          'completion_status': 'abandoned',
          if (hintsUsed > 0) 'hints_used': hintsUsed,
        };
      default:
        throw ArgumentError(
          'Animal Sound Matching production event type not mapped',
        );
    }
  }
}

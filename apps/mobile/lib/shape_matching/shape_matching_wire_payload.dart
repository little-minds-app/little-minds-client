import 'shape_matching_logic.dart';

/// LMP-50 / activity-event-v1.schema.json payload allowlists for Shape Matching.
///
/// Instrumentation may carry developer-local keys; production wire MUST match
/// the JSON Schema branches (additionalProperties: false on payload).
abstract final class ShapeMatchingWirePayload {
  /// Published LMP-134 Shape Matching `content_version_id` (telemetry fixture).
  static const productionContentVersionId =
      '018f1340-0000-4000-8000-000000000001';

  /// Task 1–4 matrix: local instrument keys → wire keys accepted by schema.
  static const localInstrumentKeysByType = <String, Set<String>>{
    'activity_started': {'age_months', 'activity_variant_id', 'choice_count', 'restart'},
    'activity_attempted': {'shape_id', 'correct', 'round_index'},
    'activity_hint_used': {'hint_level'},
    'activity_completed': {'completion_status', 'scoring'},
    'activity_abandoned': {'completion_status'},
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
    final band = ShapeMatchingBand.forAgeMonths(ageMonths);
    if (band == null) return null;
    if (band.minMonths == 24) return '24_35';
    if (band.minMonths == 36) return '36_47';
    if (band.minMonths == 48 && band.maxMonths == 59) return '48_59';
    return '60_71';
  }

  /// Canonical payload for batch admission (strip/rename only — no backend loosening).
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
          if (band != null) 'age_band': band,
          if (p['restart'] == true) 'restart': true,
        };
      case 'activity_attempted':
        final roundIndex = p['round_index'];
        return {
          if (roundIndex is int) 'attempt_index': roundIndex,
          if (eligibleFirstAttempts != null)
            'eligible_first_attempts': eligibleFirstAttempts,
          if (correctFirstAttempts != null)
            'correct_first_attempts': correctFirstAttempts,
        };
      case 'activity_hint_used':
        return {'hint_level': p['hint_level']};
      case 'activity_completed':
        return {
          'completion_status': 'completed',
          'scoring': 'neutral',
          if (hintsUsed > 0) 'hints_used': hintsUsed,
          if (eligibleFirstAttempts != null)
            'eligible_first_attempts': eligibleFirstAttempts,
          if (correctFirstAttempts != null)
            'correct_first_attempts': correctFirstAttempts,
        };
      case 'activity_abandoned':
        return {
          'completion_status': 'abandoned',
          if (hintsUsed > 0) 'hints_used': hintsUsed,
        };
      default:
        throw ArgumentError('Shape Matching production event type not mapped');
    }
  }

  /// Repairs queued wire envelopes written before payload canonicalization (legacy outbox).
  static Map<String, dynamic> repairQueuedEvent(
    Map<String, dynamic> envelope, {
    int hintsUsed = 0,
    int? eligibleFirstAttempts,
    int? correctFirstAttempts,
  }) {
    if (envelope['content_version_id'] != productionContentVersionId) {
      return envelope;
    }
    final eventType = envelope['event_type'];
    if (eventType is! String ||
        !schemaWireKeysByType.containsKey(eventType)) {
      return envelope;
    }
    final payload = envelope['payload'];
    if (payload is! Map) return envelope;
    final copy = Map<String, dynamic>.from(envelope);
    copy['payload'] = canonicalPayload(
      eventType: eventType,
      instrumentPayload: Map<String, dynamic>.from(payload),
      hintsUsed: hintsUsed,
      eligibleFirstAttempts: eligibleFirstAttempts,
      correctFirstAttempts: correctFirstAttempts,
    );
    return copy;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_wire_payload.dart';

void main() {
  test('age band wire mapping', () {
    expect(AnimalSoundMatchingWirePayload.ageBandWire(30), '24_35');
    expect(AnimalSoundMatchingWirePayload.ageBandWire(40), '36_47');
    expect(AnimalSoundMatchingWirePayload.ageBandWire(55), '48_71');
    expect(AnimalSoundMatchingWirePayload.ageBandWire(17), isNull);
  });

  test('canonical started strips local-only keys including prompt_mode', () {
    final payload = AnimalSoundMatchingWirePayload.canonicalPayload(
      eventType: 'activity_started',
      instrumentPayload: {
        'age_months': 30,
        'activity_variant_id': 'animal_sound_matching',
        'choice_count': 2,
        'prompt_mode': 'visual',
        'restart': true,
      },
    );
    expect(payload.keys.toSet(), {'age_months', 'age_band', 'restart'});
    expect(payload['age_band'], '24_35');
    expect(payload.containsKey('prompt_mode'), isFalse);
  });

  test('canonical attempted uses attempt_index from round_index', () {
    final payload = AnimalSoundMatchingWirePayload.canonicalPayload(
      eventType: 'activity_attempted',
      instrumentPayload: {
        'animal_id': 'cat',
        'choice_id': 'dog',
        'correct': false,
        'round_index': 2,
        'prompt_mode': 'audio',
      },
    );
    expect(payload['attempt_index'], 2);
    expect(payload.containsKey('animal_id'), isFalse);
    expect(payload.containsKey('prompt_mode'), isFalse);
  });

  test('canonical completed is scoring-neutral', () {
    final payload = AnimalSoundMatchingWirePayload.canonicalPayload(
      eventType: 'activity_completed',
      instrumentPayload: {
        'completion_status': 'completed',
        'scoring': 'neutral',
        'prompt_mode': 'visual',
      },
      hintsUsed: 1,
      eligibleFirstAttempts: 3,
      correctFirstAttempts: 2,
    );
    expect(payload['scoring'], 'neutral');
    expect(payload['hints_used'], 1);
    expect(payload['eligible_first_attempts'], 3);
    expect(payload.containsKey('prompt_mode'), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_wire_payload.dart';

void main() {
  test('age band wire mapping', () {
    expect(ColorSortingWirePayload.ageBandWire(30), '24_35');
    expect(ColorSortingWirePayload.ageBandWire(40), '36_47');
    expect(ColorSortingWirePayload.ageBandWire(55), '48_71');
    expect(ColorSortingWirePayload.ageBandWire(17), isNull);
  });

  test('canonical started strips local-only keys', () {
    final payload = ColorSortingWirePayload.canonicalPayload(
      eventType: 'activity_started',
      instrumentPayload: {
        'age_months': 30,
        'activity_variant_id': 'color_sorting',
        'bin_count': 2,
        'restart': true,
      },
    );
    expect(payload.keys.toSet(), {'age_months', 'age_band', 'restart'});
    expect(payload['age_band'], '24_35');
  });

  test('canonical attempted uses attempt_index from round_index', () {
    final payload = ColorSortingWirePayload.canonicalPayload(
      eventType: 'activity_attempted',
      instrumentPayload: {
        'color_id': 'red',
        'bin_id': 'blue',
        'correct': false,
        'round_index': 2,
      },
    );
    expect(payload['attempt_index'], 2);
    expect(payload.containsKey('color_id'), isFalse);
  });

  test('canonical completed is scoring-neutral', () {
    final payload = ColorSortingWirePayload.canonicalPayload(
      eventType: 'activity_completed',
      instrumentPayload: {'completion_status': 'completed', 'scoring': 'neutral'},
      hintsUsed: 1,
      eligibleFirstAttempts: 3,
      correctFirstAttempts: 2,
    );
    expect(payload['scoring'], 'neutral');
    expect(payload['hints_used'], 1);
    expect(payload['eligible_first_attempts'], 3);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_wire_payload.dart';

void main() {
  test('canonical payloads strip Shape Matching instrument keys', () {
    expect(
      ShapeMatchingWirePayload.canonicalPayload(
        eventType: 'activity_started',
        instrumentPayload: {
          'age_months': 36,
          'activity_variant_id': 'shape_matching',
          'choice_count': 3,
        },
      ),
      {'age_months': 36, 'age_band': '36_47'},
    );
    expect(
      ShapeMatchingWirePayload.canonicalPayload(
        eventType: 'activity_attempted',
        instrumentPayload: {
          'shape_id': 'circle',
          'correct': true,
          'round_index': 2,
        },
      ),
      {'attempt_index': 2},
    );
  });

  test('repairQueuedEvent fixes legacy outbox envelope', () {
    final legacy = {
      'content_version_id': ShapeMatchingWirePayload.productionContentVersionId,
      'event_type': 'activity_attempted',
      'payload': {'shape_id': 'star', 'correct': false, 'round_index': 1},
    };
    final repaired = ShapeMatchingWirePayload.repairQueuedEvent(legacy);
    expect(repaired['payload'], {'attempt_index': 1});
  });

  test('additionalProperties negative: shape_id fails schema wire set', () {
    const wireKeys =
        ShapeMatchingWirePayload.schemaWireKeysByType['activity_attempted']!;
    expect(wireKeys.contains('shape_id'), isFalse);
  });
}

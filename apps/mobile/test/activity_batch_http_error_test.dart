import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/offline/activity_batch_http_error.dart';

void main() {
  test('parseActivityBatchHttpError extracts stable codes and field paths', () {
    const body = '''
{
  "statusCode": 400,
  "message": [
    "sessions.0.device_id must match pattern",
    "batch.invalid_event"
  ],
  "error": "Bad Request",
  "details": [
    {"path": ["events", 1, "payload", "shape_id"], "code": "schema.enum"}
  ]
}
''';
    final summary = parseActivityBatchHttpError(status: 400, body: body);
    expect(summary.topLevelCode, 'batch.invalid_event');
    expect(summary.fieldPaths, contains('sessions.0.device_id'));
    expect(summary.validationCategories, contains('schema.pattern'));
    expect(summary.validationCategories, contains('schema.enum'));
  });

  test('parseActivityBatchHttpError ignores unsafe message content', () {
    const body =
        '{"message":"Bearer secret-token leaked","error":"not safe!"}';
    final summary = parseActivityBatchHttpError(status: 400, body: body);
    expect(summary.topLevelCode, isNull);
    expect(summary.validationCategories, contains('schema.validation'));
  });
}

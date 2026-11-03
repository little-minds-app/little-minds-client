import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_api/api.dart';
import 'package:little_minds_mobile/parent_dashboard/mission_status_view_data.dart';

import 'parent_dashboard_fixtures.dart';

void main() {
  test('maps reported parent status with provenance labels', () {
    final view = mapMissionStatusToView(sampleMissionStatusResponse());
    expect(view.isEmpty, isFalse);
    expect(view.rows.single.reportPresentation, MissionReportPresentation.reported);
    expect(view.rows.single.reportLabel, contains('caregiver_report'));
    expect(view.rows.single.reportLabel, contains('Tamamlandı'));
  });

  test('maps no_report without inventing completion', () {
    final view = mapMissionStatusToView(
      sampleMissionStatusResponse(
        items: [
          sampleMissionRow(
            reportAvailability: MissionParentReportFactsAvailabilityEnum.noReport,
          ),
        ],
      ),
    );
    expect(view.rows.single.reportPresentation, MissionReportPresentation.noReport);
    expect(view.rows.single.reportLabel, contains('Ebeveyn bildirimi yok'));
  });

  test('surfaces truncated pagination flag', () {
    final view = mapMissionStatusToView(
      sampleMissionStatusResponse(truncated: true),
    );
    expect(view.truncated, isTrue);
  });
}

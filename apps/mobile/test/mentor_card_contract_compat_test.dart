import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/mentor/mentor.dart';
import 'package:little_minds_mobile/near_far/near_far_constants.dart';

/// Offline contract-compatibility suite (LMP-47 review fix).
///
/// Backend schema is SoT. These tests do **not** call the API and do not
/// require a live backend clone in CI — see `content/mentor-card/CONTRACT_COMPAT.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MentorCardV1 enCard;
  late MentorCardV1 trCard;
  late Map<String, Object?> enRaw;
  late Map<String, Object?> trRaw;

  setUpAll(() async {
    final loader = MentorCardFixtureLoader();
    enRaw = await loader.loadRawNearFar(locale: 'en-US');
    trRaw = await loader.loadRawNearFar(locale: 'tr-TR');
    enCard = await loader.requireNearFar(locale: 'en-US');
    trCard = await loader.requireNearFar(locale: 'tr-TR');
  });

  group('Pin + schema version (SoT mirror)', () {
    test('TC-MC-C01 pin SHA matches verified backend merge commit', () {
      // Backend PR #11 merge on main (verified) — do not invent SHAs.
      expect(
        MentorCardContentPin.backendCommitSha,
        '8678e61a673e82a5823875d8af4fc1bf6d700ac9',
      );
      expect(MentorCardContentPin.schemaVersion, '1.0.0');
      expect(mentorCardSchemaVersion, '1.0.0');
    });

    test('TC-MC-C02 repo VERSION file is 1.0.0 when present', () {
      final candidates = [
        File('../../content/mentor-card/VERSION'),
        File('../content/mentor-card/VERSION'),
        File('content/mentor-card/VERSION'),
        File('/workspace/content/mentor-card/VERSION'),
      ];
      File? found;
      for (final c in candidates) {
        if (c.existsSync()) {
          found = c;
          break;
        }
      }
      expect(found, isNotNull, reason: 'VERSION mirror missing');
      expect(found!.readAsStringSync().trim(), '1.0.0');
    });

    test('TC-MC-C03 unknown schema_version fails closed', () {
      final bad = Map<String, Object?>.from(enRaw)..['schema_version'] = '9.9.9';
      final result = validateMentorCard(bad);
      expect(result, isA<MentorCardValidationFail>());
      expect(
        (result as MentorCardValidationFail)
            .issues
            .any((i) => i.code == 'schema.version_incompatible'),
        isTrue,
      );
    });
  });

  group('Fixture parity en-US / tr-TR', () {
    test('TC-MC-C04 paired locales share id and required caregiver sections', () {
      expect(enCard.mentorCardId, trCard.mentorCardId);
      expect(enCard.mentorCardId, nearFarMentorCardId);
      expect(enCard.locale, 'en-US');
      expect(trCard.locale, 'tr-TR');
      expect(enCard.schemaVersion, trCard.schemaVersion);
      expect(enCard.ageMinMonths, trCard.ageMinMonths);
      expect(enCard.ageMaxMonths, trCard.ageMaxMonths);
      expect(enCard.why.summary, isNotEmpty);
      expect(trCard.why.summary, isNotEmpty);
      expect(enCard.how.steps, isNotEmpty);
      expect(enCard.whatToSay.during.length, greaterThanOrEqualTo(1));
      expect(enCard.safety.constraints, isNotEmpty);
      expect(enCard.adaptations, isNotEmpty);
      expect(enCard.reviewStatus, 'draft');
      expect(trCard.reviewStatus, 'draft');
    });

    test('TC-MC-C05 asset fixtures byte-match content/ mirror for mission id', () {
      expect(enCard.linkedMissionIds, contains(NearFarConstants.missionId));
      expect(trCard.linkedMissionIds, contains(NearFarConstants.missionId));
    });
  });

  group('Near/Far mission resolution', () {
    test('TC-MC-C06 mentor card resolves to NearFarConstants.missionId', () {
      expect(enCard.mentorCardId, NearFarConstants.mentorCardId);
      expect(enCard.linkedMissionIds, contains(NearFarConstants.missionId));
      expect(enCard.linkedActivityIds, contains(NearFarConstants.activityId));
      expect(enCard.ageMinMonths, NearFarConstants.ageMinMonths);
      expect(enCard.ageMaxMonths, NearFarConstants.ageMaxMonths);
      expect(
        MentorCardNearFarLinks.resolveMissionId(enCard),
        NearFarConstants.missionId,
      );
      expect(
        MentorCardNearFarLinks.resolveMissionId(trCard),
        NearFarConstants.missionId,
      );
      expect(MentorCardNearFarLinks.isNearFarMentorCard(enCard), isTrue);
      expect(
        MentorCardNearFarLinks.resolveActivityId(enCard),
        NearFarConstants.activityId,
      );
    });

    test('TC-MC-C07 legacy content mission id still maps to runtime v1', () {
      final legacy = enCard.copyWith(
        linkedMissionIds: const [
          MentorCardNearFarLinks.legacyContentMissionId,
        ],
      );
      expect(
        MentorCardNearFarLinks.resolveMissionId(legacy),
        NearFarConstants.missionId,
      );
    });

    test('TC-MC-C08 unrelated mission link does not resolve to Near/Far', () {
      final other = enCard.copyWith(
        linkedMissionIds: const ['color_hunt_v1'],
        mentorCardId: 'other_card',
      );
      expect(MentorCardNearFarLinks.resolveMissionId(other), isNull);
      expect(MentorCardNearFarLinks.isNearFarMentorCard(other), isFalse);
    });
  });

  group('Draft ≠ approved', () {
    test('TC-MC-C09 fixtures remain draft and fail parent-surface gate', () {
      expect(MentorCardReviewGate.isDraft(enCard), isTrue);
      expect(MentorCardReviewGate.isApprovedOrLater(enCard), isFalse);
      expect(MentorCardReviewGate.mayRenderOnParentMentorSurface(enCard), isFalse);
      expect(trCard.reviewStatus, isNot(equals('approved')));
      expect(trCard.reviewStatus, isNot(equals('published')));
    });

    test('TC-MC-C10 approved status would pass gate (synthetic)', () {
      final approved = enCard.copyWith(reviewStatus: 'approved');
      expect(MentorCardReviewGate.isDraft(approved), isFalse);
      expect(MentorCardReviewGate.mayRenderOnParentMentorSurface(approved), isTrue);
    });
  });

  group('Valid / invalid agreement with backend-style rules', () {
    test('TC-MC-C11 valid fixtures pass full validator', () {
      expect(validateMentorCard(enRaw), isA<MentorCardValidationOk>());
      expect(validateMentorCard(trRaw), isA<MentorCardValidationOk>());
    });

    test('TC-MC-C12 invalid: missing safety adaptations fails', () {
      final bad = jsonDecode(jsonEncode(enRaw)) as Map<String, dynamic>;
      bad.remove('adaptations');
      final result = validateMentorCard(Map<String, Object?>.from(bad));
      expect(result, isA<MentorCardValidationFail>());
    });

    test('TC-MC-C13 invalid: age out of band fails', () {
      expect(isMentorCardAgeApplicable(enCard, 29), isFalse);
      expect(isMentorCardAgeApplicable(enCard, 32), isTrue);
    });

    test('TC-MC-C14 invalid: proof/photo copy fails safe-copy', () {
      final bad = jsonDecode(jsonEncode(enRaw)) as Map<String, dynamic>;
      bad['what_to_say'] = {
        ...(bad['what_to_say'] as Map),
        'during': ['Please take a photo proof of the toys.'],
      };
      bad['parent_prompts_during'] = [
        'Please take a photo proof of the toys.',
      ];
      final result = validateMentorCard(Map<String, Object?>.from(bad));
      expect(result, isA<MentorCardValidationFail>());
      final codes =
          (result as MentorCardValidationFail).issues.map((i) => i.code);
      expect(codes.any((c) => c.startsWith('safe_copy.')), isTrue);
    });
  });
}

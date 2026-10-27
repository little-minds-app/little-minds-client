import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/mentor/mentor.dart';

Map<String, Object?> _deepCopy(Map<String, Object?> source) {
  return Map<String, Object?>.from(
    jsonDecode(jsonEncode(source)) as Map<dynamic, dynamic>,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Object?> enRaw;
  late Map<String, Object?> trRaw;
  late MentorCardV1 enCard;

  setUpAll(() async {
    final loader = MentorCardFixtureLoader();
    enRaw = await loader.loadRawNearFar(locale: 'en-US');
    trRaw = await loader.loadRawNearFar(locale: 'tr-TR');
    final enResult = validateMentorCard(enRaw);
    expect(enResult, isA<MentorCardValidationOk>());
    enCard = (enResult as MentorCardValidationOk).card;
  });

  group('Mentor card pin + fixtures (LMP-47)', () {
    test('TC-MC-001 pin documents backend PR head pending merge', () {
      expect(
        MentorCardContentPin.backendCommitSha,
        'a6dc8116994595be1788450c525e48138b9580eb',
      );
      expect(MentorCardContentPin.schemaVersion, mentorCardSchemaVersion);
      expect(
        MentorCardContentPin.backendPullRequestUrl,
        contains('little-minds-backend/pull/11'),
      );
    });

    test('TC-MC-002 accepts Near/Far en-US and tr-TR fixtures', () async {
      final loader = MentorCardFixtureLoader();
      final en = await loader.requireNearFar(locale: 'en-US');
      final tr = await loader.requireNearFar(locale: 'tr-TR');

      expect(en.schemaVersion, '1.0.0');
      expect(tr.schemaVersion, '1.0.0');
      expect(en.mentorCardId, nearFarMentorCardId);
      expect(tr.mentorCardId, nearFarMentorCardId);
      expect(en.why.summary, isNotEmpty);
      expect(en.how.steps, isNotEmpty);
      expect(en.whatToSay.before, isNotEmpty);
      expect(en.safety.requiresAdultSupervision, isTrue);
      expect(en.safety.prohibitsProofOrPhoto, isTrue);
      expect(en.adaptations, isNotEmpty);
      expect(en.locale, 'en-US');
      expect(tr.locale, 'tr-TR');
      expect(en.reviewStatus, 'draft');
      expect(
        MentorCardNearFarLinks.resolveMissionId(en),
        'near_far_sock_soft_toy_v1',
      );
    });

    test('TC-MC-003 locales share mentor_card_id without single-locale hardcoding',
        () {
      expect(enRaw['mentor_card_id'], trRaw['mentor_card_id']);
      expect(enRaw['locale'], isNot(trRaw['locale']));
      expect(mentorCardV1Locales, containsAll(['en-US', 'tr-TR']));
    });
  });

  group('Mentor card validation', () {
    test('TC-MC-004 rejects missing required caregiver sections', () {
      final card = _deepCopy(enRaw)
        ..remove('why')
        ..remove('how')
        ..remove('what_to_say');
      final result = validateMentorCard(card);
      expect(result, isA<MentorCardValidationFail>());
      final blob = (result as MentorCardValidationFail)
          .issues
          .map((i) => '${i.path} ${i.message}')
          .join(' ');
      expect(blob, anyOf(contains('why'), contains('how'), contains('what_to_say')));
    });

    test('TC-MC-005 rejects invalid payload types', () {
      expect(validateMentorCard(null), isA<MentorCardValidationFail>());
      expect(validateMentorCard('x'), isA<MentorCardValidationFail>());
    });

    test('TC-MC-006 rejects incompatible schema_version', () {
      final card = _deepCopy(enRaw)..['schema_version'] = '2.0.0';
      final result = validateMentorCard(card);
      expect(result, isA<MentorCardValidationFail>());
      final issues = (result as MentorCardValidationFail).issues;
      expect(
        issues.any((i) => i.code == 'schema.version_incompatible'),
        isTrue,
      );
    });

    test('TC-MC-007 rejects age_min_months > age_max_months', () {
      final card = _deepCopy(enRaw)
        ..['age_min_months'] = 48
        ..['age_max_months'] = 30;
      final result = validateMentorCard(card);
      expect(result, isA<MentorCardValidationFail>());
      expect(
        (result as MentorCardValidationFail)
            .issues
            .any((i) => i.code == 'age.range_order'),
        isTrue,
      );
    });

    test('TC-MC-008 rejects age outside product band via structural rules', () {
      final card = _deepCopy(enRaw)
        ..['age_min_months'] = 12
        ..['age_max_months'] = 18;
      final result = validateMentorCard(card);
      expect(result, isA<MentorCardValidationFail>());
    });

    test('TC-MC-009 applies hard age eligibility filter', () {
      expect(isMentorCardAgeApplicable(enCard, 32), isTrue);
      expect(isMentorCardAgeApplicable(enCard, 29), isFalse);
      expect(isMentorCardAgeApplicable(enCard, 48), isFalse);
      expect(isMentorCardAgeApplicable(enCard, 23), isFalse);
    });

    test('TC-MC-010 rejects coercive / proof copy via safe-copy rules', () {
      final card = _deepCopy(enRaw);
      final what = Map<String, Object?>.from(card['what_to_say']! as Map);
      what['during'] = [
        'You must complete 5 missions daily and take a photo proof.',
      ];
      card['what_to_say'] = what;
      card['parent_prompts_during'] = [
        'You must complete 5 missions daily and take a photo proof.',
      ];
      final result = validateMentorCard(card);
      expect(result, isA<MentorCardValidationFail>());
      final codes =
          (result as MentorCardValidationFail).issues.map((i) => i.code);
      expect(codes.any((c) => c.startsWith('safe_copy.')), isTrue);
    });

    test('TC-MC-011 rejects missing adult-supervision safety copy', () {
      final card = _deepCopy(enRaw);
      card['safety'] = {
        'constraints': ['No glass or choking hazards.'],
        'requires_adult_supervision': true,
        'prohibits_proof_or_photo': true,
      };
      final result = validateMentorCard(card);
      expect(result, isA<MentorCardValidationFail>());
      expect(
        (result as MentorCardValidationFail).issues.any(
              (i) => i.code == 'safe_copy.adult_supervision_copy',
            ),
        isTrue,
      );
    });

    test('TC-MC-012 rejects what_to_say / Blueprint alias mismatch', () {
      final card = _deepCopy(enRaw)
        ..['parent_script_before'] = [
          'Different text than what_to_say.before',
        ];
      final result = validateMentorCard(card);
      expect(result, isA<MentorCardValidationFail>());
      expect(
        (result as MentorCardValidationFail).issues.any(
              (i) => i.code == 'copy.script_alias_mismatch',
            ),
        isTrue,
      );
    });

    test('TC-MC-013 allows forward-compatible extensions bag', () {
      final card = _deepCopy(enRaw)
        ..['extensions'] = {
          'future_hint': true,
          'nested': {'ok': 1},
        };
      expect(validateMentorCard(card), isA<MentorCardValidationOk>());
    });
  });

  group('Mentor card safe-copy (locale)', () {
    test('TC-MC-014 flags Turkish adult-supervision absence', () {
      final issues = validateMentorCardSafeCopy(
        enCard.copyWith(
          locale: 'tr-TR',
          safety: const MentorCardSafety(
            constraints: ['Cam kullanmayın.'],
            requiresAdultSupervision: true,
            prohibitsProofOrPhoto: true,
          ),
        ),
      );
      expect(
        issues.any((i) => i.code == 'safe_copy.adult_supervision_copy'),
        isTrue,
      );
    });

    test('TC-MC-015 accepts Turkish yetişkin gözetimi phrasing', () {
      final issues = validateMentorCardSafeCopy(
        enCard.copyWith(
          locale: 'tr-TR',
          safety: const MentorCardSafety(
            constraints: ['Yetişkin gözetimi gerekir.'],
            requiresAdultSupervision: true,
            prohibitsProofOrPhoto: true,
          ),
        ),
      );
      expect(issues, isEmpty);
    });

    test('TC-MC-016 flags diagnostic language outside disclaimer', () {
      final issues = validateMentorCardSafeCopy(
        enCard.copyWith(
          why: const MentorCardWhy(
            summary: 'This diagnoses spatial delay.',
            learningIntention: 'Explore.',
          ),
        ),
      );
      expect(
        issues.any((i) => i.code == 'safe_copy.diagnostic_claim'),
        isTrue,
      );
    });
  });

  group('Asset availability', () {
    test('TC-MC-017 fixture assets are declared and loadable', () async {
      for (final name in [
        MentorCardContentPin.nearFarEnUsFixture,
        MentorCardContentPin.nearFarTrTrFixture,
      ]) {
        final raw = await rootBundle
            .loadString(MentorCardContentPin.fixtureAssetPath(name));
        expect(raw, isNotEmpty);
        expect(jsonDecode(raw), isA<Map>());
      }
    });
  });
}

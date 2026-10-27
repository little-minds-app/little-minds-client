import 'mentor_card.dart';
import 'mentor_card_safe_copy.dart';

final _localePattern = RegExp(r'^[a-z]{2}-[A-Z]{2}$');
final _mentorCardIdPattern = RegExp(r'^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$');

bool _isNonEmptyString(Object? value, {int max = 1000}) {
  if (value is! String) return false;
  return value.isNotEmpty && value.length <= max;
}

bool _isStringList(
  Object? value, {
  required int minItems,
  int maxItemLen = 400,
}) {
  if (value is! List) return false;
  if (value.length < minItems) return false;
  for (final item in value) {
    if (item is! String) return false;
    if (item.isEmpty) return false;
    if (item.length > maxItemLen) return false;
  }
  return true;
}

List<MentorCardValidationIssue> _requireKey(
  Map<String, Object?> record,
  String key,
) {
  if (!record.containsKey(key) || record[key] == null) {
    return [
      MentorCardValidationIssue(
        code: 'schema.required',
        path: '/$key',
        message: 'must have required property \'$key\'',
      ),
    ];
  }
  return const [];
}

List<MentorCardValidationIssue> _validateStructural(
  Map<String, Object?> record,
) {
  final issues = <MentorCardValidationIssue>[];

  const requiredKeys = [
    'schema_version',
    'mentor_card_id',
    'version',
    'locale',
    'title',
    'age_min_months',
    'age_max_months',
    'domains',
    'goals',
    'interaction_style',
    'estimated_prep_minutes',
    'estimated_screen_minutes',
    'estimated_offscreen_minutes',
    'materials',
    'why',
    'how',
    'what_to_say',
    'safety',
    'adaptations',
    'parent_script_before',
    'parent_prompts_during',
    'parent_prompts_after',
    'scaffold_down',
    'extend_up',
    'evidence_refs',
    'review_status',
    'observed_vs_suggested',
    'not_a_developmental_assessment',
  ];

  for (final key in requiredKeys) {
    issues.addAll(_requireKey(record, key));
  }
  if (issues.isNotEmpty) return issues;

  final id = record['mentor_card_id'];
  if (id is! String ||
      id.isEmpty ||
      id.length > 128 ||
      !_mentorCardIdPattern.hasMatch(id)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.pattern',
        path: '/mentor_card_id',
        message: 'must match mentor_card_id pattern',
      ),
    );
  }

  final version = record['version'];
  if (version is! int || version < 1) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.minimum',
        path: '/version',
        message: 'version must be an integer >= 1',
      ),
    );
  }

  final locale = record['locale'];
  if (locale is! String || !_localePattern.hasMatch(locale)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.pattern',
        path: '/locale',
        message: 'locale must match xx-YY',
      ),
    );
  }

  if (!_isNonEmptyString(record['title'], max: 200)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.type',
        path: '/title',
        message: 'title must be a non-empty string',
      ),
    );
  }

  final ageMin = record['age_min_months'];
  final ageMax = record['age_max_months'];
  if (ageMin is! int || ageMin < 24 || ageMin > 71) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.minimum',
        path: '/age_min_months',
        message: 'age_min_months must be 24–71',
      ),
    );
  }
  if (ageMax is! int || ageMax < 24 || ageMax > 71) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.maximum',
        path: '/age_max_months',
        message: 'age_max_months must be 24–71',
      ),
    );
  }

  if (!_isStringList(record['domains'], minItems: 1, maxItemLen: 64)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.minItems',
        path: '/domains',
        message: 'domains must be a non-empty string array',
      ),
    );
  }
  if (!_isStringList(record['goals'], minItems: 1, maxItemLen: 128)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.minItems',
        path: '/goals',
        message: 'goals must be a non-empty string array',
      ),
    );
  }

  final style = record['interaction_style'];
  if (style is! String || !mentorCardInteractionStyles.contains(style)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.enum',
        path: '/interaction_style',
        message: 'interaction_style is not an allowed value',
      ),
    );
  }

  for (final entry in {
    'estimated_prep_minutes': (0, 60),
    'estimated_screen_minutes': (0, 30),
    'estimated_offscreen_minutes': (0, 60),
  }.entries) {
    final value = record[entry.key];
    if (value is! int || value < entry.value.$1 || value > entry.value.$2) {
      issues.add(
        MentorCardValidationIssue(
          code: 'schema.minimum',
          path: '/${entry.key}',
          message: '${entry.key} out of range',
        ),
      );
    }
  }

  final materials = record['materials'];
  if (materials is! List || materials.isEmpty) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.minItems',
        path: '/materials',
        message: 'materials must be a non-empty array',
      ),
    );
  } else {
    for (var i = 0; i < materials.length; i++) {
      final m = materials[i];
      if (m is! Map ||
          !_isNonEmptyString(m['id'], max: 64) ||
          !_isNonEmptyString(m['label'], max: 200)) {
        issues.add(
          MentorCardValidationIssue(
            code: 'schema.required',
            path: '/materials/$i',
            message: 'material requires id and label',
          ),
        );
      }
    }
  }

  final why = record['why'];
  if (why is! Map ||
      !_isNonEmptyString(why['summary'], max: 500) ||
      !_isNonEmptyString(why['learning_intention'], max: 500)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.required',
        path: '/why',
        message: 'why requires summary and learning_intention',
      ),
    );
  }

  final how = record['how'];
  if (how is! Map ||
      !_isNonEmptyString(how['prep_summary'], max: 500) ||
      !_isStringList(how['steps'], minItems: 1)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.required',
        path: '/how',
        message: 'how requires prep_summary and steps',
      ),
    );
  }

  final what = record['what_to_say'];
  if (what is! Map ||
      !_isStringList(what['before'], minItems: 1) ||
      !_isStringList(what['during'], minItems: 1) ||
      !_isStringList(what['after'], minItems: 1)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.required',
        path: '/what_to_say',
        message: 'what_to_say requires before/during/after',
      ),
    );
  }

  final safety = record['safety'];
  if (safety is! Map ||
      !_isStringList(safety['constraints'], minItems: 1) ||
      safety['requires_adult_supervision'] != true ||
      safety['prohibits_proof_or_photo'] != true) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.const',
        path: '/safety',
        message:
            'safety requires constraints and true supervision/no-proof flags',
      ),
    );
  }

  final adaptations = record['adaptations'];
  if (adaptations is! List || adaptations.isEmpty) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.minItems',
        path: '/adaptations',
        message: 'adaptations must be a non-empty array',
      ),
    );
  } else {
    for (var i = 0; i < adaptations.length; i++) {
      final a = adaptations[i];
      if (a is! Map ||
          !_isNonEmptyString(a['id'], max: 64) ||
          a['kind'] is! String ||
          !mentorCardAdaptationKinds.contains(a['kind']) ||
          !_isNonEmptyString(a['summary'], max: 400)) {
        issues.add(
          MentorCardValidationIssue(
            code: 'schema.enum',
            path: '/adaptations/$i',
            message: 'adaptation requires id, kind, summary',
          ),
        );
      }
    }
  }

  for (final key in [
    'parent_script_before',
    'parent_prompts_during',
    'parent_prompts_after',
    'scaffold_down',
    'extend_up',
  ]) {
    if (!_isStringList(record[key], minItems: 1)) {
      issues.add(
        MentorCardValidationIssue(
          code: 'schema.minItems',
          path: '/$key',
          message: '$key must be a non-empty string array',
        ),
      );
    }
  }

  final evidence = record['evidence_refs'];
  if (evidence is! List) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.type',
        path: '/evidence_refs',
        message: 'evidence_refs must be a string array',
      ),
    );
  } else {
    for (final item in evidence) {
      if (item is! String || item.isEmpty || item.length > 128) {
        issues.add(
          const MentorCardValidationIssue(
            code: 'schema.type',
            path: '/evidence_refs',
            message: 'evidence_refs items must be non-empty strings',
          ),
        );
        break;
      }
    }
  }

  final review = record['review_status'];
  if (review is! String || !mentorCardReviewStatuses.contains(review)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.enum',
        path: '/review_status',
        message: 'review_status is not an allowed value',
      ),
    );
  }

  if (!_isNonEmptyString(record['observed_vs_suggested'], max: 600) ||
      !_isNonEmptyString(record['not_a_developmental_assessment'], max: 600)) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'schema.required',
        path: '/observed_vs_suggested',
        message: 'observed_vs_suggested and disclaimer are required',
      ),
    );
  }

  return issues;
}

List<MentorCardValidationIssue> _validateAgeRange(MentorCardV1 card) {
  if (card.ageMinMonths > card.ageMaxMonths) {
    return const [
      MentorCardValidationIssue(
        code: 'age.range_order',
        path: 'age_min_months',
        message: 'age_min_months must be <= age_max_months',
      ),
    ];
  }
  return const [];
}

List<MentorCardValidationIssue> _validateScriptConsistency(MentorCardV1 card) {
  final issues = <MentorCardValidationIssue>[];
  final pairs = <(List<String>, List<String>, String)>[
    (card.whatToSay.before, card.parentScriptBefore, 'before'),
    (card.whatToSay.during, card.parentPromptsDuring, 'during'),
    (card.whatToSay.after, card.parentPromptsAfter, 'after'),
  ];
  for (final pair in pairs) {
    if (!_listEquals(pair.$1, pair.$2)) {
      issues.add(
        MentorCardValidationIssue(
          code: 'copy.script_alias_mismatch',
          path: 'what_to_say.${pair.$3}',
          message:
              'what_to_say.${pair.$3} must match Blueprint alias array for ${pair.$3}',
        ),
      );
    }
  }
  return issues;
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Full mentor-card validation: schema version + structural + age + safe copy.
///
/// Mirrors backend `validateMentorCard` without inventing a second OpenAPI.
MentorCardValidationResult validateMentorCard(Object? payload) {
  if (payload == null || payload is! Map) {
    return const MentorCardValidationFail([
      MentorCardValidationIssue(
        code: 'schema.type',
        path: '',
        message: 'Mentor card payload must be a JSON object',
      ),
    ]);
  }

  final record = Map<String, Object?>.from(payload);
  final schemaVersion = record['schema_version'];
  if (schemaVersion != mentorCardSchemaVersion) {
    return MentorCardValidationFail([
      MentorCardValidationIssue(
        code: 'schema.version_incompatible',
        path: 'schema_version',
        message:
            'Unsupported schema_version ${schemaVersion.toString()}; expected $mentorCardSchemaVersion',
      ),
    ]);
  }

  final structural = _validateStructural(record);
  if (structural.isNotEmpty) {
    return MentorCardValidationFail(structural);
  }

  late final MentorCardV1 card;
  try {
    card = MentorCardV1.fromJson(record);
  } catch (e) {
    return MentorCardValidationFail([
      MentorCardValidationIssue(
        code: 'schema.invalid',
        path: '',
        message: 'Payload failed model parse: $e',
      ),
    ]);
  }

  final issues = <MentorCardValidationIssue>[
    ..._validateAgeRange(card),
    ..._validateScriptConsistency(card),
    ...validateMentorCardSafeCopy(card),
  ];

  if (issues.isNotEmpty) {
    return MentorCardValidationFail(issues);
  }
  return MentorCardValidationOk(card);
}

/// Hard age eligibility filter (Blueprint §4.5).
bool isMentorCardAgeApplicable(MentorCardV1 card, int ageMonths) {
  if (ageMonths < 24 || ageMonths > 71) return false;
  return ageMonths >= card.ageMinMonths && ageMonths <= card.ageMaxMonths;
}

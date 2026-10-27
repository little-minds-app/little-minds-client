/// Thin Dart model aligned with backend
/// `content/schemas/mentor-card/v1.schema.json` (LMP-47 / Blueprint F-009).
///
/// Backend owns the canonical contract. Do not invent divergent fields.
library;

const String mentorCardSchemaVersion = '1.0.0';

/// Locales shipped with V1 fixtures; schema accepts any `xx-YY` tag.
const List<String> mentorCardV1Locales = ['tr-TR', 'en-US'];

const Set<String> mentorCardInteractionStyles = {
  'warm_invitational',
  'observe_wait_respond_extend',
  'guided_play',
  'open_ended',
};

const Set<String> mentorCardAdaptationKinds = {
  'seated',
  'low_motor',
  'low_noise',
  'sensory_friendly',
  'small_space',
  'no_purchase',
  'tactile',
  'point_instead_of_move',
  'other',
};

const Set<String> mentorCardReviewStatuses = {
  'draft',
  'pedagogy_review',
  'safety_review',
  'localization_review',
  'approved',
  'staged',
  'published',
  'archived',
  'rolled_back',
};

/// Canonical Near/Far mentor card id from backend fixtures.
const String nearFarMentorCardId = 'near_far_play_mentor';

class MentorCardMaterial {
  const MentorCardMaterial({
    required this.id,
    required this.label,
    this.optional = false,
    this.householdCommon = true,
  });

  final String id;
  final String label;
  final bool optional;
  final bool householdCommon;

  factory MentorCardMaterial.fromJson(Map<String, Object?> json) {
    return MentorCardMaterial(
      id: json['id']! as String,
      label: json['label']! as String,
      optional: json['optional'] as bool? ?? false,
      householdCommon: json['household_common'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'optional': optional,
        'household_common': householdCommon,
      };
}

class MentorCardAdaptation {
  const MentorCardAdaptation({
    required this.id,
    required this.kind,
    required this.summary,
  });

  final String id;
  final String kind;
  final String summary;

  factory MentorCardAdaptation.fromJson(Map<String, Object?> json) {
    return MentorCardAdaptation(
      id: json['id']! as String,
      kind: json['kind']! as String,
      summary: json['summary']! as String,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'summary': summary,
      };
}

class MentorCardWhy {
  const MentorCardWhy({
    required this.summary,
    required this.learningIntention,
  });

  final String summary;
  final String learningIntention;

  factory MentorCardWhy.fromJson(Map<String, Object?> json) {
    return MentorCardWhy(
      summary: json['summary']! as String,
      learningIntention: json['learning_intention']! as String,
    );
  }

  Map<String, Object?> toJson() => {
        'summary': summary,
        'learning_intention': learningIntention,
      };
}

class MentorCardHow {
  const MentorCardHow({
    required this.prepSummary,
    required this.steps,
  });

  final String prepSummary;
  final List<String> steps;

  factory MentorCardHow.fromJson(Map<String, Object?> json) {
    return MentorCardHow(
      prepSummary: json['prep_summary']! as String,
      steps: (json['steps']! as List<dynamic>).cast<String>(),
    );
  }

  Map<String, Object?> toJson() => {
        'prep_summary': prepSummary,
        'steps': steps,
      };
}

class MentorCardWhatToSay {
  const MentorCardWhatToSay({
    required this.before,
    required this.during,
    required this.after,
  });

  final List<String> before;
  final List<String> during;
  final List<String> after;

  factory MentorCardWhatToSay.fromJson(Map<String, Object?> json) {
    return MentorCardWhatToSay(
      before: (json['before']! as List<dynamic>).cast<String>(),
      during: (json['during']! as List<dynamic>).cast<String>(),
      after: (json['after']! as List<dynamic>).cast<String>(),
    );
  }

  Map<String, Object?> toJson() => {
        'before': before,
        'during': during,
        'after': after,
      };
}

class MentorCardSafety {
  const MentorCardSafety({
    required this.constraints,
    required this.requiresAdultSupervision,
    required this.prohibitsProofOrPhoto,
  });

  final List<String> constraints;
  final bool requiresAdultSupervision;
  final bool prohibitsProofOrPhoto;

  factory MentorCardSafety.fromJson(Map<String, Object?> json) {
    return MentorCardSafety(
      constraints: (json['constraints']! as List<dynamic>).cast<String>(),
      requiresAdultSupervision: json['requires_adult_supervision']! as bool,
      prohibitsProofOrPhoto: json['prohibits_proof_or_photo']! as bool,
    );
  }

  Map<String, Object?> toJson() => {
        'constraints': constraints,
        'requires_adult_supervision': requiresAdultSupervision,
        'prohibits_proof_or_photo': prohibitsProofOrPhoto,
      };
}

/// Caregiver-facing mentor card document (content JSON, not a Prisma row).
class MentorCardV1 {
  const MentorCardV1({
    required this.schemaVersion,
    required this.mentorCardId,
    required this.version,
    required this.locale,
    required this.title,
    required this.ageMinMonths,
    required this.ageMaxMonths,
    required this.domains,
    required this.goals,
    required this.interactionStyle,
    required this.estimatedPrepMinutes,
    required this.estimatedScreenMinutes,
    required this.estimatedOffscreenMinutes,
    required this.materials,
    required this.why,
    required this.how,
    required this.whatToSay,
    required this.safety,
    required this.adaptations,
    required this.parentScriptBefore,
    required this.parentPromptsDuring,
    required this.parentPromptsAfter,
    required this.scaffoldDown,
    required this.extendUp,
    required this.evidenceRefs,
    required this.reviewStatus,
    required this.observedVsSuggested,
    required this.notADevelopmentalAssessment,
    this.reviewerId,
    this.reviewedAt,
    this.linkedActivityIds = const [],
    this.linkedMissionIds = const [],
    this.extensions = const {},
  });

  final String schemaVersion;
  final String mentorCardId;
  final int version;
  final String locale;
  final String title;
  final int ageMinMonths;
  final int ageMaxMonths;
  final List<String> domains;
  final List<String> goals;
  final String interactionStyle;
  final int estimatedPrepMinutes;
  final int estimatedScreenMinutes;
  final int estimatedOffscreenMinutes;
  final List<MentorCardMaterial> materials;
  final MentorCardWhy why;
  final MentorCardHow how;
  final MentorCardWhatToSay whatToSay;
  final MentorCardSafety safety;
  final List<MentorCardAdaptation> adaptations;
  final List<String> parentScriptBefore;
  final List<String> parentPromptsDuring;
  final List<String> parentPromptsAfter;
  final List<String> scaffoldDown;
  final List<String> extendUp;
  final List<String> evidenceRefs;
  final String reviewStatus;
  final String? reviewerId;
  final String? reviewedAt;
  final String observedVsSuggested;
  final String notADevelopmentalAssessment;
  final List<String> linkedActivityIds;
  final List<String> linkedMissionIds;
  final Map<String, Object?> extensions;

  factory MentorCardV1.fromJson(Map<String, Object?> json) {
    List<String> stringList(Object? value) =>
        (value as List<dynamic>? ?? const []).cast<String>();

    Map<String, Object?> asMap(Object? value) =>
        Map<String, Object?>.from(value! as Map);

    return MentorCardV1(
      schemaVersion: json['schema_version']! as String,
      mentorCardId: json['mentor_card_id']! as String,
      version: json['version']! as int,
      locale: json['locale']! as String,
      title: json['title']! as String,
      ageMinMonths: json['age_min_months']! as int,
      ageMaxMonths: json['age_max_months']! as int,
      domains: stringList(json['domains']),
      goals: stringList(json['goals']),
      interactionStyle: json['interaction_style']! as String,
      estimatedPrepMinutes: json['estimated_prep_minutes']! as int,
      estimatedScreenMinutes: json['estimated_screen_minutes']! as int,
      estimatedOffscreenMinutes: json['estimated_offscreen_minutes']! as int,
      materials: (json['materials']! as List<dynamic>)
          .map((e) => MentorCardMaterial.fromJson(asMap(e)))
          .toList(),
      why: MentorCardWhy.fromJson(asMap(json['why'])),
      how: MentorCardHow.fromJson(asMap(json['how'])),
      whatToSay: MentorCardWhatToSay.fromJson(asMap(json['what_to_say'])),
      safety: MentorCardSafety.fromJson(asMap(json['safety'])),
      adaptations: (json['adaptations']! as List<dynamic>)
          .map((e) => MentorCardAdaptation.fromJson(asMap(e)))
          .toList(),
      parentScriptBefore: stringList(json['parent_script_before']),
      parentPromptsDuring: stringList(json['parent_prompts_during']),
      parentPromptsAfter: stringList(json['parent_prompts_after']),
      scaffoldDown: stringList(json['scaffold_down']),
      extendUp: stringList(json['extend_up']),
      evidenceRefs: stringList(json['evidence_refs']),
      reviewStatus: json['review_status']! as String,
      reviewerId: json['reviewer_id'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      observedVsSuggested: json['observed_vs_suggested']! as String,
      notADevelopmentalAssessment:
          json['not_a_developmental_assessment']! as String,
      linkedActivityIds: stringList(json['linked_activity_ids']),
      linkedMissionIds: stringList(json['linked_mission_ids']),
      extensions: json['extensions'] == null
          ? const {}
          : Map<String, Object?>.from(json['extensions']! as Map),
    );
  }

  Map<String, Object?> toJson() => {
        'schema_version': schemaVersion,
        'mentor_card_id': mentorCardId,
        'version': version,
        'locale': locale,
        'title': title,
        'age_min_months': ageMinMonths,
        'age_max_months': ageMaxMonths,
        'domains': domains,
        'goals': goals,
        'interaction_style': interactionStyle,
        'estimated_prep_minutes': estimatedPrepMinutes,
        'estimated_screen_minutes': estimatedScreenMinutes,
        'estimated_offscreen_minutes': estimatedOffscreenMinutes,
        'materials': materials.map((m) => m.toJson()).toList(),
        'why': why.toJson(),
        'how': how.toJson(),
        'what_to_say': whatToSay.toJson(),
        'safety': safety.toJson(),
        'adaptations': adaptations.map((a) => a.toJson()).toList(),
        'parent_script_before': parentScriptBefore,
        'parent_prompts_during': parentPromptsDuring,
        'parent_prompts_after': parentPromptsAfter,
        'scaffold_down': scaffoldDown,
        'extend_up': extendUp,
        'evidence_refs': evidenceRefs,
        'review_status': reviewStatus,
        'reviewer_id': reviewerId,
        'reviewed_at': reviewedAt,
        'observed_vs_suggested': observedVsSuggested,
        'not_a_developmental_assessment': notADevelopmentalAssessment,
        if (linkedActivityIds.isNotEmpty)
          'linked_activity_ids': linkedActivityIds,
        if (linkedMissionIds.isNotEmpty) 'linked_mission_ids': linkedMissionIds,
        if (extensions.isNotEmpty) 'extensions': extensions,
      };

  MentorCardV1 copyWith({
    String? schemaVersion,
    String? mentorCardId,
    int? version,
    String? locale,
    String? title,
    int? ageMinMonths,
    int? ageMaxMonths,
    List<String>? domains,
    List<String>? goals,
    String? interactionStyle,
    int? estimatedPrepMinutes,
    int? estimatedScreenMinutes,
    int? estimatedOffscreenMinutes,
    List<MentorCardMaterial>? materials,
    MentorCardWhy? why,
    MentorCardHow? how,
    MentorCardWhatToSay? whatToSay,
    MentorCardSafety? safety,
    List<MentorCardAdaptation>? adaptations,
    List<String>? parentScriptBefore,
    List<String>? parentPromptsDuring,
    List<String>? parentPromptsAfter,
    List<String>? scaffoldDown,
    List<String>? extendUp,
    List<String>? evidenceRefs,
    String? reviewStatus,
    String? reviewerId,
    String? reviewedAt,
    String? observedVsSuggested,
    String? notADevelopmentalAssessment,
    List<String>? linkedActivityIds,
    List<String>? linkedMissionIds,
    Map<String, Object?>? extensions,
  }) {
    return MentorCardV1(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      mentorCardId: mentorCardId ?? this.mentorCardId,
      version: version ?? this.version,
      locale: locale ?? this.locale,
      title: title ?? this.title,
      ageMinMonths: ageMinMonths ?? this.ageMinMonths,
      ageMaxMonths: ageMaxMonths ?? this.ageMaxMonths,
      domains: domains ?? this.domains,
      goals: goals ?? this.goals,
      interactionStyle: interactionStyle ?? this.interactionStyle,
      estimatedPrepMinutes: estimatedPrepMinutes ?? this.estimatedPrepMinutes,
      estimatedScreenMinutes:
          estimatedScreenMinutes ?? this.estimatedScreenMinutes,
      estimatedOffscreenMinutes:
          estimatedOffscreenMinutes ?? this.estimatedOffscreenMinutes,
      materials: materials ?? this.materials,
      why: why ?? this.why,
      how: how ?? this.how,
      whatToSay: whatToSay ?? this.whatToSay,
      safety: safety ?? this.safety,
      adaptations: adaptations ?? this.adaptations,
      parentScriptBefore: parentScriptBefore ?? this.parentScriptBefore,
      parentPromptsDuring: parentPromptsDuring ?? this.parentPromptsDuring,
      parentPromptsAfter: parentPromptsAfter ?? this.parentPromptsAfter,
      scaffoldDown: scaffoldDown ?? this.scaffoldDown,
      extendUp: extendUp ?? this.extendUp,
      evidenceRefs: evidenceRefs ?? this.evidenceRefs,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      observedVsSuggested: observedVsSuggested ?? this.observedVsSuggested,
      notADevelopmentalAssessment:
          notADevelopmentalAssessment ?? this.notADevelopmentalAssessment,
      linkedActivityIds: linkedActivityIds ?? this.linkedActivityIds,
      linkedMissionIds: linkedMissionIds ?? this.linkedMissionIds,
      extensions: extensions ?? this.extensions,
    );
  }
}

class MentorCardValidationIssue {
  const MentorCardValidationIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;
}

sealed class MentorCardValidationResult {
  const MentorCardValidationResult();
}

final class MentorCardValidationOk extends MentorCardValidationResult {
  const MentorCardValidationOk(this.card);
  final MentorCardV1 card;
}

final class MentorCardValidationFail extends MentorCardValidationResult {
  const MentorCardValidationFail(this.issues);
  final List<MentorCardValidationIssue> issues;
}

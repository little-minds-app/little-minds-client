import 'mentor_card.dart';

/// Safe-copy policy mirror of backend `mentor-card.safe-copy.ts` (LMP-47).
///
/// Blueprint §4.3 coaching rules and §5.2 no proof/photo.
class _ForbiddenRule {
  const _ForbiddenRule({
    required this.code,
    required this.pattern,
    required this.message,
  });

  final String code;
  final RegExp pattern;
  final String message;
}

const _diagnosticScanSkipPaths = {'not_a_developmental_assessment'};

final _forbiddenRules = <_ForbiddenRule>[
  _ForbiddenRule(
    code: 'safe_copy.coercive_must',
    pattern: RegExp(
      r'\byou must\b|\bmust complete\b|\bzorunlu\b|\bher gün tamamla\b',
      caseSensitive: false,
    ),
    message: 'Coercive duty language is not allowed',
  ),
  _ForbiddenRule(
    code: 'safe_copy.comparative_judgment',
    pattern: RegExp(
      r'\bbehind\b|\bshould be able\b|\bgeride\b|\byapabilmeli\b|\byapması gerekir\b',
      caseSensitive: false,
    ),
    message: 'Comparative / deficit judgment language is not allowed',
  ),
  _ForbiddenRule(
    code: 'safe_copy.unlock_manipulation',
    pattern: RegExp(
      r'\bunlock development\b|\bkeep playing to unlock\b',
      caseSensitive: false,
    ),
    message: 'Manipulative unlock language is not allowed',
  ),
  _ForbiddenRule(
    code: 'safe_copy.proof_or_photo',
    pattern: RegExp(
      r'\bphoto proof\b|\btake a photo\b|\bvideo proof\b|\bupload (a |the )?(picture|photo|video)\b|\bfotoğraf çek\b|\bfotograf cek\b|\bkanıt yükle\b|\bkanit yukle\b|\bsend (a |the )?photo\b',
      caseSensitive: false,
    ),
    message: 'Proof / photo / video capture requirements are not allowed',
  ),
  _ForbiddenRule(
    code: 'safe_copy.diagnostic_claim',
    pattern: RegExp(
      r'\bdiagnos|\bIQ\b|\bdevelopmental disorder\b|\btanı koy\b|\btani koy\b|\bgelişim bozukluğu\b|\bgelisim bozuklugu\b',
      caseSensitive: false,
    ),
    message: 'Diagnostic or clinical claim language is not allowed',
  ),
];

final _adultSupervisionPattern = RegExp(
  r'adult supervision|yetişkin gözetimi|yetiskin gozetimi',
  caseSensitive: false,
);

List<({String path, String value})> _collectCopyStrings(MentorCardV1 card) {
  final out = <({String path, String value})>[];
  void push(String path, String value) => out.add((path: path, value: value));

  push('title', card.title);
  push('why.summary', card.why.summary);
  push('why.learning_intention', card.why.learningIntention);
  push('how.prep_summary', card.how.prepSummary);
  for (var i = 0; i < card.how.steps.length; i++) {
    push('how.steps[$i]', card.how.steps[i]);
  }
  for (var i = 0; i < card.whatToSay.before.length; i++) {
    push('what_to_say.before[$i]', card.whatToSay.before[i]);
  }
  for (var i = 0; i < card.whatToSay.during.length; i++) {
    push('what_to_say.during[$i]', card.whatToSay.during[i]);
  }
  for (var i = 0; i < card.whatToSay.after.length; i++) {
    push('what_to_say.after[$i]', card.whatToSay.after[i]);
  }
  for (var i = 0; i < card.safety.constraints.length; i++) {
    push('safety.constraints[$i]', card.safety.constraints[i]);
  }
  for (var i = 0; i < card.adaptations.length; i++) {
    push('adaptations[$i].summary', card.adaptations[i].summary);
  }
  for (var i = 0; i < card.parentScriptBefore.length; i++) {
    push('parent_script_before[$i]', card.parentScriptBefore[i]);
  }
  for (var i = 0; i < card.parentPromptsDuring.length; i++) {
    push('parent_prompts_during[$i]', card.parentPromptsDuring[i]);
  }
  for (var i = 0; i < card.parentPromptsAfter.length; i++) {
    push('parent_prompts_after[$i]', card.parentPromptsAfter[i]);
  }
  for (var i = 0; i < card.scaffoldDown.length; i++) {
    push('scaffold_down[$i]', card.scaffoldDown[i]);
  }
  for (var i = 0; i < card.extendUp.length; i++) {
    push('extend_up[$i]', card.extendUp[i]);
  }
  push('observed_vs_suggested', card.observedVsSuggested);
  push('not_a_developmental_assessment', card.notADevelopmentalAssessment);
  for (var i = 0; i < card.materials.length; i++) {
    push('materials[$i].label', card.materials[i].label);
  }
  return out;
}

/// Returns policy issues for an already schema-shaped card.
List<MentorCardValidationIssue> validateMentorCardSafeCopy(MentorCardV1 card) {
  final issues = <MentorCardValidationIssue>[];

  if (card.safety.requiresAdultSupervision != true) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'safe_copy.adult_supervision_flag',
        path: 'safety.requires_adult_supervision',
        message: 'requires_adult_supervision must be true',
      ),
    );
  }

  if (card.safety.prohibitsProofOrPhoto != true) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'safe_copy.no_proof_flag',
        path: 'safety.prohibits_proof_or_photo',
        message: 'prohibits_proof_or_photo must be true',
      ),
    );
  }

  final hasSupervisionMention = card.safety.constraints.any(
    (c) => _adultSupervisionPattern.hasMatch(c),
  );
  if (!hasSupervisionMention) {
    issues.add(
      const MentorCardValidationIssue(
        code: 'safe_copy.adult_supervision_copy',
        path: 'safety.constraints',
        message:
            'At least one safety constraint must mention adult supervision (locale-aware)',
      ),
    );
  }

  for (final entry in _collectCopyStrings(card)) {
    for (final rule in _forbiddenRules) {
      if (rule.code == 'safe_copy.diagnostic_claim' &&
          _diagnosticScanSkipPaths.contains(entry.path)) {
        continue;
      }
      if (rule.pattern.hasMatch(entry.value)) {
        issues.add(
          MentorCardValidationIssue(
            code: rule.code,
            path: entry.path,
            message: rule.message,
          ),
        );
      }
    }
  }

  return issues;
}

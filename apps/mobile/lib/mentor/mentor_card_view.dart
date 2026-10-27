import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'mentor_card.dart';
import 'mentor_card_review.dart';
import 'mentor_card_validator.dart';

/// Reusable Parent Play Mentor card body (LMP-48 / Blueprint F-009).
///
/// Binds coaching copy from [MentorCardV1] (fixture / reviewed content) — never
/// hardcodes before/during/after scripts in ARB. Chrome labels come from
/// [AppLocalizations].
///
/// **Review gate:** caregiver-ready rendering requires
/// [MentorCardReviewGate.mayRenderOnParentMentorSurface]. Draft fixtures stay
/// blocked unless [allowDraftPreview] is true (dev/test only). Preview still
/// shows an explicit draft banner and never claims approved status.
class MentorCardView extends StatelessWidget {
  const MentorCardView({
    super.key,
    required this.card,
    this.childAgeMonths,
    this.allowDraftPreview = false,
  });

  final MentorCardV1 card;

  /// Optional child age for applicability messaging (Blueprint age filter).
  final int? childAgeMonths;

  /// Dev/test-only: render draft/non-approved copy with an explicit banner.
  /// Production parent surfaces must leave this `false`.
  final bool allowDraftPreview;

  static const Key viewKey = Key('mentor-card-view');
  static const Key titleKey = Key('mentor-card-title');
  static const Key draftBannerKey = Key('mentor-card-draft-banner');
  static const Key blockedKey = Key('mentor-card-blocked');
  static const Key ageKey = Key('mentor-card-age');
  static const Key whyKey = Key('mentor-card-why');
  static const Key howKey = Key('mentor-card-how');
  static const Key whatToSayKey = Key('mentor-card-what-to-say');
  static const Key whatBeforeKey = Key('mentor-card-what-before');
  static const Key whatDuringKey = Key('mentor-card-what-during');
  static const Key whatAfterKey = Key('mentor-card-what-after');
  static const Key safetyKey = Key('mentor-card-safety');
  static const Key adaptationsKey = Key('mentor-card-adaptations');
  static const Key observedKey = Key('mentor-card-observed-vs-suggested');
  static const Key disclaimerKey = Key('mentor-card-not-assessment');

  bool get _caregiverReady =>
      MentorCardReviewGate.mayRenderOnParentMentorSurface(card);

  bool get _showContent => _caregiverReady || allowDraftPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: l10n.mentorCardSemanticsLabel(card.title),
      child: KeyedSubtree(
        key: viewKey,
        child: _showContent
            ? _MentorCardBody(
                card: card,
                childAgeMonths: childAgeMonths,
                showDraftBanner: !_caregiverReady && allowDraftPreview,
                l10n: l10n,
                theme: theme,
              )
            : _MentorCardBlocked(
                card: card,
                l10n: l10n,
                theme: theme,
              ),
      ),
    );
  }
}

class _MentorCardBlocked extends StatelessWidget {
  const _MentorCardBlocked({
    required this.card,
    required this.l10n,
    required this.theme,
  });

  final MentorCardV1 card;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: MentorCardView.blockedKey,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mentorCardNotApprovedTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mentorCardNotApprovedBody(card.reviewStatus),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MentorCardBody extends StatelessWidget {
  const _MentorCardBody({
    required this.card,
    required this.childAgeMonths,
    required this.showDraftBanner,
    required this.l10n,
    required this.theme,
  });

  final MentorCardV1 card;
  final int? childAgeMonths;
  final bool showDraftBanner;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final before = card.whatToSay.before.isNotEmpty
        ? card.whatToSay.before
        : card.parentScriptBefore;
    final during = card.whatToSay.during.isNotEmpty
        ? card.whatToSay.during
        : card.parentPromptsDuring;
    final after = card.whatToSay.after.isNotEmpty
        ? card.whatToSay.after
        : card.parentPromptsAfter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDraftBanner) ...[
          Semantics(
            liveRegion: true,
            child: Material(
              key: MentorCardView.draftBannerKey,
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  l10n.mentorCardDraftPreviewBanner,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          key: MentorCardView.titleKey,
          card.title,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _AgeApplicability(
          card: card,
          childAgeMonths: childAgeMonths,
          l10n: l10n,
          theme: theme,
        ),
        const SizedBox(height: 20),
        _Section(
          key: MentorCardView.whyKey,
          title: l10n.mentorCardSectionWhy,
          children: [
            Text(card.why.summary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              card.why.learningIntention,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        _Section(
          key: MentorCardView.howKey,
          title: l10n.mentorCardSectionHow,
          children: [
            Text(card.how.prepSummary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 10),
            ..._bulletList(card.how.steps, theme),
          ],
        ),
        _Section(
          key: MentorCardView.whatToSayKey,
          title: l10n.mentorCardSectionWhatToSay,
          children: [
            _SubSection(
              key: MentorCardView.whatBeforeKey,
              title: l10n.mentorCardWhatBefore,
              lines: before,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _SubSection(
              key: MentorCardView.whatDuringKey,
              title: l10n.mentorCardWhatDuring,
              lines: during,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _SubSection(
              key: MentorCardView.whatAfterKey,
              title: l10n.mentorCardWhatAfter,
              lines: after,
              theme: theme,
            ),
          ],
        ),
        _Section(
          key: MentorCardView.safetyKey,
          title: l10n.mentorCardSectionSafety,
          children: [
            ..._bulletList(card.safety.constraints, theme),
            if (card.safety.requiresAdultSupervision) ...[
              const SizedBox(height: 8),
              Text(
                l10n.mentorCardSafetyAdultRequired,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (card.safety.prohibitsProofOrPhoto) ...[
              const SizedBox(height: 6),
              Text(
                l10n.mentorCardSafetyNoProof,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        _Section(
          key: MentorCardView.adaptationsKey,
          title: l10n.mentorCardSectionAdaptations,
          children: [
            for (final adaptation in card.adaptations) ...[
              Text(
                adaptation.summary,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
        _Section(
          key: MentorCardView.observedKey,
          title: l10n.mentorCardSectionObserved,
          children: [
            Text(card.observedVsSuggested, style: theme.textTheme.bodyLarge),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            key: MentorCardView.disclaimerKey,
            card.notADevelopmentalAssessment,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  static List<Widget> _bulletList(List<String> lines, ThemeData theme) {
    return [
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: theme.textTheme.bodyLarge),
              Expanded(
                child: Text(line, style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
        ),
    ];
  }
}

class _AgeApplicability extends StatelessWidget {
  const _AgeApplicability({
    required this.card,
    required this.childAgeMonths,
    required this.l10n,
    required this.theme,
  });

  final MentorCardV1 card;
  final int? childAgeMonths;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final ageLine = l10n.mentorCardAgeRange(card.ageMinMonths, card.ageMaxMonths);
    final applicability = childAgeMonths == null
        ? null
        : isMentorCardAgeApplicable(card, childAgeMonths!)
            ? l10n.mentorCardAgeFits
            : l10n.mentorCardAgeOutside;

    return Semantics(
      label: applicability == null ? ageLine : '$ageLine. $applicability',
      child: Column(
        key: MentorCardView.ageKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ageLine,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (applicability != null) ...[
            const SizedBox(height: 4),
            Text(
              applicability,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SubSection extends StatelessWidget {
  const _SubSection({
    super.key,
    required this.title,
    required this.lines,
    required this.theme,
  });

  final String title;
  final List<String> lines;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: theme.textTheme.bodyLarge),
                Expanded(
                  child: Text(line, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

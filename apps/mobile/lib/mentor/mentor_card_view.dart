import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../near_far/near_far_constants.dart';
import 'mentor_card.dart';
import 'mentor_card_near_far_links.dart';
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
///
/// Optional [onOpenMission] opens the existing Near/Far mission flow when
/// [MentorCardNearFarLinks.resolveMissionId] resolves — never a duplicate
/// mission UI.
class MentorCardView extends StatelessWidget {
  const MentorCardView({
    super.key,
    required this.card,
    this.childAgeMonths,
    this.allowDraftPreview = false,
    this.onOpenMission,
  });

  final MentorCardV1 card;

  /// Optional child age for applicability messaging (Blueprint age filter).
  final int? childAgeMonths;

  /// Dev/test-only: render draft/non-approved copy with an explicit banner.
  /// Production parent surfaces must leave this `false`.
  final bool allowDraftPreview;

  /// Opens the existing Near/Far real-world mission flow (LMP-45/46 demo).
  /// Shown only when content is visible and the card links the canonical
  /// mission id (`near_far_sock_soft_toy_v1`).
  final VoidCallback? onOpenMission;

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
  static const Key openMissionKey = Key('mentor-card-open-mission');
  static const Key openMissionHintKey = Key('mentor-card-open-mission-hint');

  bool get _caregiverReady =>
      MentorCardReviewGate.mayRenderOnParentMentorSurface(card);

  bool get _showContent => _caregiverReady || allowDraftPreview;

  /// Mission CTA only when the card links the canonical Near/Far mission.
  bool get _canOfferMission {
    if (onOpenMission == null || !_showContent) return false;
    return MentorCardNearFarLinks.resolveMissionId(card) ==
        NearFarConstants.missionId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      key: viewKey,
      container: true,
      label: l10n.mentorCardSemanticsLabel(card.title),
      child: _showContent
          ? _MentorCardBody(
              card: card,
              childAgeMonths: childAgeMonths,
              showDraftBanner: !_caregiverReady && allowDraftPreview,
              showMissionAction: _canOfferMission,
              onOpenMission: onOpenMission,
              l10n: l10n,
              theme: theme,
            )
          : _MentorCardBlocked(
              card: card,
              l10n: l10n,
              theme: theme,
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
    required this.showMissionAction,
    required this.onOpenMission,
    required this.l10n,
    required this.theme,
  });

  final MentorCardV1 card;
  final int? childAgeMonths;
  final bool showDraftBanner;
  final bool showMissionAction;
  final VoidCallback? onOpenMission;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            _ExpandablePromptTile(
              key: MentorCardView.whatBeforeKey,
              title: l10n.mentorCardWhatBefore,
              lines: before,
              theme: theme,
            ),
            _ExpandablePromptTile(
              key: MentorCardView.whatDuringKey,
              title: l10n.mentorCardWhatDuring,
              lines: during,
              theme: theme,
            ),
            _ExpandablePromptTile(
              key: MentorCardView.whatAfterKey,
              title: l10n.mentorCardWhatAfter,
              lines: after,
              theme: theme,
            ),
          ],
        ),
        // Safety is never collapsed — always visible for caregivers.
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
        if (showMissionAction && onOpenMission != null) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 200),
            child: FilledButton(
              key: MentorCardView.openMissionKey,
              onPressed: onOpenMission,
              child: Text(l10n.mentorCardOpenMission),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            key: MentorCardView.openMissionHintKey,
            l10n.mentorCardOpenMissionHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
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
    final ageLine =
        l10n.mentorCardAgeRange(card.ageMinMonths, card.ageMaxMonths);
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

/// Collapsed-by-default Before/During/After prompts (accessible ExpansionTile).
class _ExpandablePromptTile extends StatelessWidget {
  const _ExpandablePromptTile({
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
    return Semantics(
      explicitChildNodes: true,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
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
      ),
    );
  }
}

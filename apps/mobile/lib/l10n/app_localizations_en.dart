// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Little Minds';

  @override
  String get hubGreeting => 'Let\'s play!';

  @override
  String get hubSubtitle => 'Pick a calm activity.';

  @override
  String get hubEmptyPlayable => 'New games are on the way.';

  @override
  String get hubPassiveBadge => 'Coming Soon';

  @override
  String get hubPassiveHint => 'Not ready yet';

  @override
  String get hubPlayableHint => 'Play';

  @override
  String get hubParentExit => 'Grown-ups';

  @override
  String get hubProfiles => 'Profiles';

  @override
  String get hubProfilesHint => 'Choose who is playing. No fake profiles here.';

  @override
  String get hubAudioWelcomeCue => 'Welcome to Little Minds';

  @override
  String get hubAudioPassiveCue => 'This game is coming soon';

  @override
  String get hubAudioPlayableCue => 'Let\'s play';

  @override
  String get hubAudioParentExitCue => 'Opening grown-ups gate';

  @override
  String hubCarouselPageLabel(int current, int total) {
    return 'Activity $current of $total';
  }

  @override
  String hubCarouselDotLabel(int index) {
    return 'Go to activity $index';
  }

  @override
  String get activityShapeMatching => 'Shape Matching';

  @override
  String get activityColorSorting => 'Color Sorting';

  @override
  String get activityAnimalSounds => 'Animal Sounds';

  @override
  String get activityCounting => 'Counting';

  @override
  String get activityMemoryMatching => 'Memory Matching';

  @override
  String get activityObjectCategories => 'Object Categories';

  @override
  String get flameHostReady => 'Flame host ready';

  @override
  String get flameRegistryEmpty => 'Activity registry empty';

  @override
  String flameRegistryCount(int count) {
    return '$count activities registered';
  }

  @override
  String get activityBackToHub => 'Back';

  @override
  String get activityPause => 'Pause';

  @override
  String get activityResume => 'Resume';

  @override
  String get activityRestart => 'Start again';

  @override
  String get activitySessionUnavailable =>
      'This activity is not ready offline yet.';

  @override
  String get activityPhaseIdle => 'Ready';

  @override
  String get activityPhasePreparing => 'Getting ready';

  @override
  String get activityPhasePlaying => 'Playing';

  @override
  String get activityPhasePaused => 'Paused';

  @override
  String get activityPhaseBackground => 'Waiting';

  @override
  String get activityPhaseCompleted => 'Nice work';

  @override
  String get nearFarTitle => 'Near and Far';

  @override
  String get nearFarBack => 'Back';

  @override
  String get nearFarDemoEntry => 'Temporary Near/Far demo (dev)';

  @override
  String get nearFarDemoEntryHint =>
      'Opens a temporary Slice B demo. Parent Gate here is a placeholder — not secure sign-in yet.';

  @override
  String get nearFarPromptNear => 'Move the sock and soft toy near each other.';

  @override
  String get nearFarPromptFar => 'Now move them far apart.';

  @override
  String get nearFarPromptDone => 'Nice exploring!';

  @override
  String get nearFarLabelNear => 'Near';

  @override
  String get nearFarLabelFar => 'Far';

  @override
  String get nearFarLabelNeither => 'Keep moving';

  @override
  String get nearFarSockLabel => 'Sock';

  @override
  String get nearFarSoftToyLabel => 'Soft toy';

  @override
  String get nearFarMissionTitle => 'Try it in the room';

  @override
  String get nearFarMissionBody =>
      'Ask a grown-up for one sock and one soft toy. Put them near, then far. Talk about what changed.';

  @override
  String get nearFarMissionMaterials =>
      'Materials: one sock, one soft toy. Adult supervision. No glass or small choking hazards.';

  @override
  String get nearFarMissionTry => 'Try together';

  @override
  String get nearFarMissionOpen => 'Try together';

  @override
  String get nearFarMissionSkip => 'Skip';

  @override
  String get nearFarMissionDone => 'We\'re done';

  @override
  String get nearFarMissionStepsTitle => 'Explore near and far';

  @override
  String get nearFarMissionOpenedConfirm =>
      'With a grown-up, explore near and far using a sock and a soft toy.';

  @override
  String get nearFarMissionStep1 =>
      'Ask a grown-up for one sock and one soft toy.';

  @override
  String get nearFarMissionStep2 => 'Put them near each other.';

  @override
  String get nearFarMissionStep3 => 'Now put them far apart.';

  @override
  String get nearFarMissionStep4 =>
      'Talk about what changed. Pointing is okay too.';

  @override
  String get nearFarMissionSkipped => 'That\'s okay. You can try another time.';

  @override
  String get nearFarMissionCompleted => 'Nice exploring together.';

  @override
  String get nearFarMissionLater => 'Maybe later';

  @override
  String get nearFarMissionBack => 'Back';

  @override
  String get nearFarSpokenAssetsBlocked =>
      'Spoken near/far audio is blocked until approved offline voice packs and a working player are installed. On-screen labels still work.';

  @override
  String get mentorCardSurfaceTitle => 'Parent Play Mentor';

  @override
  String get mentorCardBack => 'Back';

  @override
  String get mentorCardSettingsEntry => 'Near/Far mentor card';

  @override
  String get mentorCardSettingsEntryHint =>
      'Caregiver coaching for near and far play. Draft content stays behind the review gate.';

  @override
  String get mentorCardSectionWhy => 'Why';

  @override
  String get mentorCardSectionHow => 'How';

  @override
  String get mentorCardSectionWhatToSay => 'What to say';

  @override
  String get mentorCardWhatBefore => 'Before';

  @override
  String get mentorCardWhatDuring => 'During';

  @override
  String get mentorCardWhatAfter => 'After';

  @override
  String get mentorCardSectionSafety => 'Safety';

  @override
  String get mentorCardSectionAdaptations => 'Adaptations';

  @override
  String get mentorCardSectionObserved => 'Observed vs suggested';

  @override
  String mentorCardAgeRange(int minMonths, int maxMonths) {
    return 'For children aged $minMonths–$maxMonths months';
  }

  @override
  String get mentorCardAgeFits => 'Fits this child’s age.';

  @override
  String get mentorCardAgeOutside => 'Outside this card’s age range.';

  @override
  String get mentorCardSafetyAdultRequired => 'Adult supervision is required.';

  @override
  String get mentorCardSafetyNoProof => 'No photos or proof are required.';

  @override
  String get mentorCardDraftPreviewBanner =>
      'Draft preview — not approved caregiver guidance.';

  @override
  String get mentorCardNotApprovedTitle => 'Guidance not ready yet';

  @override
  String mentorCardNotApprovedBody(String status) {
    return 'This mentor card is still in “$status” review and is not approved for caregivers.';
  }

  @override
  String get mentorCardLoading => 'Loading mentor guidance';

  @override
  String get mentorCardLoadError =>
      'Mentor guidance could not be loaded. Try again.';

  @override
  String get mentorCardRetry => 'Try again';

  @override
  String mentorCardSemanticsLabel(String title) {
    return 'Parent Play Mentor card: $title';
  }

  @override
  String get mentorCardOpenMission => 'Try the near and far mission';

  @override
  String get mentorCardOpenMissionHint =>
      'Opens the existing Near/Far play and real-world mission. You can skip anytime. No photos or proof.';
}

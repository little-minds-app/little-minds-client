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
  String get nearFarDemoEntry => 'Try Near/Far demo';

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
  String get nearFarMissionOpen => 'Open invitation';

  @override
  String get nearFarMissionLater => 'Maybe later';

  @override
  String get nearFarSpokenAssetsBlocked =>
      'Spoken near/far audio packs are not installed yet. On-screen labels still work.';
}

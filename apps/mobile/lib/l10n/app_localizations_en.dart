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
  String get hubSubtitle =>
      'Choose something calm and fun. Grown-ups can leave safely.';

  @override
  String get hubEmptyPlayable =>
      'No games are ready to play yet. Soft tiles below are coming soon.';

  @override
  String get hubPassiveBadge => 'Soon';

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
  String get activityShapeMatching => 'Shape matching';

  @override
  String get activityColorSorting => 'Color sorting';

  @override
  String get activityAnimalSounds => 'Animal sounds';

  @override
  String get activityCounting => 'Counting';

  @override
  String get activityMemoryMatching => 'Memory matching';

  @override
  String get activityObjectCategories => 'Object categories';

  @override
  String get flameHostReady => 'Flame host ready';

  @override
  String get flameRegistryEmpty => 'Activity registry empty';

  @override
  String flameRegistryCount(int count) {
    return '$count activities registered';
  }
}

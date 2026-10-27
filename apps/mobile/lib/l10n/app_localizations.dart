import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Little Minds'**
  String get appTitle;

  /// Short Child Hub greeting under the brand.
  ///
  /// In en, this message translates to:
  /// **'Let\'s play!'**
  String get hubGreeting;

  /// No description provided for @hubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a calm activity.'**
  String get hubSubtitle;

  /// No description provided for @hubEmptyPlayable.
  ///
  /// In en, this message translates to:
  /// **'New games are on the way.'**
  String get hubEmptyPlayable;

  /// No description provided for @hubPassiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get hubPassiveBadge;

  /// No description provided for @hubPassiveHint.
  ///
  /// In en, this message translates to:
  /// **'Not ready yet'**
  String get hubPassiveHint;

  /// No description provided for @hubPlayableHint.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get hubPlayableHint;

  /// Accessible label for the safe Parent Gate exit control.
  ///
  /// In en, this message translates to:
  /// **'Grown-ups'**
  String get hubParentExit;

  /// No description provided for @hubProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get hubProfiles;

  /// No description provided for @hubProfilesHint.
  ///
  /// In en, this message translates to:
  /// **'Choose who is playing. No fake profiles here.'**
  String get hubProfilesHint;

  /// No description provided for @hubAudioWelcomeCue.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Little Minds'**
  String get hubAudioWelcomeCue;

  /// No description provided for @hubAudioPassiveCue.
  ///
  /// In en, this message translates to:
  /// **'This game is coming soon'**
  String get hubAudioPassiveCue;

  /// No description provided for @hubAudioPlayableCue.
  ///
  /// In en, this message translates to:
  /// **'Let\'s play'**
  String get hubAudioPlayableCue;

  /// No description provided for @hubAudioParentExitCue.
  ///
  /// In en, this message translates to:
  /// **'Opening grown-ups gate'**
  String get hubAudioParentExitCue;

  /// No description provided for @hubCarouselPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity {current} of {total}'**
  String hubCarouselPageLabel(int current, int total);

  /// No description provided for @hubCarouselDotLabel.
  ///
  /// In en, this message translates to:
  /// **'Go to activity {index}'**
  String hubCarouselDotLabel(int index);

  /// No description provided for @activityShapeMatching.
  ///
  /// In en, this message translates to:
  /// **'Shape Matching'**
  String get activityShapeMatching;

  /// No description provided for @activityColorSorting.
  ///
  /// In en, this message translates to:
  /// **'Color Sorting'**
  String get activityColorSorting;

  /// No description provided for @activityAnimalSounds.
  ///
  /// In en, this message translates to:
  /// **'Animal Sounds'**
  String get activityAnimalSounds;

  /// No description provided for @activityCounting.
  ///
  /// In en, this message translates to:
  /// **'Counting'**
  String get activityCounting;

  /// No description provided for @activityMemoryMatching.
  ///
  /// In en, this message translates to:
  /// **'Memory Matching'**
  String get activityMemoryMatching;

  /// No description provided for @activityObjectCategories.
  ///
  /// In en, this message translates to:
  /// **'Object Categories'**
  String get activityObjectCategories;

  /// No description provided for @flameHostReady.
  ///
  /// In en, this message translates to:
  /// **'Flame host ready'**
  String get flameHostReady;

  /// No description provided for @flameRegistryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Activity registry empty'**
  String get flameRegistryEmpty;

  /// No description provided for @flameRegistryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} activities registered'**
  String flameRegistryCount(int count);

  /// Safe return from mini-game host to Child Hub.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get activityBackToHub;

  /// No description provided for @activityPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get activityPause;

  /// No description provided for @activityResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get activityResume;

  /// No description provided for @activityRestart.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get activityRestart;

  /// No description provided for @activitySessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This activity is not ready offline yet.'**
  String get activitySessionUnavailable;

  /// No description provided for @activityPhaseIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get activityPhaseIdle;

  /// No description provided for @activityPhasePreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting ready'**
  String get activityPhasePreparing;

  /// No description provided for @activityPhasePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get activityPhasePlaying;

  /// No description provided for @activityPhasePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get activityPhasePaused;

  /// No description provided for @activityPhaseBackground.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get activityPhaseBackground;

  /// No description provided for @activityPhaseCompleted.
  ///
  /// In en, this message translates to:
  /// **'Nice work'**
  String get activityPhaseCompleted;

  /// Near/Far Slice B demo title (LMP-45).
  ///
  /// In en, this message translates to:
  /// **'Near and Far'**
  String get nearFarTitle;

  /// No description provided for @nearFarBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get nearFarBack;

  /// Temporary developer/demo entry on Parent Settings placeholder. Does not imply a secure authenticated Parent Gate — real auth is not implemented yet. Not Child Hub nav.
  ///
  /// In en, this message translates to:
  /// **'Temporary Near/Far demo (dev)'**
  String get nearFarDemoEntry;

  /// Clarifies that Parent Settings / Gate are scaffolding, not authenticated caregiver security.
  ///
  /// In en, this message translates to:
  /// **'Opens a temporary Slice B demo. Parent Gate here is a placeholder — not secure sign-in yet.'**
  String get nearFarDemoEntryHint;

  /// No description provided for @nearFarPromptNear.
  ///
  /// In en, this message translates to:
  /// **'Move the sock and soft toy near each other.'**
  String get nearFarPromptNear;

  /// No description provided for @nearFarPromptFar.
  ///
  /// In en, this message translates to:
  /// **'Now move them far apart.'**
  String get nearFarPromptFar;

  /// No description provided for @nearFarPromptDone.
  ///
  /// In en, this message translates to:
  /// **'Nice exploring!'**
  String get nearFarPromptDone;

  /// No description provided for @nearFarLabelNear.
  ///
  /// In en, this message translates to:
  /// **'Near'**
  String get nearFarLabelNear;

  /// No description provided for @nearFarLabelFar.
  ///
  /// In en, this message translates to:
  /// **'Far'**
  String get nearFarLabelFar;

  /// No description provided for @nearFarLabelNeither.
  ///
  /// In en, this message translates to:
  /// **'Keep moving'**
  String get nearFarLabelNeither;

  /// No description provided for @nearFarSockLabel.
  ///
  /// In en, this message translates to:
  /// **'Sock'**
  String get nearFarSockLabel;

  /// No description provided for @nearFarSoftToyLabel.
  ///
  /// In en, this message translates to:
  /// **'Soft toy'**
  String get nearFarSoftToyLabel;

  /// No description provided for @nearFarMissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Try it in the room'**
  String get nearFarMissionTitle;

  /// No description provided for @nearFarMissionBody.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up for one sock and one soft toy. Put them near, then far. Talk about what changed.'**
  String get nearFarMissionBody;

  /// No description provided for @nearFarMissionMaterials.
  ///
  /// In en, this message translates to:
  /// **'Materials: one sock, one soft toy. Adult supervision. No glass or small choking hazards.'**
  String get nearFarMissionMaterials;

  /// Primary Start/Try action for optional real-world mission (LMP-46). No proof or photo.
  ///
  /// In en, this message translates to:
  /// **'Try together'**
  String get nearFarMissionTry;

  /// Deprecated alias of nearFarMissionTry for older copy references.
  ///
  /// In en, this message translates to:
  /// **'Try together'**
  String get nearFarMissionOpen;

  /// Explicit optional skip — never penalized (LM-005 / F-008).
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get nearFarMissionSkip;

  /// Optional calm completion — no timer, score, or proof required.
  ///
  /// In en, this message translates to:
  /// **'We\'re done'**
  String get nearFarMissionDone;

  /// Title while optional off-screen mission guidance is active.
  ///
  /// In en, this message translates to:
  /// **'Explore near and far'**
  String get nearFarMissionStepsTitle;

  /// Calm lead-in after Start/Try (LMP-46). Not parent mentor UI (LMP-47/48).
  ///
  /// In en, this message translates to:
  /// **'With a grown-up, explore near and far using a sock and a soft toy.'**
  String get nearFarMissionOpenedConfirm;

  /// No description provided for @nearFarMissionStep1.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up for one sock and one soft toy.'**
  String get nearFarMissionStep1;

  /// No description provided for @nearFarMissionStep2.
  ///
  /// In en, this message translates to:
  /// **'Put them near each other.'**
  String get nearFarMissionStep2;

  /// No description provided for @nearFarMissionStep3.
  ///
  /// In en, this message translates to:
  /// **'Now put them far apart.'**
  String get nearFarMissionStep3;

  /// No description provided for @nearFarMissionStep4.
  ///
  /// In en, this message translates to:
  /// **'Talk about what changed. Pointing is okay too.'**
  String get nearFarMissionStep4;

  /// Calm skip acknowledgment — no guilt, no proof.
  ///
  /// In en, this message translates to:
  /// **'That\'s okay. You can try another time.'**
  String get nearFarMissionSkipped;

  /// Calm optional completion — scoring-neutral, no photo proof.
  ///
  /// In en, this message translates to:
  /// **'Nice exploring together.'**
  String get nearFarMissionCompleted;

  /// No description provided for @nearFarMissionLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get nearFarMissionLater;

  /// Obvious calm exit from mission guidance, skip, or completion.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get nearFarMissionBack;

  /// No description provided for @nearFarSpokenAssetsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Spoken near/far audio is blocked until approved offline voice packs and a working player are installed. On-screen labels still work.'**
  String get nearFarSpokenAssetsBlocked;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

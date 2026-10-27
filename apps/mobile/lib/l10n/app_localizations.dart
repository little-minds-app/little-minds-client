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

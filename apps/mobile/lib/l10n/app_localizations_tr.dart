// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Little Minds';

  @override
  String get hubGreeting => 'Hadi oynayalım!';

  @override
  String get hubSubtitle =>
      'Sakin ve eğlenceli bir şey seç. Büyükler güvenle çıkabilir.';

  @override
  String get hubEmptyPlayable =>
      'Henüz oynanabilir oyun yok. Aşağıdaki yumuşak kutular yakında gelecek.';

  @override
  String get hubPassiveBadge => 'Yakında';

  @override
  String get hubPassiveHint => 'Henüz hazır değil';

  @override
  String get hubPlayableHint => 'Oyna';

  @override
  String get hubParentExit => 'Büyükler';

  @override
  String get hubProfiles => 'Profiller';

  @override
  String get hubProfilesHint => 'Kim oynuyor seç. Burada sahte profil yok.';

  @override
  String get hubAudioWelcomeCue => 'Little Minds\'a hoş geldin';

  @override
  String get hubAudioPassiveCue => 'Bu oyun yakında gelecek';

  @override
  String get hubAudioPlayableCue => 'Hadi oynayalım';

  @override
  String get hubAudioParentExitCue => 'Büyükler kapısı açılıyor';

  @override
  String get activityShapeMatching => 'Şekil eşleştirme';

  @override
  String get activityColorSorting => 'Renk sıralama';

  @override
  String get activityAnimalSounds => 'Hayvan sesleri';

  @override
  String get activityCounting => 'Sayma';

  @override
  String get activityMemoryMatching => 'Hafıza eşleştirme';

  @override
  String get activityObjectCategories => 'Nesne grupları';

  @override
  String get flameHostReady => 'Flame hazır';

  @override
  String get flameRegistryEmpty => 'Etkinlik listesi boş';

  @override
  String flameRegistryCount(int count) {
    return '$count etkinlik kayıtlı';
  }
}

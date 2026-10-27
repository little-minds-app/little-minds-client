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
  String get hubSubtitle => 'Sakin bir etkinlik seç.';

  @override
  String get hubEmptyPlayable => 'Yeni oyunlar yakında.';

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
  String hubCarouselPageLabel(int current, int total) {
    return 'Etkinlik $current / $total';
  }

  @override
  String hubCarouselDotLabel(int index) {
    return '$index. etkinliğe git';
  }

  @override
  String get activityShapeMatching => 'Şekil Eşleştirme';

  @override
  String get activityColorSorting => 'Renk Sıralama';

  @override
  String get activityAnimalSounds => 'Hayvan Sesleri';

  @override
  String get activityCounting => 'Sayma';

  @override
  String get activityMemoryMatching => 'Hafıza Eşleştirme';

  @override
  String get activityObjectCategories => 'Nesne Grupları';

  @override
  String get flameHostReady => 'Flame hazır';

  @override
  String get flameRegistryEmpty => 'Etkinlik listesi boş';

  @override
  String flameRegistryCount(int count) {
    return '$count etkinlik kayıtlı';
  }

  @override
  String get activityBackToHub => 'Geri';

  @override
  String get activityPause => 'Duraklat';

  @override
  String get activityResume => 'Devam';

  @override
  String get activityRestart => 'Yeniden başla';

  @override
  String get activitySessionUnavailable =>
      'Bu etkinlik henüz çevrimdışı hazır değil.';

  @override
  String get activityPhaseIdle => 'Hazır';

  @override
  String get activityPhasePreparing => 'Hazırlanıyor';

  @override
  String get activityPhasePlaying => 'Oynanıyor';

  @override
  String get activityPhasePaused => 'Duraklatıldı';

  @override
  String get activityPhaseBackground => 'Bekleniyor';

  @override
  String get activityPhaseCompleted => 'Aferin';

  @override
  String get nearFarTitle => 'Yakın ve Uzak';

  @override
  String get nearFarBack => 'Geri';

  @override
  String get nearFarDemoEntry => 'Yakın/Uzak demosunu dene';

  @override
  String get nearFarPromptNear =>
      'Çorabı ve yumuşak oyuncağı birbirine yaklaştır.';

  @override
  String get nearFarPromptFar => 'Şimdi onları uzaklaştır.';

  @override
  String get nearFarPromptDone => 'Güzel keşif!';

  @override
  String get nearFarLabelNear => 'Yakın';

  @override
  String get nearFarLabelFar => 'Uzak';

  @override
  String get nearFarLabelNeither => 'Hareket ettirmeye devam';

  @override
  String get nearFarSockLabel => 'Çorap';

  @override
  String get nearFarSoftToyLabel => 'Yumuşak oyuncak';

  @override
  String get nearFarMissionTitle => 'Odada dene';

  @override
  String get nearFarMissionBody =>
      'Büyüklerden bir çorap ve bir yumuşak oyuncak iste. Önce yakın, sonra uzak koy. Ne değişti konuşun.';

  @override
  String get nearFarMissionMaterials =>
      'Malzemeler: bir çorap, bir yumuşak oyuncak. Yetişkin gözetimi. Cam veya boğulma riski olan küçük nesneler yok.';

  @override
  String get nearFarMissionOpen => 'Daveti aç';

  @override
  String get nearFarMissionLater => 'Belki sonra';

  @override
  String get nearFarSpokenAssetsBlocked =>
      'Konuşulan yakın/uzak ses paketleri henüz yok. Ekrandaki yazılar çalışır.';
}

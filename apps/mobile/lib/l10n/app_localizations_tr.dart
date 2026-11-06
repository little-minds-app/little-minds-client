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
  String get nearFarDemoEntry => 'Geçici Yakın/Uzak demosu (geliştirici)';

  @override
  String get nearFarDemoEntryHint =>
      'Geçici Slice B demosunu açar. Buradaki Büyükler Kapısı yer tutucudur — henüz güvenli giriş yoktur.';

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
  String get nearFarMissionTry => 'Birlikte dene';

  @override
  String get nearFarMissionOpen => 'Birlikte dene';

  @override
  String get nearFarMissionSkip => 'Atla';

  @override
  String get nearFarMissionDone => 'Bitirdik';

  @override
  String get nearFarMissionStepsTitle => 'Yakın ve uzağı keşfet';

  @override
  String get nearFarMissionOpenedConfirm =>
      'Bir büyükle çorap ve yumuşak oyuncak kullanarak yakın ve uzağı keşfedin.';

  @override
  String get nearFarMissionStep1 =>
      'Büyüklerden bir çorap ve bir yumuşak oyuncak iste.';

  @override
  String get nearFarMissionStep2 => 'Onları birbirine yaklaştırın.';

  @override
  String get nearFarMissionStep3 => 'Şimdi onları uzaklaştırın.';

  @override
  String get nearFarMissionStep4 => 'Ne değişti konuşun. İşaret etmek de olur.';

  @override
  String get nearFarMissionSkipped =>
      'Sorun değil. Başka zaman deneyebilirsiniz.';

  @override
  String get nearFarMissionCompleted => 'Birlikte güzel keşfettiniz.';

  @override
  String get nearFarMissionLater => 'Belki sonra';

  @override
  String get nearFarMissionBack => 'Geri';

  @override
  String get nearFarSpokenAssetsBlocked =>
      'Onaylı çevrimdışı ses paketleri ve çalışan bir oynatıcı gelene kadar konuşulan yakın/uzak sesleri engellidir. Ekrandaki yazılar çalışır.';

  @override
  String get mentorCardSurfaceTitle => 'Ebeveyn Oyun Rehberi';

  @override
  String get mentorCardBack => 'Geri';

  @override
  String get mentorCardSettingsEntry => 'Yakın/Uzak mentor kartı';

  @override
  String get mentorCardSettingsEntryHint =>
      'Yakın ve uzak oyun için bakımveren rehberliği. Taslak içerik inceleme kapısının arkasında kalır.';

  @override
  String get mentorCardSectionWhy => 'Neden';

  @override
  String get mentorCardSectionHow => 'Nasıl';

  @override
  String get mentorCardSectionWhatToSay => 'Ne söylenebilir';

  @override
  String get mentorCardWhatBefore => 'Önce';

  @override
  String get mentorCardWhatDuring => 'Sırasında';

  @override
  String get mentorCardWhatAfter => 'Sonra';

  @override
  String get mentorCardSectionSafety => 'Güvenlik';

  @override
  String get mentorCardSectionAdaptations => 'Uyarlamalar';

  @override
  String get mentorCardSectionObserved => 'Gözlenen ve önerilen';

  @override
  String mentorCardAgeRange(int minMonths, int maxMonths) {
    return '$minMonths–$maxMonths aylık çocuklar için';
  }

  @override
  String get mentorCardAgeFits => 'Bu çocuğun yaşına uygun.';

  @override
  String get mentorCardAgeOutside => 'Bu kartın yaş aralığının dışında.';

  @override
  String get mentorCardSafetyAdultRequired => 'Yetişkin gözetimi gereklidir.';

  @override
  String get mentorCardSafetyNoProof => 'Fotoğraf veya kanıt istenmez.';

  @override
  String get mentorCardDraftPreviewBanner =>
      'Taslak önizleme — onaylı bakımveren rehberliği değildir.';

  @override
  String get mentorCardNotApprovedTitle => 'Rehberlik henüz hazır değil';

  @override
  String mentorCardNotApprovedBody(String status) {
    return 'Bu mentor kartı hâlâ “$status” incelemesinde ve bakımverenler için onaylı değildir.';
  }

  @override
  String get mentorCardLoading => 'Mentor rehberliği yükleniyor';

  @override
  String get mentorCardLoadError =>
      'Mentor rehberliği yüklenemedi. Yeniden deneyin.';

  @override
  String get mentorCardRetry => 'Yeniden dene';

  @override
  String mentorCardSemanticsLabel(String title) {
    return 'Ebeveyn Oyun Rehberi kartı: $title';
  }

  @override
  String get mentorCardOpenMission => 'Yakın ve uzak görevini dene';

  @override
  String get mentorCardOpenMissionHint =>
      'Mevcut Yakın/Uzak oyunu ve gerçek dünya görevini açar. İstediğiniz zaman atlayabilirsiniz. Fotoğraf veya kanıt yok.';

  @override
  String get screenTimeCalmTitle => 'Mola zamanı';

  @override
  String get screenTimeCalmBody =>
      'Bugünlük ekran süresi doldu. Hazır olduğunda bir büyüğe sor.';

  @override
  String get screenTimeCalmTrustTitle => 'Bir büyüğe sor';

  @override
  String get screenTimeCalmTrustBody =>
      'Oyun, bir büyük ekran süresini kontrol edene kadar duraklatıldı. Bugünkü süren bitmiş değil.';

  @override
  String get screenTimeCalmGrownUps => 'Büyükler';

  @override
  String get screenTimeDebugSettingsEntry =>
      'Ekran süresi hata ayıklama (DEBUG)';

  @override
  String get screenTimeDebugSettingsEntryHint =>
      'Yerel günlük limit için canlı denetleyici ve QA kontrolleri. Yalnızca hata ayıklama derlemeleri — bakımveren ürün kontrolü değildir.';

  @override
  String get screenTimeDebugTitle => 'Ekran süresi hata ayıklama';

  @override
  String get screenTimeDebugBack => 'Geri';

  @override
  String get screenTimeDebugOnlyBanner =>
      'YALNIZCA DEBUG — bakımveren arayüzü değildir';

  @override
  String get screenTimeDebugUnavailable =>
      'Ekran süresi hata ayıklama denetleyicisi bu derlemede kullanılamaz.';

  @override
  String get screenTimeDebugSectionBudget => 'Bütçe';

  @override
  String get screenTimeDebugSectionLifecycle => 'Yaşam döngüsü';

  @override
  String get screenTimeDebugSectionTrust => 'Güven';

  @override
  String get screenTimeDebugSectionQa => 'QA kontrolleri';

  @override
  String get screenTimeDebugFieldDayKey => 'Gün anahtarı';

  @override
  String get screenTimeDebugFieldAccumulated => 'Biriken';

  @override
  String get screenTimeDebugFieldRemaining => 'Kalan';

  @override
  String get screenTimeDebugFieldCap => 'Günlük limit';

  @override
  String get screenTimeDebugFieldCapReached => 'Limit doldu';

  @override
  String get screenTimeDebugFieldKidsMode => 'Çocuk Modu kabuğu';

  @override
  String get screenTimeDebugFieldCounting => 'Sayılıyor';

  @override
  String get screenTimeDebugFieldForeground => 'Uygulama ön planda';

  @override
  String get screenTimeDebugFieldGameplayPhase => 'Oynanış aşaması';

  @override
  String get screenTimeDebugFieldInitialized => 'Başlatıldı';

  @override
  String get screenTimeDebugFieldTrustState => 'Güven durumu';

  @override
  String get screenTimeDebugFieldClockSkew => 'Saat sapması';

  @override
  String get screenTimeDebugFieldCorrupt => 'Bozuk kalıcılık';

  @override
  String get screenTimeDebugFieldStorageFailed => 'Depolama hatası';

  @override
  String get screenTimeDebugFieldAllowsPlay => 'Çocuk oyununa izin';

  @override
  String get screenTimeDebugQaNearCap => '29:50 ayarla';

  @override
  String get screenTimeDebugQaAtCap => '30:00 ayarla';

  @override
  String get screenTimeDebugQaReset => 'Bütçeyi sıfırla';

  @override
  String get screenTimeDebugQaReload => 'Depodan yeniden yükle';

  @override
  String get screenTimeDebugQaPersist => 'Şimdi kaydet';

  @override
  String get screenTimeDebugResetConfirmTitle =>
      'Ekran süresi bütçesi sıfırlansın mı?';

  @override
  String get screenTimeDebugResetConfirmBody =>
      'Bu, bugünkü kullanılan süreyi bu hata ayıklama derlemesinde 0:00 yapar. Bozuk kanıtı temizlemez veya güven kurtarmayı değiştirmez.';

  @override
  String get screenTimeDebugResetCancel => 'İptal';

  @override
  String get screenTimeDebugResetConfirm => 'Sıfırla';

  @override
  String get screenTimeDebugStatusNearCap =>
      'Bütçe 29:50 kullanılmış olarak ayarlandı.';

  @override
  String get screenTimeDebugStatusAtCap =>
      'Bütçe 30:00 (limit) olarak ayarlandı.';

  @override
  String get screenTimeDebugStatusReset => 'Bütçe 0:00 olarak sıfırlandı.';

  @override
  String get screenTimeDebugStatusReload => 'Depodan yeniden yüklendi.';

  @override
  String get screenTimeDebugStatusPersist =>
      'Geçerli kontrol noktası kaydedildi.';

  @override
  String get shapeMatchingPromptMatch => 'Aynı şekli bul!';

  @override
  String get shapeMatchingPromptDone => 'Harika yaptın!';

  @override
  String get shapeMatchingTapOrDragHint => 'Dokun veya sürükle.';

  @override
  String get shapeMatchingTargetLabel => 'Bunu eşleştir';

  @override
  String get shapeMatchingChoicesLabel => 'Birini seç';

  @override
  String get shapeMatchingTryAgain => 'Bir daha dene!';

  @override
  String get shapeMatchingPlayAgain => 'Tekrar oyna';

  @override
  String shapeMatchingHintLevel(int level) {
    return 'Küçük bir ipucu: aynı şekle bak ($level)';
  }

  @override
  String get shapeMatchingShapeCircle => 'Daire';

  @override
  String get shapeMatchingShapeSquare => 'Kare';

  @override
  String get shapeMatchingShapeTriangle => 'Üçgen';

  @override
  String get shapeMatchingShapeStar => 'Yıldız';

  @override
  String get shapeMatchingShapeHexagon => 'Altıgen';

  @override
  String get shapeMatchingPraiseGreat => 'Aferin!';

  @override
  String get shapeMatchingPraiseNice => 'Güzel eşleşme!';

  @override
  String get shapeMatchingPraiseAwesome => 'Süper!';

  @override
  String get shapeMatchingGardenTitle => 'Neşeli Öğrenme Bahçesi';

  @override
  String get colorSortingPromptSort => 'Eşleşen sepete koy!';

  @override
  String get colorSortingPromptDone => 'Harika yaptın!';

  @override
  String get colorSortingTapOrDragHint => 'Sepete dokun veya sürükle.';

  @override
  String get colorSortingObjectLabel => 'Sıralanacak oyuncak';

  @override
  String get colorSortingBinLabel => 'Sepet';

  @override
  String get colorSortingBinsLabel => 'Sepetler';

  @override
  String get colorSortingTryAgain => 'Bir daha dene!';

  @override
  String get colorSortingPlayAgain => 'Tekrar oyna';

  @override
  String colorSortingHintLevel(int level) {
    return 'Küçük bir ipucu: aynı renge bak ($level)';
  }

  @override
  String get colorSortingColorRed => 'Kırmızı';

  @override
  String get colorSortingColorYellow => 'Sarı';

  @override
  String get colorSortingColorBlue => 'Mavi';

  @override
  String get colorSortingColorGreen => 'Yeşil';

  @override
  String get colorSortingPraiseGreat => 'Aferin!';

  @override
  String get colorSortingPraiseNice => 'Güzel sıralama!';

  @override
  String get colorSortingPraiseAwesome => 'Süper!';

  @override
  String get colorSortingOrchardTitle => 'Renkli Meyve Bahçesi';

  @override
  String get parentDashboardChildSelectorLabel => 'Çocuk profili';

  @override
  String get parentDashboardChildSelectorHint =>
      'Hangi çocuğun özeti ve görev durumunun gösterileceğini seçin.';
}

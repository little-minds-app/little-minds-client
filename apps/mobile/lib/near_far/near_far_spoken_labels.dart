import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'near_far_relation.dart';

/// Spoken "near" / "far" label stems (Blueprint §5.2 / §22).
///
/// Asset convention (local / offline only — never network):
/// `assets/audio/near_far/<locale>/<stem>.wav`
/// Examples: `assets/audio/near_far/en-US/near.wav`, `…/tr-TR/far.wav`
///
/// **Licensing:** only pedagogy-approved, licensed WAV packs may be committed.
/// Spoken-label AC stays **BLOCKED** until approved en-US/tr-TR assets **and** a
/// working offline WAV player are integrated and tested. Do not fake speech.
enum NearFarSpokenStem {
  near('near'),
  far('far');

  const NearFarSpokenStem(this.assetStem);
  final String assetStem;

  static NearFarSpokenStem? fromRelation(NearFarRelation relation) {
    switch (relation) {
      case NearFarRelation.near:
        return NearFarSpokenStem.near;
      case NearFarRelation.far:
        return NearFarSpokenStem.far;
      case NearFarRelation.neither:
        return null;
    }
  }
}

/// Plays a local asset path when approved packs exist.
///
/// [canPlay] distinguishes a real offline player from the unavailable stub.
/// Asset presence alone must never imply spoken-label readiness.
abstract class NearFarLabelPlayer {
  /// True only when this player can actually play offline WAV assets.
  bool get canPlay;

  Future<bool> playAsset(String assetPath);
}

/// Default player — **cannot play** and never satisfies spoken-label readiness.
///
/// Even if licensed WAV files are later dropped into the asset bundle, this
/// stub still reports [canPlay] == false until a real offline player is wired.
class UnavailableNearFarLabelPlayer implements NearFarLabelPlayer {
  const UnavailableNearFarLabelPlayer();

  @override
  bool get canPlay => false;

  @override
  Future<bool> playAsset(String assetPath) async => false;
}

/// Test / DI double that records attempted plays.
class RecordingNearFarLabelPlayer implements NearFarLabelPlayer {
  RecordingNearFarLabelPlayer({this.canPlay = true});

  @override
  bool canPlay;

  final List<String> plays = <String>[];
  var succeed = true;

  @override
  Future<bool> playAsset(String assetPath) async {
    plays.add(assetPath);
    return succeed && canPlay;
  }
}

/// Offline spoken-label presence + readiness + play hook for Near/Far.
class NearFarSpokenLabels {
  NearFarSpokenLabels({
    AssetBundle? bundle,
    NearFarLabelPlayer? player,
  })  : _bundle = bundle ?? rootBundle,
        _player = player ?? const UnavailableNearFarLabelPlayer();

  final AssetBundle _bundle;
  final NearFarLabelPlayer _player;

  /// Exposed for diagnostics — never treat as spoken AC by itself.
  NearFarLabelPlayer get player => _player;

  @visibleForTesting
  final Map<String, bool> presenceCache = <String, bool>{};

  @visibleForTesting
  int loadAttempts = 0;

  static String assetPath(NearFarSpokenStem stem, String localeTag) =>
      'assets/audio/near_far/$localeTag/${stem.assetStem}.wav';

  /// Probes whether both near and far **files** exist for [localeTag].
  ///
  /// File presence ≠ spoken readiness (see [areSpokenLabelsReady]).
  Future<bool> areAssetsPresent(String localeTag) async {
    final near = await _probe(assetPath(NearFarSpokenStem.near, localeTag));
    final far = await _probe(assetPath(NearFarSpokenStem.far, localeTag));
    return near && far;
  }

  /// Spoken-label readiness requires licensed assets **and** a capable player.
  ///
  /// [UnavailableNearFarLabelPlayer] always yields false.
  Future<bool> areSpokenLabelsReady(String localeTag) async {
    if (!_player.canPlay) {
      return false;
    }
    return areAssetsPresent(localeTag);
  }

  /// Speaks [stem] only when assets are present, sound is on, and player can play.
  ///
  /// Returns `true` only on actual player-reported playback. Missing assets or
  /// an unavailable player → `false` (spoken AC remains blocked).
  Future<bool> speak(
    NearFarSpokenStem stem, {
    required String localeTag,
    bool soundOff = false,
  }) async {
    if (soundOff || !_player.canPlay) {
      return false;
    }
    final path = assetPath(stem, localeTag);
    final present = await _probe(path);
    if (!present) {
      return false;
    }
    return _player.playAsset(path);
  }

  Future<bool> _probe(String path) async {
    final cached = presenceCache[path];
    if (cached != null) {
      return cached;
    }
    loadAttempts += 1;
    try {
      await _bundle.load(path);
      presenceCache[path] = true;
      return true;
    } catch (_) {
      presenceCache[path] = false;
      return false;
    }
  }

  @visibleForTesting
  void clearCache() {
    presenceCache.clear();
    loadAttempts = 0;
  }
}

/// Maps Flutter [Locale] to Blueprint asset tags (`en-US` / `tr-TR`).
String nearFarLocaleTag(Locale locale) {
  final language = locale.languageCode.toLowerCase();
  if (language == 'tr') {
    return 'tr-TR';
  }
  return 'en-US';
}

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
/// Missing packs → spoken-label AC is **blocked** — do not fake speech or claim
/// the spoken AC is met.
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
/// Production must wire a real offline WAV player once licensed assets land.
/// This interface exists so tests can inject a recorder without claiming
/// speakers worked.
abstract class NearFarLabelPlayer {
  Future<bool> playAsset(String assetPath);
}

/// Default player — **does not synthesize speech**. Returns false always.
///
/// Used until licensed WAV assets + a real media player are approved. Calling
/// this never satisfies the spoken-label acceptance criterion.
class UnavailableNearFarLabelPlayer implements NearFarLabelPlayer {
  const UnavailableNearFarLabelPlayer();

  @override
  Future<bool> playAsset(String assetPath) async => false;
}

/// Test / DI double that records attempted plays.
class RecordingNearFarLabelPlayer implements NearFarLabelPlayer {
  final List<String> plays = <String>[];
  var succeed = true;

  @override
  Future<bool> playAsset(String assetPath) async {
    plays.add(assetPath);
    return succeed;
  }
}

/// Offline spoken-label readiness + play hook for Near/Far.
class NearFarSpokenLabels {
  NearFarSpokenLabels({
    AssetBundle? bundle,
    NearFarLabelPlayer? player,
  })  : _bundle = bundle ?? rootBundle,
        _player = player ?? const UnavailableNearFarLabelPlayer();

  final AssetBundle _bundle;
  final NearFarLabelPlayer _player;

  @visibleForTesting
  final Map<String, bool> presenceCache = <String, bool>{};

  @visibleForTesting
  int loadAttempts = 0;

  static String assetPath(NearFarSpokenStem stem, String localeTag) =>
      'assets/audio/near_far/$localeTag/${stem.assetStem}.wav';

  /// Probes whether both near and far assets exist for [localeTag].
  Future<bool> areAssetsReady(String localeTag) async {
    final near = await _probe(assetPath(NearFarSpokenStem.near, localeTag));
    final far = await _probe(assetPath(NearFarSpokenStem.far, localeTag));
    return near && far;
  }

  /// Speaks [stem] when assets exist, sound is on, and a capable player is wired.
  ///
  /// Returns `true` only when a local asset was found **and** the player
  /// reported playback. Missing assets → `false` (expected blocker today).
  Future<bool> speak(
    NearFarSpokenStem stem, {
    required String localeTag,
    bool soundOff = false,
  }) async {
    if (soundOff) {
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

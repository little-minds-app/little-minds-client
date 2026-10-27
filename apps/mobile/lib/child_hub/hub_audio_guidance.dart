import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Locale-tagged Child Hub audio cue IDs (F-004 / Blueprint § audio integrity).
///
/// Asset convention (local / offline only — never network):
/// `assets/audio/hub/<locale>/<cue_id>.wav`
/// Examples: `assets/audio/hub/en-US/welcome.wav`, `…/tr-TR/welcome.wav`
///
/// **V1 reality:** [LocalAssetHubAudioGuidance] only **probes** whether a local
/// asset exists. It does **not** decode or play PCM/WAV audio. Missing assets
/// no-op. Do not describe this as full spoken audio guidance for QA or users
/// until pedagogy-approved packs land and a real player is wired.
enum HubAudioCue {
  welcome('welcome'),
  passiveUnavailable('passive_unavailable'),
  playableSelect('playable_select'),
  parentExit('parent_exit');

  const HubAudioCue(this.assetStem);
  final String assetStem;
}

/// Offline-bound hub cue hook (no network audio).
///
/// [play] is the extension-point name. The default [LocalAssetHubAudioGuidance]
/// implementation is an **existence probe + no-op**, not media playback.
abstract class HubAudioGuidance {
  /// Invokes the cue hook for [localeTag] (`en-US` / `tr-TR`).
  ///
  /// Return value for [LocalAssetHubAudioGuidance]: `true` only means a local
  /// asset **file was found** — not that sound was heard. Missing assets and
  /// [soundOff] return `false` without error.
  Future<bool> play(
    HubAudioCue cue, {
    required String localeTag,
    bool soundOff = false,
  });

  /// Canonical asset path for [cue] + [localeTag].
  static String assetPath(HubAudioCue cue, String localeTag) =>
      'assets/audio/hub/$localeTag/${cue.assetStem}.wav';
}

/// **Probe-only** offline stub — not a media player.
///
/// Probes the asset bundle once per locale+cue and **caches** presence or
/// absence so Simulator/debug sessions do not spam expected-missing paths
/// (approved voice packs are not shipped in V1). Never fetches remote audio.
/// Never plays WAV/PCM.
class LocalAssetHubAudioGuidance implements HubAudioGuidance {
  LocalAssetHubAudioGuidance({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Cached probe results keyed by [HubAudioGuidance.assetPath].
  /// `true` = present, `false` = known missing. Avoids repeat [AssetBundle.load].
  @visibleForTesting
  final Map<String, bool> presenceCache = <String, bool>{};

  /// How many times [AssetBundle.load] was attempted (tests / diagnostics).
  @visibleForTesting
  int loadAttempts = 0;

  @override
  Future<bool> play(
    HubAudioCue cue, {
    required String localeTag,
    bool soundOff = false,
  }) async {
    if (soundOff) {
      return false;
    }

    final path = HubAudioGuidance.assetPath(cue, localeTag);
    final cached = presenceCache[path];
    if (cached != null) {
      return cached;
    }

    loadAttempts += 1;
    try {
      // Existence probe only — no AudioPlayer / no PCM decode / no speakers.
      await _bundle.load(path);
      presenceCache[path] = true;
      return true;
    } catch (_) {
      // Expected in V1 when pedagogy-approved packs are absent — cache and
      // stay quiet (do not debugPrint on every welcome / parent_exit cue).
      presenceCache[path] = false;
      return false;
    }
  }

  /// Clears the presence/absence cache (tests).
  @visibleForTesting
  void clearCache() {
    presenceCache.clear();
    loadAttempts = 0;
  }
}

/// Test double that records cue requests without touching the asset bundle.
class RecordingHubAudioGuidance implements HubAudioGuidance {
  final List<({HubAudioCue cue, String localeTag, bool soundOff})> plays = [];

  @override
  Future<bool> play(
    HubAudioCue cue, {
    required String localeTag,
    bool soundOff = false,
  }) async {
    plays.add((cue: cue, localeTag: localeTag, soundOff: soundOff));
    return !soundOff;
  }
}

/// Maps a Flutter [Locale] to Blueprint locale tags used in asset paths.
String hubLocaleTag(Locale locale) {
  final language = locale.languageCode.toLowerCase();
  if (language == 'tr') {
    return 'tr-TR';
  }
  return 'en-US';
}

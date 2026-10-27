import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Locale-tagged Child Hub audio cues (F-004 / Blueprint § audio integrity).
///
/// Asset convention (local / offline only — never network):
/// `assets/audio/hub/<locale>/<cue_id>.wav`
/// Examples: `assets/audio/hub/en-US/welcome.wav`, `…/tr-TR/welcome.wav`
///
/// When the asset is missing (current V1 default until pedagogy-approved
/// voice packs land), implementations MUST no-op gracefully. The hub stays
/// fully usable offline without invented external audio.
enum HubAudioCue {
  welcome('welcome'),
  passiveUnavailable('passive_unavailable'),
  playableSelect('playable_select'),
  parentExit('parent_exit');

  const HubAudioCue(this.assetStem);
  final String assetStem;
}

/// Plays hub navigation cues without leaving Kids Mode offline boundaries.
abstract class HubAudioGuidance {
  /// Attempts to play [cue] for [localeTag] (`en-US` / `tr-TR`).
  ///
  /// Returns whether a local asset was found. Missing assets are not errors.
  Future<bool> play(
    HubAudioCue cue, {
    required String localeTag,
    bool soundOff = false,
  });

  /// Canonical asset path for [cue] + [localeTag].
  static String assetPath(HubAudioCue cue, String localeTag) =>
      'assets/audio/hub/$localeTag/${cue.assetStem}.wav';
}

/// Default offline-safe guidance: probes the asset bundle, never fetches
/// remote audio, and no-ops when assets are absent (graceful stub).
///
/// Playback of present WAV files is intentionally deferred until approved
/// voice assets ship; discovery still validates the offline path contract.
class LocalAssetHubAudioGuidance implements HubAudioGuidance {
  LocalAssetHubAudioGuidance({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

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
    try {
      await _bundle.load(path);
      // Asset exists. Full PCM playback lands with pedagogy-approved packs.
      // Until then, presence is enough for offline contract + tests.
      if (kDebugMode) {
        debugPrint('HubAudioGuidance: asset present (stub play): $path');
      }
      return true;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('HubAudioGuidance: missing asset, graceful no-op: $path');
      }
      return false;
    }
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

import 'package:flutter/foundation.dart';
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
/// Loads the expected asset path from the bundle to verify the offline
/// contract. Never fetches remote audio. Never plays WAV/PCM. When the file is
/// absent (current V1 default), returns `false` and no-ops. Real spoken cues
/// require pedagogy-approved assets **and** a future playback implementation.
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
      // Existence probe only — no AudioPlayer / no PCM decode / no speakers.
      await _bundle.load(path);
      if (kDebugMode) {
        debugPrint(
          'HubAudioGuidance: asset present (probe only, no playback): $path',
        );
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

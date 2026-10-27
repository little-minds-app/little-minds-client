import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/child_hub/hub_audio_guidance.dart';

/// Counts [load] calls; optional set of paths that "exist".
class _CountingBundle extends CachingAssetBundle {
  _CountingBundle({this.presentPaths = const {}});

  final Set<String> presentPaths;
  int loadCount = 0;
  final List<String> loadedPaths = [];

  @override
  Future<ByteData> load(String key) async {
    loadCount += 1;
    loadedPaths.add(key);
    if (!presentPaths.contains(key)) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode('wav')));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TC-AUDIO-001 missing assets no-op without repeat loads or spam probes',
      () async {
    final bundle = _CountingBundle();
    final guidance = LocalAssetHubAudioGuidance(bundle: bundle);

    final first = await guidance.play(
      HubAudioCue.welcome,
      localeTag: 'en-US',
    );
    final second = await guidance.play(
      HubAudioCue.welcome,
      localeTag: 'en-US',
    );
    final third = await guidance.play(
      HubAudioCue.welcome,
      localeTag: 'en-US',
    );

    expect(first, isFalse);
    expect(second, isFalse);
    expect(third, isFalse);
    expect(bundle.loadCount, 1);
    expect(guidance.loadAttempts, 1);
    expect(
      guidance.presenceCache[HubAudioGuidance.assetPath(
        HubAudioCue.welcome,
        'en-US',
      )],
      isFalse,
    );
  });

  test('TC-AUDIO-002 caches independently per locale and cue', () async {
    final bundle = _CountingBundle();
    final guidance = LocalAssetHubAudioGuidance(bundle: bundle);

    await guidance.play(HubAudioCue.welcome, localeTag: 'en-US');
    await guidance.play(HubAudioCue.parentExit, localeTag: 'en-US');
    await guidance.play(HubAudioCue.welcome, localeTag: 'tr-TR');

    // One probe each for distinct paths.
    expect(bundle.loadCount, 3);

    await guidance.play(HubAudioCue.welcome, localeTag: 'en-US');
    await guidance.play(HubAudioCue.parentExit, localeTag: 'en-US');
    await guidance.play(HubAudioCue.welcome, localeTag: 'tr-TR');

    expect(bundle.loadCount, 3);
    expect(guidance.loadAttempts, 3);
  });

  test('TC-AUDIO-003 present asset is cached as present; still no playback API',
      () async {
    final path = HubAudioGuidance.assetPath(HubAudioCue.welcome, 'en-US');
    final bundle = _CountingBundle(presentPaths: {path});
    final guidance = LocalAssetHubAudioGuidance(bundle: bundle);

    expect(await guidance.play(HubAudioCue.welcome, localeTag: 'en-US'), isTrue);
    expect(await guidance.play(HubAudioCue.welcome, localeTag: 'en-US'), isTrue);
    expect(bundle.loadCount, 1);
    expect(guidance.presenceCache[path], isTrue);
  });

  test('TC-AUDIO-004 soundOff skips probe and returns false', () async {
    final bundle = _CountingBundle();
    final guidance = LocalAssetHubAudioGuidance(bundle: bundle);

    final result = await guidance.play(
      HubAudioCue.welcome,
      localeTag: 'en-US',
      soundOff: true,
    );

    expect(result, isFalse);
    expect(bundle.loadCount, 0);
    expect(guidance.presenceCache, isEmpty);
  });
}

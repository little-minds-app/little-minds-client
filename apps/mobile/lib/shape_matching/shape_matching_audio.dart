import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled preschool SFX cues for Shape Matching (offline, locale-agnostic).
///
/// Paths: `assets/audio/shape_matching/sfx/<file>.wav`
enum ShapeMatchingSfxCue {
  tapPop('tap_pop.wav'),
  dragBounce('drag_bounce.wav'),
  correctChime('correct_chime.wav'),
  softClap('soft_clap.wav'),
  wrongSoft('wrong_soft.wav'),
  completeJingle('complete_jingle.wav'),
  twinkle('twinkle.wav');

  const ShapeMatchingSfxCue(this.fileName);
  final String fileName;

  /// Full Flutter asset key (pubspec / rootBundle).
  String get assetPath => 'assets/audio/shape_matching/sfx/$fileName';

  /// [AssetSource] path relative to the Flutter assets root.
  String get assetSourcePath => 'audio/shape_matching/sfx/$fileName';
}

/// Bundled Happy Garden BGM loop (offline, instrumental).
abstract final class ShapeMatchingBgmTrack {
  static const fileName = 'happy_garden_loop.mp3';
  static const assetPath =
      'assets/audio/shape_matching/bgm/$fileName';
  static const assetSourcePath = 'audio/shape_matching/bgm/$fileName';
}

/// Offline SFX player port — inject [RecordingShapeMatchingSfxPlayer] in tests.
abstract class ShapeMatchingSfxPlayer {
  /// True only when this player can actually emit audio.
  bool get canPlay;

  Future<bool> play(ShapeMatchingSfxCue cue, {required double volume});

  Future<void> stopAll();

  Future<void> dispose();
}

/// Separate single-instance BGM port — loop / pause / resume / stop / dispose.
abstract class ShapeMatchingBgmPlayer {
  bool get canPlay;
  bool get isPlaying;
  bool get isPaused;
  double get volume;

  /// Idempotent: if already looping, only updates volume (no restart).
  /// If paused, resumes. If stopped, starts a single looped instance.
  Future<bool> startLoop({required double volume});

  Future<void> setVolume(double volume);

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}

/// Default no-op when a real engine cannot be constructed (or for DI stubs).
class UnavailableShapeMatchingSfxPlayer implements ShapeMatchingSfxPlayer {
  const UnavailableShapeMatchingSfxPlayer();

  @override
  bool get canPlay => false;

  @override
  Future<bool> play(ShapeMatchingSfxCue cue, {required double volume}) async =>
      false;

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

class UnavailableShapeMatchingBgmPlayer implements ShapeMatchingBgmPlayer {
  const UnavailableShapeMatchingBgmPlayer();

  @override
  bool get canPlay => false;

  @override
  bool get isPlaying => false;

  @override
  bool get isPaused => false;

  @override
  double get volume => 0;

  @override
  Future<bool> startLoop({required double volume}) async => false;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// Test / DI double that records cue plays without touching speakers.
///
/// When [holdPlays] is true, each [play] call parks on a completer until
/// [releaseNextPlay] (or [releaseAllPlays]) — used for deterministic celebrate
/// race tests without wall-clock sleeps.
class RecordingShapeMatchingSfxPlayer implements ShapeMatchingSfxPlayer {
  RecordingShapeMatchingSfxPlayer({
    this.canPlay = true,
    this.holdPlays = false,
  });

  @override
  bool canPlay;

  /// When true, [play] awaits an explicit [releaseNextPlay] before recording.
  bool holdPlays;

  final List<ShapeMatchingSfxCue> plays = <ShapeMatchingSfxCue>[];
  final List<double> volumes = <double>[];
  var succeed = true;
  var stopCount = 0;
  var disposeCount = 0;

  final List<_HeldPlay> _heldPlays = <_HeldPlay>[];

  /// Number of [play] calls currently waiting on a release gate.
  int get pendingPlayCount => _heldPlays.length;

  /// Cue for the oldest held [play], if any.
  ShapeMatchingSfxCue? get nextHeldCue =>
      _heldPlays.isEmpty ? null : _heldPlays.first.cue;

  /// Completes the oldest held [play]. Returns false if none are pending.
  bool releaseNextPlay({bool? succeedOverride}) {
    if (_heldPlays.isEmpty) return false;
    final held = _heldPlays.removeAt(0);
    final ok = succeedOverride ?? (succeed && canPlay);
    if (ok) {
      plays.add(held.cue);
      volumes.add(held.volume);
    }
    held.completer.complete(ok);
    return true;
  }

  /// Completes every held [play] in FIFO order.
  void releaseAllPlays({bool? succeedOverride}) {
    while (_heldPlays.isNotEmpty) {
      releaseNextPlay(succeedOverride: succeedOverride);
    }
  }

  @override
  Future<bool> play(ShapeMatchingSfxCue cue, {required double volume}) async {
    if (!holdPlays) {
      plays.add(cue);
      volumes.add(volume);
      return succeed && canPlay;
    }
    final held = _HeldPlay(cue, volume);
    _heldPlays.add(held);
    return held.completer.future;
  }

  @override
  Future<void> stopAll() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    canPlay = false;
    // Fail any still-held plays so celebrate awaits do not hang after dispose.
    while (_heldPlays.isNotEmpty) {
      releaseNextPlay(succeedOverride: false);
    }
  }
}

class _HeldPlay {
  _HeldPlay(this.cue, this.volume);

  final ShapeMatchingSfxCue cue;
  final double volume;
  final Completer<bool> completer = Completer<bool>();
}

/// Recording BGM double for deterministic lifecycle / duck tests.
class RecordingShapeMatchingBgmPlayer implements ShapeMatchingBgmPlayer {
  RecordingShapeMatchingBgmPlayer({this.canPlay = true});

  @override
  bool canPlay;

  @override
  bool isPlaying = false;

  @override
  bool isPaused = false;

  @override
  double volume = 0;

  var startLoopCount = 0;
  var pauseCount = 0;
  var resumeCount = 0;
  var stopCount = 0;
  var disposeCount = 0;
  final List<double> volumeHistory = <double>[];
  var succeed = true;

  @override
  Future<bool> startLoop({required double volume}) async {
    if (!canPlay || !succeed) return false;
    startLoopCount++;
    this.volume = volume;
    volumeHistory.add(volume);
    isPlaying = true;
    isPaused = false;
    return true;
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
    volumeHistory.add(volume);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    if (isPlaying) {
      isPaused = true;
      isPlaying = false;
    }
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    if (isPaused || (!isPlaying && startLoopCount > 0 && disposeCount == 0)) {
      isPaused = false;
      isPlaying = true;
    }
  }

  @override
  Future<void> stop() async {
    stopCount++;
    isPlaying = false;
    isPaused = false;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    canPlay = false;
    isPlaying = false;
    isPaused = false;
  }
}

/// Production offline SFX player using [audioplayers] + ambient iOS session
/// (respects the hardware silent switch; mixes with other audio).
class AudioplayersShapeMatchingSfxPlayer implements ShapeMatchingSfxPlayer {
  AudioplayersShapeMatchingSfxPlayer();

  final List<AudioPlayer> _active = <AudioPlayer>[];
  var _disposed = false;
  var _sessionConfigured = false;

  @override
  bool get canPlay => !_disposed;

  Future<void> _ensureSession() async {
    if (_sessionConfigured) return;
    _sessionConfigured = true;
    try {
      // Ambient + mixWithOthers: honor iOS silent switch; no exclusive focus.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (_) {
      // Test / desktop without plugins — stay quiet.
    }
  }

  static const _opTimeout = Duration(milliseconds: 250);

  Future<void> _safeDispose(AudioPlayer player) async {
    _active.remove(player);
    try {
      await player.dispose().timeout(_opTimeout);
    } catch (_) {}
  }

  @override
  Future<bool> play(ShapeMatchingSfxCue cue, {required double volume}) async {
    if (_disposed) return false;
    await _ensureSession();
    AudioPlayer? player;
    try {
      player = AudioPlayer();
      _active.add(player);
      await player.setReleaseMode(ReleaseMode.release).timeout(_opTimeout);
      await player.setPlayerMode(PlayerMode.lowLatency).timeout(_opTimeout);
      await player.setVolume(volume.clamp(0.0, 1.0)).timeout(_opTimeout);
      await player
          .play(AssetSource(cue.assetSourcePath))
          .timeout(_opTimeout);
      final active = player;
      unawaited(
        active.onPlayerComplete.first
            .timeout(const Duration(seconds: 5))
            .then((_) => _safeDispose(active))
            .catchError((_) => _safeDispose(active)),
      );
      return true;
    } catch (_) {
      if (player != null) {
        await _safeDispose(player);
      }
      return false;
    }
  }

  @override
  Future<void> stopAll() async {
    final snapshot = List<AudioPlayer>.from(_active);
    _active.clear();
    await Future.wait(
      snapshot.map((player) async {
        try {
          await player.stop().timeout(_opTimeout);
        } catch (_) {}
        try {
          await player.dispose().timeout(_opTimeout);
        } catch (_) {}
      }),
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stopAll();
  }
}

/// Production single-instance BGM loop player (ambient / no exclusive focus).
class AudioplayersShapeMatchingBgmPlayer implements ShapeMatchingBgmPlayer {
  AudioplayersShapeMatchingBgmPlayer();

  AudioPlayer? _player;
  var _disposed = false;
  var _sessionConfigured = false;
  var _playing = false;
  var _paused = false;
  double _volume = 0;

  static const _opTimeout = Duration(milliseconds: 400);

  @override
  bool get canPlay => !_disposed;

  @override
  bool get isPlaying => _playing && !_paused && !_disposed;

  @override
  bool get isPaused => _paused && !_disposed;

  @override
  double get volume => _volume;

  Future<void> _ensureSession() async {
    if (_sessionConfigured) return;
    _sessionConfigured = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Future<bool> startLoop({required double volume}) async {
    if (_disposed) return false;
    _volume = volume.clamp(0.0, 1.0);
    if (_player != null && _playing && !_paused) {
      await setVolume(_volume);
      return true;
    }
    if (_player != null && _paused) {
      await setVolume(_volume);
      await resume();
      return true;
    }
    await _ensureSession();
    try {
      final player = _player ?? AudioPlayer();
      _player = player;
      await player.setReleaseMode(ReleaseMode.loop).timeout(_opTimeout);
      await player.setPlayerMode(PlayerMode.mediaPlayer).timeout(_opTimeout);
      await player.setVolume(_volume).timeout(_opTimeout);
      await player
          .play(AssetSource(ShapeMatchingBgmTrack.assetSourcePath))
          .timeout(_opTimeout);
      _playing = true;
      _paused = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    final player = _player;
    if (player == null || _disposed) return;
    try {
      await player.setVolume(_volume).timeout(_opTimeout);
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (player == null || _disposed) return;
    try {
      await player.pause().timeout(_opTimeout);
      _paused = true;
      _playing = false;
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    final player = _player;
    if (player == null || _disposed) return;
    try {
      await player.resume().timeout(_opTimeout);
      _paused = false;
      _playing = true;
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.stop().timeout(_opTimeout);
    } catch (_) {}
    _playing = false;
    _paused = false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playing = false;
    _paused = false;
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop().timeout(_opTimeout);
    } catch (_) {}
    try {
      await player.dispose().timeout(_opTimeout);
    } catch (_) {}
  }
}

/// Shape Matching offline audio — SFX + separate Happy Garden BGM.
///
/// Celebrate mapping (no gameplay delay):
/// - Mid-match: [correctChime] → delayed [softClap] → optional [twinkle]
/// - Completion: [completeJingle] → delayed [softClap] → [twinkle] (richer)
///
/// BGM ducks under celebrate (restore after sequence); duck serial cancels
/// superseded restores on rapid matches. [silence] pauses BGM; [resetForReplay]
/// keeps the same BGM instance looping (no duplicate start); [dispose] stops.
class ShapeMatchingAudio {
  ShapeMatchingAudio({
    this.soundOff = false,
    ShapeMatchingSfxPlayer? player,
    ShapeMatchingBgmPlayer? bgmPlayer,
    AssetBundle? bundle,
    this.clapDelay = const Duration(milliseconds: 140),
    this.twinkleDelay = const Duration(milliseconds: 520),
    this.completionClapDelay = const Duration(milliseconds: 180),
    this.completionTwinkleDelay = const Duration(milliseconds: 620),
    this.bgmGain = 0.20,
    this.sfxGain = 0.85,
    this.bgmDuckFactor = 0.25,
    this.matchDuckRestore = const Duration(milliseconds: 900),
    this.completionDuckRestore = const Duration(milliseconds: 1300),
  })  : _bundle = bundle ?? rootBundle,
        _player = player ?? AudioplayersShapeMatchingSfxPlayer(),
        _bgm = bgmPlayer ?? AudioplayersShapeMatchingBgmPlayer(),
        _ownsDefaultPlayer = player == null,
        _ownsDefaultBgm = bgmPlayer == null;

  final bool soundOff;
  final AssetBundle _bundle;
  final ShapeMatchingSfxPlayer _player;
  final ShapeMatchingBgmPlayer _bgm;
  final bool _ownsDefaultPlayer;
  final bool _ownsDefaultBgm;

  /// Delay from chime/jingle start to bunny-paw clap (mid-match).
  final Duration clapDelay;

  /// Delay from chime start to optional twinkle (mid-match).
  final Duration twinkleDelay;

  final Duration completionClapDelay;
  final Duration completionTwinkleDelay;

  /// Software BGM gain (~20% while idle looping).
  final double bgmGain;

  /// Comfortable SFX gain (independent of BGM).
  final double sfxGain;

  /// Multiplier applied to [bgmGain] while ducked under celebrate.
  final double bgmDuckFactor;

  /// Time from celebrate start until BGM volume restores (mid-match).
  final Duration matchDuckRestore;

  /// Longer restore window for session-complete celebrate.
  final Duration completionDuckRestore;

  var _assetsPresent = false;
  var _bgmAssetPresent = false;
  var _ready = false;
  var _bgmReady = false;
  var _disposed = false;
  var _lifecycleEpoch = 0;
  var _lastCelebratedSerial = 0;
  var _lastDuckSerial = 0;
  Timer? _clapTimer;
  Timer? _twinkleTimer;
  Timer? _duckRestoreTimer;

  @visibleForTesting
  final Map<String, bool> presenceCache = <String, bool>{};

  bool get assetsPresent => _assetsPresent;
  bool get bgmAssetPresent => _bgmAssetPresent;
  bool get ready => _ready && !_disposed;
  bool get bgmReady => _bgmReady && !_disposed;
  bool get isDisposed => _disposed;
  ShapeMatchingSfxPlayer get player => _player;
  ShapeMatchingBgmPlayer get bgmPlayer => _bgm;
  int get lastCelebratedSerial => _lastCelebratedSerial;
  int get lastDuckSerial => _lastDuckSerial;
  int get lifecycleEpoch => _lifecycleEpoch;
  bool get bgmIsPlaying => _bgm.isPlaying;
  bool get bgmIsPaused => _bgm.isPaused;
  double get bgmVolume => _bgm.volume;

  static const requiredCues = <ShapeMatchingSfxCue>[
    ShapeMatchingSfxCue.tapPop,
    ShapeMatchingSfxCue.dragBounce,
    ShapeMatchingSfxCue.correctChime,
    ShapeMatchingSfxCue.softClap,
    ShapeMatchingSfxCue.wrongSoft,
    ShapeMatchingSfxCue.completeJingle,
    ShapeMatchingSfxCue.twinkle,
  ];

  /// Probes bundled SFX + BGM. [localeTag] kept for API compatibility.
  Future<void> probe(String localeTag) async {
    if (_disposed) {
      _ready = false;
      _bgmReady = false;
      return;
    }
    var allPresent = true;
    for (final cue in requiredCues) {
      final present = await _probe(cue.assetPath);
      if (!present) {
        allPresent = false;
        break;
      }
    }
    _assetsPresent = allPresent;
    _ready = allPresent && !soundOff && _player.canPlay && !_disposed;

    _bgmAssetPresent = await _probe(ShapeMatchingBgmTrack.assetPath);
    _bgmReady =
        _bgmAssetPresent && !soundOff && _bgm.canPlay && !_disposed;
  }

  /// Starts or continues the single Happy Garden loop (idempotent).
  Future<bool> ensureBgmPlaying() async {
    if (!_bgmGate()) return false;
    if (_bgm.isPlaying) {
      // Already looping — do not restart between rounds / on replay.
      return true;
    }
    if (_bgm.isPaused) {
      await _bgm.setVolume(_effectiveBgmGain());
      await _bgm.resume();
      return _bgm.isPlaying || _bgm.isPaused == false;
    }
    return _bgm.startLoop(volume: _effectiveBgmGain());
  }

  Future<void> pauseBgm() async {
    if (_disposed) return;
    await _bgm.pause();
  }

  Future<void> resumeBgm() async {
    if (!_bgmGate()) return;
    if (_bgm.isPaused) {
      await _bgm.setVolume(_effectiveBgmGain());
      await _bgm.resume();
      return;
    }
    if (!_bgm.isPlaying) {
      await ensureBgmPlaying();
    }
  }

  Future<bool> playTap() => _playImmediate(ShapeMatchingSfxCue.tapPop);

  Future<bool> playDragBounce() =>
      _playImmediate(ShapeMatchingSfxCue.dragBounce);

  Future<bool> playWrong() => _playImmediate(ShapeMatchingSfxCue.wrongSoft);

  /// Correct match / completion celebrate sequence. Idempotent per [serial].
  Future<bool> playCorrectMatch({
    required int serial,
    required bool isCompletion,
  }) async {
    if (!_gate()) return false;
    if (serial <= 0) return false;
    if (serial <= _lastCelebratedSerial) {
      // Duplicate notify / rapid spam for the same match — ignore.
      return false;
    }
    _lastCelebratedSerial = serial;
    _cancelSequenceTimers();
    final epoch = _lifecycleEpoch;

    // Duck BGM under celebrate; newer serial cancels prior restore.
    // ignore: discarded_futures
    _duckBgmForCelebrate(serial: serial, isCompletion: isCompletion);

    final lead = isCompletion
        ? ShapeMatchingSfxCue.completeJingle
        : ShapeMatchingSfxCue.correctChime;
    final played = await _playCue(lead);
    // Lifecycle epoch covers silence/dispose; serial covers a newer celebrate
    // that started while this lead cue was still in-flight.
    if (!played ||
        _disposed ||
        epoch != _lifecycleEpoch ||
        serial != _lastCelebratedSerial) {
      return false;
    }

    final clapAfter = isCompletion ? completionClapDelay : clapDelay;
    final twinkleAfter =
        isCompletion ? completionTwinkleDelay : twinkleDelay;

    // Drop any orphaned timers a superseded in-flight celebrate may have set.
    _cancelSequenceTimers();
    _clapTimer = Timer(clapAfter, () {
      if (_disposed ||
          epoch != _lifecycleEpoch ||
          serial != _lastCelebratedSerial) {
        return;
      }
      // ignore: discarded_futures
      _playCue(ShapeMatchingSfxCue.softClap);
    });
    _twinkleTimer = Timer(twinkleAfter, () {
      if (_disposed ||
          epoch != _lifecycleEpoch ||
          serial != _lastCelebratedSerial) {
        return;
      }
      // ignore: discarded_futures
      _playCue(ShapeMatchingSfxCue.twinkle);
    });
    return true;
  }

  /// Stops SFX + cancels pending celebrate/duck timers. Optionally pauses BGM
  /// (pause / background / screen-time). Replay keeps BGM with [pauseBgm]=false.
  Future<void> silence({bool pauseBgm = true}) async {
    _lifecycleEpoch++;
    _cancelSequenceTimers();
    _cancelDuckRestore();
    await _player.stopAll();
    if (pauseBgm) {
      await _bgm.pause();
    } else if (_bgm.isPlaying || _bgm.isPaused) {
      // Unduck without stopping the loop.
      await _bgm.setVolume(_effectiveBgmGain());
    }
  }

  /// Full teardown for exit / disposeResources / child switch / Kids Mode leave.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    _bgmReady = false;
    _lifecycleEpoch++;
    _cancelSequenceTimers();
    _cancelDuckRestore();
    await _player.stopAll();
    await _player.dispose();
    await _bgm.stop();
    await _bgm.dispose();
  }

  /// Replay / progress reset — silence SFX, keep same BGM instance looping.
  Future<void> resetForReplay() async {
    await silence(pauseBgm: false);
    _lastCelebratedSerial = 0;
    _lastDuckSerial = 0;
    await ensureBgmPlaying();
  }

  void _cancelSequenceTimers() {
    _clapTimer?.cancel();
    _twinkleTimer?.cancel();
    _clapTimer = null;
    _twinkleTimer = null;
  }

  void _cancelDuckRestore() {
    _duckRestoreTimer?.cancel();
    _duckRestoreTimer = null;
  }

  double _effectiveBgmGain() => bgmGain.clamp(0.0, 1.0);

  double _duckedBgmGain() =>
      (_effectiveBgmGain() * bgmDuckFactor).clamp(0.0, 1.0);

  bool _bgmGate() {
    if (_disposed || soundOff || !_bgmReady || !_bgm.canPlay) {
      return false;
    }
    return true;
  }

  Future<void> _duckBgmForCelebrate({
    required int serial,
    required bool isCompletion,
  }) async {
    if (!_bgmGate()) return;
    if (!_bgm.isPlaying && !_bgm.isPaused) return;
    if (serial < _lastDuckSerial) return;
    _lastDuckSerial = serial;
    final epoch = _lifecycleEpoch;
    _cancelDuckRestore();
    await _bgm.setVolume(_duckedBgmGain());
    final restoreAfter =
        isCompletion ? completionDuckRestore : matchDuckRestore;
    _duckRestoreTimer = Timer(restoreAfter, () {
      if (_disposed ||
          epoch != _lifecycleEpoch ||
          serial != _lastDuckSerial) {
        return;
      }
      // ignore: discarded_futures
      _bgm.setVolume(_effectiveBgmGain());
    });
  }

  bool _gate() {
    if (_disposed || soundOff || !_ready || !_player.canPlay) {
      return false;
    }
    return true;
  }

  Future<bool> _playImmediate(ShapeMatchingSfxCue cue) async {
    if (!_gate()) return false;
    return _playCue(cue);
  }

  Future<bool> _playCue(ShapeMatchingSfxCue cue) async {
    if (!_gate()) return false;
    try {
      return await _player.play(cue, volume: sfxGain.clamp(0.0, 1.0));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probe(String path) async {
    final cached = presenceCache[path];
    if (cached != null) return cached;
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
  void clearPresenceCache() {
    presenceCache.clear();
  }

  @visibleForTesting
  bool get ownsDefaultPlayer => _ownsDefaultPlayer;

  @visibleForTesting
  bool get ownsDefaultBgm => _ownsDefaultBgm;
}

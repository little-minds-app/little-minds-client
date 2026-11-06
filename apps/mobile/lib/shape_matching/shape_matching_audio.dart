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

/// Offline SFX player port — inject [RecordingShapeMatchingSfxPlayer] in tests.
abstract class ShapeMatchingSfxPlayer {
  /// True only when this player can actually emit audio.
  bool get canPlay;

  Future<bool> play(ShapeMatchingSfxCue cue);

  Future<void> stopAll();

  Future<void> dispose();
}

/// Default no-op when a real engine cannot be constructed (or for DI stubs).
class UnavailableShapeMatchingSfxPlayer implements ShapeMatchingSfxPlayer {
  const UnavailableShapeMatchingSfxPlayer();

  @override
  bool get canPlay => false;

  @override
  Future<bool> play(ShapeMatchingSfxCue cue) async => false;

  @override
  Future<void> stopAll() async {}

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
  Future<bool> play(ShapeMatchingSfxCue cue) async {
    if (!holdPlays) {
      plays.add(cue);
      return succeed && canPlay;
    }
    final held = _HeldPlay(cue);
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
  _HeldPlay(this.cue);

  final ShapeMatchingSfxCue cue;
  final Completer<bool> completer = Completer<bool>();
}

/// Production offline player using [audioplayers] + ambient iOS session
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
  Future<bool> play(ShapeMatchingSfxCue cue) async {
    if (_disposed) return false;
    await _ensureSession();
    AudioPlayer? player;
    try {
      player = AudioPlayer();
      _active.add(player);
      await player.setReleaseMode(ReleaseMode.release).timeout(_opTimeout);
      await player.setPlayerMode(PlayerMode.lowLatency).timeout(_opTimeout);
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

/// Shape Matching offline SFX — reuses a single injectable player; no downloads.
///
/// Celebrate mapping (no gameplay delay):
/// - Mid-match: [correctChime] → delayed [softClap] → optional [twinkle]
/// - Completion: [completeJingle] → delayed [softClap] → [twinkle] (richer)
///
/// Anti-spam: one celebrate sequence per [correctMatchSerial]; duplicate notify
/// ignored; a newer serial cancels prior timers and invalidates any older
/// in-flight lead [await] so superseded celebrations cannot schedule delayed
/// clap/twinkle. [silence] / [dispose] bump lifecycle epoch for the same.
class ShapeMatchingAudio {
  ShapeMatchingAudio({
    this.soundOff = false,
    ShapeMatchingSfxPlayer? player,
    AssetBundle? bundle,
    this.clapDelay = const Duration(milliseconds: 140),
    this.twinkleDelay = const Duration(milliseconds: 520),
    this.completionClapDelay = const Duration(milliseconds: 180),
    this.completionTwinkleDelay = const Duration(milliseconds: 620),
  })  : _bundle = bundle ?? rootBundle,
        _player = player ?? AudioplayersShapeMatchingSfxPlayer(),
        _ownsDefaultPlayer = player == null;

  final bool soundOff;
  final AssetBundle _bundle;
  final ShapeMatchingSfxPlayer _player;
  final bool _ownsDefaultPlayer;

  /// Delay from chime/jingle start to bunny-paw clap (mid-match).
  final Duration clapDelay;

  /// Delay from chime start to optional twinkle (mid-match).
  final Duration twinkleDelay;

  final Duration completionClapDelay;
  final Duration completionTwinkleDelay;

  var _assetsPresent = false;
  var _ready = false;
  var _disposed = false;
  var _lifecycleEpoch = 0;
  var _lastCelebratedSerial = 0;
  Timer? _clapTimer;
  Timer? _twinkleTimer;

  @visibleForTesting
  final Map<String, bool> presenceCache = <String, bool>{};

  bool get assetsPresent => _assetsPresent;
  bool get ready => _ready && !_disposed;
  bool get isDisposed => _disposed;
  ShapeMatchingSfxPlayer get player => _player;
  int get lastCelebratedSerial => _lastCelebratedSerial;
  int get lifecycleEpoch => _lifecycleEpoch;

  static const requiredCues = <ShapeMatchingSfxCue>[
    ShapeMatchingSfxCue.tapPop,
    ShapeMatchingSfxCue.dragBounce,
    ShapeMatchingSfxCue.correctChime,
    ShapeMatchingSfxCue.softClap,
    ShapeMatchingSfxCue.wrongSoft,
    ShapeMatchingSfxCue.completeJingle,
    ShapeMatchingSfxCue.twinkle,
  ];

  /// Probes bundled SFX. [localeTag] kept for API compatibility (SFX are shared).
  Future<void> probe(String localeTag) async {
    if (_disposed) {
      _ready = false;
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

  /// Stops playback + cancels pending celebrate timers (pause / background /
  /// screen-time / replay / navigation). Does not dispose the player.
  Future<void> silence() async {
    _lifecycleEpoch++;
    _cancelSequenceTimers();
    await _player.stopAll();
  }

  /// Full teardown for exit / disposeResources / child switch.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    _lifecycleEpoch++;
    _cancelSequenceTimers();
    await _player.stopAll();
    await _player.dispose();
  }

  /// Replay / progress reset — silence + allow celebrate serials from scratch.
  Future<void> resetForReplay() async {
    await silence();
    _lastCelebratedSerial = 0;
  }

  void _cancelSequenceTimers() {
    _clapTimer?.cancel();
    _twinkleTimer?.cancel();
    _clapTimer = null;
    _twinkleTimer = null;
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
      return await _player.play(cue);
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
}

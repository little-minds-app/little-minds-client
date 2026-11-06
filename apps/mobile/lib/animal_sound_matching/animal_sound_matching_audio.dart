import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'animal_sound_matching_logic.dart';

/// Bundled preschool SFX cues for Animal Sound Matching (offline, locale-agnostic).
///
/// Paths: `assets/audio/animal_sound_matching/sfx/<file>.wav`
enum AnimalSoundMatchingSfxCue {
  tapPop('tap_pop.wav'),
  dragBounce('drag_bounce.wav'),
  correctChime('correct_chime.wav'),
  softClap('soft_clap.wav'),
  wrongSoft('wrong_soft.wav'),
  completeJingle('complete_jingle.wav'),
  twinkle('twinkle.wav');

  const AnimalSoundMatchingSfxCue(this.fileName);
  final String fileName;

  /// Full Flutter asset key (pubspec / rootBundle).
  String get assetPath => 'assets/audio/animal_sound_matching/sfx/$fileName';

  /// [AssetSource] path relative to the Flutter assets root.
  String get assetSourcePath => 'audio/animal_sound_matching/sfx/$fileName';
}

/// Bundled Animal Garden BGM loop (offline, instrumental).
abstract final class AnimalSoundMatchingBgmTrack {
  static const fileName = 'animal_garden_loop.mp3';
  static const assetPath =
      'assets/audio/animal_sound_matching/bgm/$fileName';
  static const assetSourcePath = 'audio/animal_sound_matching/bgm/$fileName';
}

/// Bundled stylized animal vocalization prompts (offline).
///
/// Original synthesis — not field recordings. Provenance lives beside assets.
abstract final class AnimalSoundMatchingAnimalTrack {
  static String assetPath(AnimalKind kind) =>
      'assets/audio/animal_sound_matching/animals/${kind.name}.wav';

  static String assetSourcePath(AnimalKind kind) =>
      'audio/animal_sound_matching/animals/${kind.name}.wav';
}

/// Single-slot animal prompt port — never stacks overlapping prompts.
///
/// Playback is generation-owned: a stale [play]/[stop] for an older
/// [generation] must neither restart old audio nor silence a newer owner.
abstract class AnimalSoundMatchingAnimalPlayer {
  bool get canPlay;
  bool get isPlaying;

  /// Generation that currently owns the bus (0 when idle / fully stopped).
  int get activeGeneration;

  /// Stops any lower-generation prompt, then plays [kind] owned by [generation].
  /// Returns false when superseded, disposed, or playback fails.
  Future<bool> play(
    AnimalKind kind, {
    required double volume,
    required int generation,
  });

  /// Stops the bus.
  ///
  /// When [generation] is non-null, stops only if that generation still owns
  /// the bus — a stale caller cannot silence a newer prompt. When null, stops
  /// unconditionally (pause / background / dispose / screen-time).
  Future<void> stop({int? generation});

  Future<void> dispose();
}

class UnavailableAnimalSoundMatchingAnimalPlayer
    implements AnimalSoundMatchingAnimalPlayer {
  const UnavailableAnimalSoundMatchingAnimalPlayer();

  @override
  bool get canPlay => false;

  @override
  bool get isPlaying => false;

  @override
  int get activeGeneration => 0;

  @override
  Future<bool> play(
    AnimalKind kind, {
    required double volume,
    required int generation,
  }) async =>
      false;

  @override
  Future<void> stop({int? generation}) async {}

  @override
  Future<void> dispose() async {}
}

/// Test double that records animal prompt plays without speakers.
///
/// When [holdPlays] is true, each [play] parks until [releaseNextPlay] —
/// used for deterministic lifecycle / rapid-replay race tests.
class RecordingAnimalSoundMatchingAnimalPlayer
    implements AnimalSoundMatchingAnimalPlayer {
  RecordingAnimalSoundMatchingAnimalPlayer({
    this.canPlay = true,
    this.holdPlays = false,
  });

  @override
  bool canPlay;

  /// When true, [play] awaits an explicit [releaseNextPlay] before recording.
  bool holdPlays;

  @override
  bool isPlaying = false;

  @override
  int activeGeneration = 0;

  final List<AnimalKind> plays = <AnimalKind>[];
  final List<double> volumes = <double>[];
  final List<int> playGenerations = <int>[];
  var succeed = true;
  var stopCount = 0;
  var disposeCount = 0;

  /// Generations that were refused a stop because a newer owner held the bus.
  final List<int> ignoredStops = <int>[];

  final List<_HeldAnimalPlay> _heldPlays = <_HeldAnimalPlay>[];

  int get pendingPlayCount => _heldPlays.length;

  AnimalKind? get nextHeldKind =>
      _heldPlays.isEmpty ? null : _heldPlays.first.kind;

  int? get nextHeldGeneration =>
      _heldPlays.isEmpty ? null : _heldPlays.first.generation;

  /// Completes the oldest held [play]. Returns false if none are pending.
  bool releaseNextPlay({bool? succeedOverride}) {
    if (_heldPlays.isEmpty) return false;
    final held = _heldPlays.removeAt(0);
    // Superseded while held — never record as an audible play.
    if (activeGeneration != held.generation) {
      held.completer.complete(false);
      return true;
    }
    final ok = succeedOverride ?? (succeed && canPlay && disposeCount == 0);
    if (ok) {
      plays.add(held.kind);
      volumes.add(held.volume);
      playGenerations.add(held.generation);
      isPlaying = true;
      activeGeneration = held.generation;
    } else {
      isPlaying = false;
      if (activeGeneration == held.generation) {
        activeGeneration = 0;
      }
    }
    held.completer.complete(ok);
    return true;
  }

  void releaseAllPlays({bool? succeedOverride}) {
    while (_heldPlays.isNotEmpty) {
      releaseNextPlay(succeedOverride: succeedOverride);
    }
  }

  void _failHeld({required bool Function(_HeldAnimalPlay held) match}) {
    final remaining = <_HeldAnimalPlay>[];
    for (final held in _heldPlays) {
      if (match(held)) {
        held.completer.complete(false);
      } else {
        remaining.add(held);
      }
    }
    _heldPlays
      ..clear()
      ..addAll(remaining);
  }

  @override
  Future<bool> play(
    AnimalKind kind, {
    required double volume,
    required int generation,
  }) async {
    // Claim the bus for this generation — supersede older owners.
    activeGeneration = generation;
    if (isPlaying) {
      stopCount++;
      isPlaying = false;
    }
    // Cancel still-held plays from older generations only.
    _failHeld(match: (held) => held.generation < generation);

    if (!holdPlays) {
      if (!canPlay || !succeed || disposeCount > 0) {
        if (activeGeneration == generation) {
          activeGeneration = 0;
        }
        return false;
      }
      // Late check: a newer claim may have arrived while we were sync.
      if (activeGeneration != generation) return false;
      plays.add(kind);
      volumes.add(volume);
      playGenerations.add(generation);
      isPlaying = true;
      // Instant complete for unit tests — keep isPlaying true so ownership
      // races can observe the active owner until an explicit stop/supersede.
      return true;
    }
    final held = _HeldAnimalPlay(kind, volume, generation);
    _heldPlays.add(held);
    return held.completer.future;
  }

  @override
  Future<void> stop({int? generation}) async {
    if (generation != null && activeGeneration != generation) {
      ignoredStops.add(generation);
      // Still fail our own held play if present, without touching newer audio.
      _failHeld(match: (held) => held.generation == generation);
      return;
    }
    stopCount++;
    isPlaying = false;
    activeGeneration = 0;
    _failHeld(match: (_) => true);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    canPlay = false;
    isPlaying = false;
    activeGeneration = 0;
    _failHeld(match: (_) => true);
  }
}

class _HeldAnimalPlay {
  _HeldAnimalPlay(this.kind, this.volume, this.generation);

  final AnimalKind kind;
  final double volume;
  final int generation;
  final Completer<bool> completer = Completer<bool>();
}

/// Native animal-prompt engine port — stop / configure / play / dispose.
///
/// Production uses [AudioplayersAnimalSoundMatchingNativeEngine]. Tests inject
/// [ControllableAnimalSoundMatchingNativeEngine] so delayed engine ops can
/// complete in reverse order without a real AudioPlayer.
abstract class AnimalSoundMatchingNativeEngine {
  /// Asset path currently applied on the shared native bus, if any.
  String? get audibleAsset;

  Future<void> ensureSession();

  Future<void> stop();

  Future<void> configure({required double volume});

  Future<void> play(String assetSourcePath);

  /// Emits when the current native play finishes naturally.
  Stream<void> get onComplete;

  Future<void> dispose();
}

/// Production [audioplayers] engine — single shared [AudioPlayer] bus.
class AudioplayersAnimalSoundMatchingNativeEngine
    implements AnimalSoundMatchingNativeEngine {
  AudioPlayer? _player;
  var _sessionConfigured = false;
  var _disposed = false;
  String? _audibleAsset;

  static const _opTimeout = Duration(milliseconds: 400);

  @override
  String? get audibleAsset => _audibleAsset;

  @override
  Stream<void> get onComplete {
    final player = _player;
    if (player == null) return const Stream<void>.empty();
    return player.onPlayerComplete;
  }

  @override
  Future<void> ensureSession() async {
    if (_disposed || _sessionConfigured) return;
    _sessionConfigured = true;
    try {
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
    } catch (_) {}
  }

  Future<AudioPlayer> _bus() async {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer();
    _player = created;
    return created;
  }

  @override
  Future<void> stop() async {
    _audibleAsset = null;
    final player = _player;
    if (player == null || _disposed) return;
    try {
      await player.stop().timeout(_opTimeout);
    } catch (_) {}
  }

  @override
  Future<void> configure({required double volume}) async {
    if (_disposed) return;
    final player = await _bus();
    if (_disposed) return;
    await player.setReleaseMode(ReleaseMode.release).timeout(_opTimeout);
    if (_disposed) return;
    await player.setPlayerMode(PlayerMode.lowLatency).timeout(_opTimeout);
    if (_disposed) return;
    await player.setVolume(volume.clamp(0.0, 1.0)).timeout(_opTimeout);
  }

  @override
  Future<void> play(String assetSourcePath) async {
    if (_disposed) return;
    final player = await _bus();
    if (_disposed) return;
    await player.play(AssetSource(assetSourcePath)).timeout(_opTimeout);
    if (_disposed) {
      _audibleAsset = null;
      return;
    }
    _audibleAsset = assetSourcePath;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _audibleAsset = null;
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

/// Controllable native engine for deterministic reverse-completion race tests.
///
/// When [holdOperations] is true, each stop/configure/play parks until
/// [releaseNextOperation]. Completing a held [play] applies [audibleAsset]
/// (simulating a late native `AudioPlayer.play` result on a shared bus).
class ControllableAnimalSoundMatchingNativeEngine
    implements AnimalSoundMatchingNativeEngine {
  ControllableAnimalSoundMatchingNativeEngine({this.holdOperations = false});

  bool holdOperations;
  var ensureSessionCount = 0;
  var stopCount = 0;
  var configureCount = 0;
  var playCount = 0;
  var disposeCount = 0;
  var maxInFlightPlays = 0;
  var _inFlightPlays = 0;

  String? _audibleAsset;
  final List<String> playCompletions = <String>[];
  final List<_HeldNativeOp> _held = <_HeldNativeOp>[];
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();

  @override
  String? get audibleAsset => _audibleAsset;

  @override
  Stream<void> get onComplete => _completeController.stream;

  int get pendingOperationCount => _held.length;

  String? get nextHeldType => _held.isEmpty ? null : _held.first.type;

  String? get nextHeldPlayAsset =>
      _held.where((op) => op.type == 'play').map((op) => op.asset).firstOrNull;

  /// Completes the oldest held op. Returns false when none are pending.
  bool releaseNextOperation({bool fail = false}) {
    if (_held.isEmpty) return false;
    final held = _held.removeAt(0);
    if (fail) {
      if (held.type == 'play') {
        _inFlightPlays = (_inFlightPlays - 1).clamp(0, 1 << 30);
      }
      held.completer.completeError(StateError('forced engine failure'));
      return true;
    }
    switch (held.type) {
      case 'stop':
        _audibleAsset = null;
        stopCount++;
      case 'configure':
        configureCount++;
      case 'play':
        _audibleAsset = held.asset;
        playCompletions.add(held.asset!);
        playCount++;
        _inFlightPlays = (_inFlightPlays - 1).clamp(0, 1 << 30);
      case 'dispose':
        _audibleAsset = null;
        disposeCount++;
        if (!_completeController.isClosed) {
          // ignore: discarded_futures
          _completeController.close();
        }
    }
    held.completer.complete();
    return true;
  }

  void releaseAllOperations() {
    while (_held.isNotEmpty) {
      releaseNextOperation();
    }
  }

  /// Completes the newest held play first (reverse completion order).
  bool releaseNewestHeldPlay() {
    for (var i = _held.length - 1; i >= 0; i--) {
      if (_held[i].type != 'play') continue;
      final held = _held.removeAt(i);
      _audibleAsset = held.asset;
      playCompletions.add(held.asset!);
      playCount++;
      _inFlightPlays = (_inFlightPlays - 1).clamp(0, 1 << 30);
      held.completer.complete();
      return true;
    }
    return false;
  }

  Future<void> _enqueue(String type, {String? asset}) {
    if (!holdOperations) {
      switch (type) {
        case 'stop':
          _audibleAsset = null;
          stopCount++;
        case 'configure':
          configureCount++;
        case 'play':
          _audibleAsset = asset;
          playCompletions.add(asset!);
          playCount++;
        case 'dispose':
          _audibleAsset = null;
          disposeCount++;
      }
      return Future<void>.value();
    }
    final held = _HeldNativeOp(type, asset);
    if (type == 'play') {
      _inFlightPlays++;
      if (_inFlightPlays > maxInFlightPlays) {
        maxInFlightPlays = _inFlightPlays;
      }
    }
    _held.add(held);
    return held.completer.future;
  }

  @override
  Future<void> ensureSession() async {
    ensureSessionCount++;
  }

  @override
  Future<void> stop() => _enqueue('stop');

  @override
  Future<void> configure({required double volume}) => _enqueue('configure');

  @override
  Future<void> play(String assetSourcePath) =>
      _enqueue('play', asset: assetSourcePath);

  @override
  Future<void> dispose() async {
    if (holdOperations) {
      await _enqueue('dispose');
      return;
    }
    _audibleAsset = null;
    disposeCount++;
    if (!_completeController.isClosed) {
      await _completeController.close();
    }
  }

  void emitNaturalComplete() {
    if (!_completeController.isClosed) {
      _completeController.add(null);
    }
  }
}

class _HeldNativeOp {
  _HeldNativeOp(this.type, this.asset);

  final String type;
  final String? asset;
  final Completer<void> completer = Completer<void>();
}

/// Production single-slot animal prompt player (ambient / no exclusive focus).
///
/// Native stop/configure/play/dispose ops are serialized on one engine bus so a
/// stale `play(old)` cannot complete after `play(new)` and override it.
/// Generation ownership still gates every async boundary: stale stop cannot
/// silence a newer owner; pause/dispose invalidate pending playback safely.
class AudioplayersAnimalSoundMatchingAnimalPlayer
    implements AnimalSoundMatchingAnimalPlayer {
  AudioplayersAnimalSoundMatchingAnimalPlayer({
    AnimalSoundMatchingNativeEngine? engine,
  }) : _engine = engine ?? AudioplayersAnimalSoundMatchingNativeEngine();

  final AnimalSoundMatchingNativeEngine _engine;
  var _disposed = false;
  var _playing = false;
  var _activeGeneration = 0;

  /// Serializes native engine mutations (last enqueued owner wins after checks).
  Future<void> _engineChain = Future<void>.value();

  @override
  bool get canPlay => !_disposed;

  @override
  bool get isPlaying => _playing && !_disposed;

  @override
  int get activeGeneration => _activeGeneration;

  /// Asset currently applied on the native bus (test / diagnostics).
  String? get audibleAsset => _engine.audibleAsset;

  bool _owns(int generation) =>
      !_disposed && _activeGeneration == generation;

  Future<T> _runOnEngine<T>(Future<T> Function() body) {
    final done = Completer<T>();
    _engineChain = _engineChain.catchError((_) {}).then((_) async {
      try {
        done.complete(await body());
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  @override
  Future<bool> play(
    AnimalKind kind, {
    required double volume,
    required int generation,
  }) async {
    if (_disposed) return false;
    // Claim ownership before awaiting so older stop/play cannot win the bus.
    _activeGeneration = generation;
    final path = AnimalSoundMatchingAnimalTrack.assetSourcePath(kind);
    return _runOnEngine(() async {
      if (!_owns(generation)) return false;
      _playing = false;
      await _engine.stop();
      if (!_owns(generation)) return false;
      await _engine.ensureSession();
      if (!_owns(generation)) return false;
      await _engine.configure(volume: volume.clamp(0.0, 1.0));
      if (!_owns(generation)) return false;
      try {
        await _engine.play(path);
      } catch (_) {
        if (_owns(generation)) {
          _playing = false;
          _activeGeneration = 0;
        }
        return false;
      }
      if (!_owns(generation)) {
        // Superseded or disposed after a late native start — never reclaim the
        // bus, and never stop a newer owner.
        return false;
      }
      _playing = true;
      final ownedGeneration = generation;
      unawaited(
        _engine.onComplete.first
            .timeout(const Duration(seconds: 4))
            .then((_) {
          if (!_disposed && _activeGeneration == ownedGeneration) {
            _playing = false;
            _activeGeneration = 0;
          }
        }).catchError((_) {
          if (!_disposed && _activeGeneration == ownedGeneration) {
            _playing = false;
            _activeGeneration = 0;
          }
        }),
      );
      return true;
    });
  }

  @override
  Future<void> stop({int? generation}) async {
    if (generation != null && _activeGeneration != generation) {
      return;
    }
    // Invalidate immediately so in-flight play awaits fail ownership checks.
    _activeGeneration = 0;
    _playing = false;
    await _runOnEngine(() async {
      // A newer play may have claimed the bus while we waited on the chain.
      if (_disposed || _activeGeneration != 0) return;
      await _engine.stop();
    });
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playing = false;
    _activeGeneration = 0;
    await _runOnEngine(() async {
      await _engine.dispose();
    });
  }
}

/// Offline SFX player port — inject [RecordingAnimalSoundMatchingSfxPlayer] in tests.
abstract class AnimalSoundMatchingSfxPlayer {
  /// True only when this player can actually emit audio.
  bool get canPlay;

  Future<bool> play(AnimalSoundMatchingSfxCue cue, {required double volume});

  Future<void> stopAll();

  Future<void> dispose();
}

/// Separate single-instance BGM port — loop / pause / resume / stop / dispose.
abstract class AnimalSoundMatchingBgmPlayer {
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
class UnavailableAnimalSoundMatchingSfxPlayer implements AnimalSoundMatchingSfxPlayer {
  const UnavailableAnimalSoundMatchingSfxPlayer();

  @override
  bool get canPlay => false;

  @override
  Future<bool> play(AnimalSoundMatchingSfxCue cue, {required double volume}) async =>
      false;

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

class UnavailableAnimalSoundMatchingBgmPlayer implements AnimalSoundMatchingBgmPlayer {
  const UnavailableAnimalSoundMatchingBgmPlayer();

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
class RecordingAnimalSoundMatchingSfxPlayer implements AnimalSoundMatchingSfxPlayer {
  RecordingAnimalSoundMatchingSfxPlayer({
    this.canPlay = true,
    this.holdPlays = false,
  });

  @override
  bool canPlay;

  /// When true, [play] awaits an explicit [releaseNextPlay] before recording.
  bool holdPlays;

  final List<AnimalSoundMatchingSfxCue> plays = <AnimalSoundMatchingSfxCue>[];
  final List<double> volumes = <double>[];
  var succeed = true;
  var stopCount = 0;
  var disposeCount = 0;

  final List<_HeldPlay> _heldPlays = <_HeldPlay>[];

  /// Number of [play] calls currently waiting on a release gate.
  int get pendingPlayCount => _heldPlays.length;

  /// Cue for the oldest held [play], if any.
  AnimalSoundMatchingSfxCue? get nextHeldCue =>
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
  Future<bool> play(AnimalSoundMatchingSfxCue cue, {required double volume}) async {
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

  final AnimalSoundMatchingSfxCue cue;
  final double volume;
  final Completer<bool> completer = Completer<bool>();
}

/// Recording BGM double for deterministic lifecycle / duck tests.
///
/// When [holdOperations] is true, [startLoop] / [setVolume] / [resume] park on a
/// completer until [releaseNextOperation] — used for delayed-future race tests
/// without wall-clock sleeps. [pause] / [stop] / [dispose] never hold so they
/// can win in-flight startup / duck races immediately.
class RecordingAnimalSoundMatchingBgmPlayer implements AnimalSoundMatchingBgmPlayer {
  RecordingAnimalSoundMatchingBgmPlayer({
    this.canPlay = true,
    this.holdOperations = false,
  });

  @override
  bool canPlay;

  /// When true, async start/volume/resume await an explicit release gate.
  bool holdOperations;

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

  final List<Completer<void>> _heldOps = <Completer<void>>[];

  /// Number of BGM ops currently waiting on a release gate.
  int get pendingOperationCount => _heldOps.length;

  /// Completes the oldest held op. Returns false if none are pending.
  bool releaseNextOperation() {
    if (_heldOps.isEmpty) return false;
    _heldOps.removeAt(0).complete();
    return true;
  }

  /// Completes every held op in FIFO order.
  void releaseAllOperations() {
    while (_heldOps.isNotEmpty) {
      releaseNextOperation();
    }
  }

  Future<void> _awaitOperationGate() async {
    if (!holdOperations) return;
    final held = Completer<void>();
    _heldOps.add(held);
    await held.future;
  }

  @override
  Future<bool> startLoop({required double volume}) async {
    await _awaitOperationGate();
    if (!canPlay || !succeed || disposeCount > 0) return false;
    startLoopCount++;
    this.volume = volume;
    volumeHistory.add(volume);
    isPlaying = true;
    isPaused = false;
    return true;
  }

  @override
  Future<void> setVolume(double volume) async {
    await _awaitOperationGate();
    if (disposeCount > 0 || !canPlay) return;
    this.volume = volume;
    volumeHistory.add(volume);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    if (isPlaying || isPaused) {
      isPaused = true;
      isPlaying = false;
    }
  }

  @override
  Future<void> resume() async {
    await _awaitOperationGate();
    if (disposeCount > 0 || !canPlay) return;
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
    // Fail-open held ops so in-flight ensure/duck awaits do not hang.
    releaseAllOperations();
  }
}

/// Production offline SFX player using [audioplayers] + ambient iOS session
/// (respects the hardware silent switch; mixes with other audio).
class AudioplayersAnimalSoundMatchingSfxPlayer implements AnimalSoundMatchingSfxPlayer {
  AudioplayersAnimalSoundMatchingSfxPlayer();

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
  Future<bool> play(AnimalSoundMatchingSfxCue cue, {required double volume}) async {
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
class AudioplayersAnimalSoundMatchingBgmPlayer implements AnimalSoundMatchingBgmPlayer {
  AudioplayersAnimalSoundMatchingBgmPlayer();

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
      return !_disposed && _playing && !_paused;
    }
    if (_player != null && _paused) {
      await setVolume(_volume);
      if (_disposed) return false;
      await resume();
      return !_disposed && isPlaying;
    }
    await _ensureSession();
    if (_disposed) return false;
    try {
      final player = _player ?? AudioPlayer();
      if (_disposed) return false;
      _player = player;
      await player.setReleaseMode(ReleaseMode.loop).timeout(_opTimeout);
      if (_disposed) return false;
      await player.setPlayerMode(PlayerMode.mediaPlayer).timeout(_opTimeout);
      if (_disposed) return false;
      await player.setVolume(_volume).timeout(_opTimeout);
      if (_disposed) return false;
      await player
          .play(AssetSource(AnimalSoundMatchingBgmTrack.assetSourcePath))
          .timeout(_opTimeout);
      if (_disposed) return false;
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
      if (_disposed) return;
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
      if (_disposed) return;
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

/// Animal Sound Matching offline audio — SFX + separate Animal Garden BGM.
///
/// Celebrate mapping (no gameplay delay):
/// - Mid-match: [correctChime] → delayed [softClap] → optional [twinkle]
/// - Completion: [completeJingle] → delayed [softClap] → [twinkle] (richer)
///
/// BGM ducks under celebrate (restore after sequence); duck serial cancels
/// superseded restores on rapid matches. [silence] pauses BGM; [resetForReplay]
/// keeps the same BGM instance looping (no duplicate start); [dispose] stops.
class AnimalSoundMatchingAudio {
  AnimalSoundMatchingAudio({
    this.soundOff = false,
    AnimalSoundMatchingSfxPlayer? player,
    AnimalSoundMatchingBgmPlayer? bgmPlayer,
    AnimalSoundMatchingAnimalPlayer? animalPlayer,
    AssetBundle? bundle,
    this.clapDelay = const Duration(milliseconds: 140),
    this.twinkleDelay = const Duration(milliseconds: 520),
    this.completionClapDelay = const Duration(milliseconds: 180),
    this.completionTwinkleDelay = const Duration(milliseconds: 620),
    this.bgmGain = 0.20,
    this.sfxGain = 0.85,
    this.animalPromptGain = 0.95,
    this.bgmDuckFactor = 0.25,
    this.matchDuckRestore = const Duration(milliseconds: 900),
    this.completionDuckRestore = const Duration(milliseconds: 1300),
    this.promptDuckRestore = const Duration(milliseconds: 1100),
  })  : _bundle = bundle ?? rootBundle,
        _player = player ?? AudioplayersAnimalSoundMatchingSfxPlayer(),
        _bgm = bgmPlayer ?? AudioplayersAnimalSoundMatchingBgmPlayer(),
        _animal = animalPlayer ??
            AudioplayersAnimalSoundMatchingAnimalPlayer(),
        _ownsDefaultPlayer = player == null,
        _ownsDefaultBgm = bgmPlayer == null,
        _ownsDefaultAnimal = animalPlayer == null;

  final bool soundOff;
  final AssetBundle _bundle;
  final AnimalSoundMatchingSfxPlayer _player;
  final AnimalSoundMatchingBgmPlayer _bgm;
  final AnimalSoundMatchingAnimalPlayer _animal;
  final bool _ownsDefaultPlayer;
  final bool _ownsDefaultBgm;
  final bool _ownsDefaultAnimal;

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

  /// Animal prompt gain — kept above BGM/SFX so recognition stays intelligible.
  final double animalPromptGain;

  /// Multiplier applied to [bgmGain] while ducked under celebrate / prompts.
  final double bgmDuckFactor;

  /// Time from celebrate start until BGM volume restores (mid-match).
  final Duration matchDuckRestore;

  /// Longer restore window for session-complete celebrate.
  final Duration completionDuckRestore;

  /// Restore window after an animal prompt ducks BGM.
  final Duration promptDuckRestore;

  var _assetsPresent = false;
  var _bgmAssetPresent = false;
  var _animalAssetsPresent = false;
  var _ready = false;
  var _bgmReady = false;
  var _animalPromptReady = false;
  var _disposed = false;
  var _lifecycleEpoch = 0;
  var _lastCelebratedSerial = 0;
  var _lastDuckSerial = 0;
  var _animalPromptSerial = 0;
  Timer? _clapTimer;
  Timer? _twinkleTimer;
  Timer? _duckRestoreTimer;

  @visibleForTesting
  final Map<String, bool> presenceCache = <String, bool>{};

  bool get assetsPresent => _assetsPresent;
  bool get bgmAssetPresent => _bgmAssetPresent;
  bool get animalAssetsPresent => _animalAssetsPresent;
  bool get ready => _ready && !_disposed;
  bool get bgmReady => _bgmReady && !_disposed;
  bool get animalPromptReady => _animalPromptReady && !_disposed;
  bool get isDisposed => _disposed;
  AnimalSoundMatchingSfxPlayer get player => _player;
  AnimalSoundMatchingBgmPlayer get bgmPlayer => _bgm;
  AnimalSoundMatchingAnimalPlayer get animalPlayer => _animal;
  int get lastCelebratedSerial => _lastCelebratedSerial;
  int get lastDuckSerial => _lastDuckSerial;
  int get animalPromptSerial => _animalPromptSerial;
  int get lifecycleEpoch => _lifecycleEpoch;
  bool get bgmIsPlaying => _bgm.isPlaying;
  bool get bgmIsPaused => _bgm.isPaused;
  double get bgmVolume => _bgm.volume;

  static const requiredCues = <AnimalSoundMatchingSfxCue>[
    AnimalSoundMatchingSfxCue.tapPop,
    AnimalSoundMatchingSfxCue.dragBounce,
    AnimalSoundMatchingSfxCue.correctChime,
    AnimalSoundMatchingSfxCue.softClap,
    AnimalSoundMatchingSfxCue.wrongSoft,
    AnimalSoundMatchingSfxCue.completeJingle,
    AnimalSoundMatchingSfxCue.twinkle,
  ];

  /// Probes bundled SFX + BGM + animal prompts. [localeTag] for API compatibility.
  Future<void> probe(String localeTag) async {
    if (_disposed) {
      _ready = false;
      _bgmReady = false;
      _animalPromptReady = false;
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

    _bgmAssetPresent = await _probe(AnimalSoundMatchingBgmTrack.assetPath);
    _bgmReady =
        _bgmAssetPresent && !soundOff && _bgm.canPlay && !_disposed;

    var animalsPresent = true;
    for (final kind in AnimalKind.values) {
      final present =
          await _probe(AnimalSoundMatchingAnimalTrack.assetPath(kind));
      if (!present) {
        animalsPresent = false;
        break;
      }
    }
    _animalAssetsPresent = animalsPresent;
    _animalPromptReady =
        animalsPresent && !soundOff && _animal.canPlay && !_disposed;
  }

  /// Starts or continues the single Happy Garden loop (idempotent).
  ///
  /// Captures [lifecycleEpoch] before awaits so a concurrent pause / screen-time
  /// silence / nav dispose cannot leave a late [startLoop] or [resume] audible.
  Future<bool> ensureBgmPlaying() async {
    if (!_bgmGate()) return false;
    if (_bgm.isPlaying) {
      // Already looping — do not restart between rounds / on replay.
      return true;
    }
    final epoch = _lifecycleEpoch;
    if (_bgm.isPaused) {
      await _bgm.setVolume(_effectiveBgmGain());
      if (!_bgmStartupStillValid(epoch)) {
        return false;
      }
      await _bgm.resume();
      if (!_bgmStartupStillValid(epoch)) {
        await _rollbackSupersededBgmStartup();
        return false;
      }
      return _bgm.isPlaying;
    }
    final started = await _bgm.startLoop(volume: _effectiveBgmGain());
    if (!started) return false;
    if (!_bgmStartupStillValid(epoch)) {
      await _rollbackSupersededBgmStartup();
      return false;
    }
    return _bgm.isPlaying;
  }

  Future<void> pauseBgm() async {
    if (_disposed) return;
    await _bgm.pause();
  }

  /// Resumes the existing loop when eligible. Same epoch guard as
  /// [ensureBgmPlaying] so a late resume cannot outrun pause / dispose.
  Future<void> resumeBgm() async {
    if (!_bgmGate()) return;
    final epoch = _lifecycleEpoch;
    if (_bgm.isPaused) {
      await _bgm.setVolume(_effectiveBgmGain());
      if (!_bgmStartupStillValid(epoch)) return;
      await _bgm.resume();
      if (!_bgmStartupStillValid(epoch)) {
        await _rollbackSupersededBgmStartup();
      }
      return;
    }
    if (!_bgm.isPlaying) {
      await ensureBgmPlaying();
    }
  }

  Future<bool> playTap() => _playImmediate(AnimalSoundMatchingSfxCue.tapPop);

  Future<bool> playDragBounce() =>
      _playImmediate(AnimalSoundMatchingSfxCue.dragBounce);

  Future<bool> playWrong() => _playImmediate(AnimalSoundMatchingSfxCue.wrongSoft);

  /// Plays the animal recognition prompt. Soft-fails when muted / missing /
  /// disposed. Ownership is generation-scoped on the animal player so a stale
  /// completion after a newer replay / silence / dispose can neither restart
  /// old audio nor silence the newer owner.
  Future<bool> playAnimalPrompt(
    AnimalKind kind, {
    bool forceRestart = false,
  }) async {
    if (!_animalGate()) return false;
    final serial = ++_animalPromptSerial;
    final epoch = _lifecycleEpoch;
    // ignore: discarded_futures
    _duckBgmForPrompt(serial: serial);
    final played = await _animal.play(
      kind,
      volume: animalPromptGain.clamp(0.0, 1.0),
      generation: serial,
    );
    if (!_animalStillValid(epoch, serial)) {
      // Roll back only OUR generation — never stop a newer valid prompt.
      try {
        await _animal.stop(generation: serial);
      } catch (_) {}
      return false;
    }
    if (!played) return false;
    return true;
  }

  bool _animalGate() {
    if (_disposed || soundOff || !_animalPromptReady || !_animal.canPlay) {
      return false;
    }
    return true;
  }

  bool _animalStillValid(int epoch, int serial) {
    return !_disposed &&
        epoch == _lifecycleEpoch &&
        serial == _animalPromptSerial &&
        _animalGate();
  }

  Future<void> _duckBgmForPrompt({required int serial}) async {
    if (!_bgmGate()) return;
    if (!_bgmHasActivePlayback()) return;
    // Prompt duck uses negative serial space so celebrate ducks stay distinct.
    final duckSerial = -serial;
    if (duckSerial > _lastDuckSerial && _lastDuckSerial > 0) return;
    _lastDuckSerial = duckSerial;
    final epoch = _lifecycleEpoch;
    _cancelDuckRestore();
    await _bgm.setVolume(_duckedBgmGain());
    if (_disposed ||
        epoch != _lifecycleEpoch ||
        _lastDuckSerial != duckSerial ||
        !_bgmGate() ||
        !_bgmHasActivePlayback()) {
      return;
    }
    _duckRestoreTimer = Timer(promptDuckRestore, () {
      if (_disposed ||
          epoch != _lifecycleEpoch ||
          _lastDuckSerial != duckSerial ||
          !_bgmHasActivePlayback()) {
        return;
      }
      // ignore: discarded_futures
      _bgm.setVolume(_effectiveBgmGain());
    });
  }

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
        ? AnimalSoundMatchingSfxCue.completeJingle
        : AnimalSoundMatchingSfxCue.correctChime;
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
      _playCue(AnimalSoundMatchingSfxCue.softClap);
    });
    _twinkleTimer = Timer(twinkleAfter, () {
      if (_disposed ||
          epoch != _lifecycleEpoch ||
          serial != _lastCelebratedSerial) {
        return;
      }
      // ignore: discarded_futures
      _playCue(AnimalSoundMatchingSfxCue.twinkle);
    });
    return true;
  }

  /// Stops SFX + animal prompts + cancels pending celebrate/duck timers.
  /// Optionally pauses BGM (pause / background / screen-time). Replay keeps
  /// BGM with [pauseBgm]=false.
  Future<void> silence({bool pauseBgm = true}) async {
    _lifecycleEpoch++;
    _cancelSequenceTimers();
    _cancelDuckRestore();
    await _animal.stop();
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
    _animalPromptReady = false;
    _lifecycleEpoch++;
    _cancelSequenceTimers();
    _cancelDuckRestore();
    await _animal.stop();
    await _animal.dispose();
    await _player.stopAll();
    await _player.dispose();
    await _bgm.stop();
    await _bgm.dispose();
  }

  /// Replay / progress reset — silence SFX/prompts, keep same BGM instance looping.
  Future<void> resetForReplay() async {
    await silence(pauseBgm: false);
    _lastCelebratedSerial = 0;
    _lastDuckSerial = 0;
    _animalPromptSerial = 0;
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

  /// True while the captured lifecycle epoch still owns BGM startup/resume.
  bool _bgmStartupStillValid(int epoch) {
    return !_disposed && epoch == _lifecycleEpoch && _bgmGate();
  }

  /// Active BGM bus (playing or intentionally paused mid-session).
  bool _bgmHasActivePlayback() => _bgm.isPlaying || _bgm.isPaused;

  /// Undo a start/resume that finished after pause / screen-time / dispose won.
  Future<void> _rollbackSupersededBgmStartup() async {
    if (_disposed) return;
    try {
      await _bgm.pause();
    } catch (_) {}
  }

  Future<void> _duckBgmForCelebrate({
    required int serial,
    required bool isCompletion,
  }) async {
    if (!_bgmGate()) return;
    if (!_bgmHasActivePlayback()) return;
    if (serial < _lastDuckSerial) return;
    _lastDuckSerial = serial;
    final epoch = _lifecycleEpoch;
    _cancelDuckRestore();
    await _bgm.setVolume(_duckedBgmGain());
    // Re-check after await: outdated duck must not schedule restore once a
    // newer match / pause / exit / dispose has claimed the bus.
    if (_disposed ||
        epoch != _lifecycleEpoch ||
        serial != _lastDuckSerial ||
        !_bgmGate() ||
        !_bgmHasActivePlayback()) {
      return;
    }
    final restoreAfter =
        isCompletion ? completionDuckRestore : matchDuckRestore;
    _duckRestoreTimer = Timer(restoreAfter, () {
      if (_disposed ||
          epoch != _lifecycleEpoch ||
          serial != _lastDuckSerial ||
          !_bgmHasActivePlayback()) {
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

  Future<bool> _playImmediate(AnimalSoundMatchingSfxCue cue) async {
    if (!_gate()) return false;
    return _playCue(cue);
  }

  Future<bool> _playCue(AnimalSoundMatchingSfxCue cue) async {
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

  @visibleForTesting
  bool get ownsDefaultAnimal => _ownsDefaultAnimal;
}

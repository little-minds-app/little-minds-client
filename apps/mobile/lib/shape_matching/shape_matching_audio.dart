import 'package:flutter/services.dart';

/// Optional offline audio cues — never claims spoken AC when assets are absent.
class ShapeMatchingAudio {
  ShapeMatchingAudio({this.soundOff = false});

  final bool soundOff;
  var _assetsPresent = false;
  var _ready = false;

  bool get assetsPresent => _assetsPresent;
  bool get ready => _ready;

  Future<void> probe(String localeTag) async {
    final stem = localeTag.startsWith('tr') ? 'tr' : 'en';
    final path = 'assets/audio/shape_matching/$stem/correct.wav';
    try {
      await rootBundle.load(path);
      _assetsPresent = true;
      _ready = !soundOff;
    } catch (_) {
      _assetsPresent = false;
      _ready = false;
    }
  }

  Future<void> playCorrect() async {
    if (!_ready) return;
    // Asset playback lands with licensed packs — probe-only in V1 scaffold.
  }
}

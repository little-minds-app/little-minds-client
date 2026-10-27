import 'dart:convert';

import 'package:flutter/services.dart';

import 'mentor_card.dart';
import 'mentor_card_pin.dart';
import 'mentor_card_validator.dart';

/// Loads pinned Near/Far mentor card fixtures (backend LMP-47 mirror).
///
/// Used by LMP-48 parent mentor UI after review-gate checks.
class MentorCardFixtureLoader {
  MentorCardFixtureLoader({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<Map<String, Object?>> loadRawNearFar({required String locale}) async {
    final fileName = switch (locale) {
      'en-US' => MentorCardContentPin.nearFarEnUsFixture,
      'tr-TR' => MentorCardContentPin.nearFarTrTrFixture,
      _ => throw ArgumentError.value(locale, 'locale', 'expected en-US or tr-TR'),
    };
    final raw =
        await _bundle.loadString(MentorCardContentPin.fixtureAssetPath(fileName));
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('Mentor fixture is not a JSON object: $fileName');
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<MentorCardValidationResult> loadAndValidateNearFar({
    required String locale,
  }) async {
    final raw = await loadRawNearFar(locale: locale);
    return validateMentorCard(raw);
  }

  Future<MentorCardV1> requireNearFar({required String locale}) async {
    final result = await loadAndValidateNearFar(locale: locale);
    return switch (result) {
      MentorCardValidationOk(:final card) => card,
      MentorCardValidationFail(:final issues) => throw StateError(
          'Pinned Near/Far mentor fixture failed validation ($locale): '
          '${issues.map((i) => '${i.code}@${i.path}').join(', ')}',
        ),
    };
  }
}

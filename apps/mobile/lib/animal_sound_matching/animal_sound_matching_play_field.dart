import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/activity_session_controller.dart';
import '../game/hitbox_scaler.dart';
import '../game/scoring_neutral_outcome.dart';
import '../l10n/app_localizations.dart';
import '../shape_matching/shape_matching_bunny_mascot.dart';
import 'animal_sound_matching_activity.dart';
import 'animal_sound_matching_characters.dart';
import 'animal_sound_matching_constants.dart';
import 'animal_sound_matching_garden_scene.dart';
import 'animal_sound_matching_logic.dart';
import 'animal_sound_matching_visual_profile.dart';

/// Landscape Animal Sound Matching play surface — Animal Garden (F-034).
class AnimalSoundMatchingPlayField extends StatefulWidget {
  const AnimalSoundMatchingPlayField({
    super.key,
    required this.activity,
    required this.controller,
    this.reduceMotion = false,
  });

  final AnimalSoundMatchingActivity activity;
  final ActivitySessionController controller;
  final bool reduceMotion;

  static const Key fieldKey = Key('animal-sound-matching-play-field');
  static const Key instructionZoneKey =
      Key('animal-sound-matching-instruction-zone');
  static const Key promptZoneKey = Key('animal-sound-matching-prompt-zone');
  static const Key choicesZoneKey = Key('animal-sound-matching-choices-zone');
  static const Key feedbackZoneKey = Key('animal-sound-matching-feedback-zone');
  static const Key visualFallbackKey =
      Key('animal-sound-matching-visual-fallback');
  static const Key replaySoundKey = Key('animal-sound-matching-replay-sound');
  static const Key promptKey = Key('animal-sound-matching-prompt');
  static const Key completionKey = Key('animal-sound-matching-completion');
  static const Key replayKey = Key('animal-sound-matching-replay');
  static const Key hintKey = Key('animal-sound-matching-hint');
  static const Key tryAgainKey = Key('animal-sound-matching-try-again');
  static const Key praiseKey = Key('animal-sound-matching-praise');

  static Key choiceKey(AnimalKind animal) =>
      Key('animal-sound-matching-choice-${animal.name}');

  @override
  State<AnimalSoundMatchingPlayField> createState() =>
      _AnimalSoundMatchingPlayFieldState();
}

class _AnimalSoundMatchingPlayFieldState
    extends State<AnimalSoundMatchingPlayField> {
  AnimalSoundMatchingActivity get activity => widget.activity;
  ActivitySessionController get controller => widget.controller;
  bool get reduceMotion => widget.reduceMotion;

  BunnyMascotMood _mascotMood = BunnyMascotMood.idle;
  Timer? _moodTimer;
  var _moodEpoch = 0;
  var _praiseVisible = false;
  var _praiseIndex = 0;
  var _celebratedMatchSerial = 0;

  @override
  void initState() {
    super.initState();
    _celebratedMatchSerial = activity.correctMatchSerial;
    activity.addListener(_onActivityChanged);
  }

  @override
  void didUpdateWidget(covariant AnimalSoundMatchingPlayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != activity) {
      oldWidget.activity.removeListener(_onActivityChanged);
      _resetVisualFeedback();
      activity.addListener(_onActivityChanged);
      _syncMoodFromOutcome(notify: false);
    }
  }

  @override
  void dispose() {
    _cancelMoodTimer();
    _moodEpoch++;
    activity.removeListener(_onActivityChanged);
    super.dispose();
  }

  void _cancelMoodTimer() {
    _moodTimer?.cancel();
    _moodTimer = null;
  }

  void _resetVisualFeedback() {
    _cancelMoodTimer();
    _moodEpoch++;
    _mascotMood = BunnyMascotMood.idle;
    _praiseVisible = false;
    _praiseIndex = 0;
    _celebratedMatchSerial = activity.correctMatchSerial;
  }

  void _onActivityChanged() {
    if (!mounted) return;
    _syncMoodFromOutcome(notify: true);
  }

  void _syncMoodFromOutcome({required bool notify}) {
    final outcome = activity.lastOutcome;

    if (outcome == null) {
      _resetVisualFeedback();
      if (notify) setState(() {});
      return;
    }

    if (outcome is ActivityCompletedOutcome) {
      _setMood(
        BunnyMascotMood.complete,
        hold: const Duration(seconds: 4),
        notify: notify,
      );
      _praiseVisible = true;
      if (notify) setState(() {});
      return;
    }
    if (outcome is EncouragementOutcome) {
      if (outcome.cueKey == 'animal_match') {
        final serial = activity.correctMatchSerial;
        if (serial > _celebratedMatchSerial) {
          _celebratedMatchSerial = serial;
          _praiseIndex++;
          _praiseVisible = true;
          _setMood(
            BunnyMascotMood.celebrate,
            hold: const Duration(milliseconds: 1200),
            notify: notify,
          );
        }
        return;
      }
      if (outcome.cueKey == 'try_again') {
        _praiseVisible = false;
        _setMood(
          BunnyMascotMood.encourage,
          hold: const Duration(milliseconds: 900),
          notify: notify,
        );
        return;
      }
    }
    if (notify) setState(() {});
  }

  void _setMood(
    BunnyMascotMood mood, {
    required Duration hold,
    bool notify = true,
  }) {
    _cancelMoodTimer();
    final epoch = _moodEpoch;
    _mascotMood = mood;
    if (notify) setState(() {});
    if (mood == BunnyMascotMood.complete) return;
    _moodTimer = Timer(hold, () {
      if (!mounted || epoch != _moodEpoch) return;
      setState(() {
        _mascotMood = BunnyMascotMood.idle;
        if (_praiseVisible &&
            activity.lastOutcome is! ActivityCompletedOutcome) {
          _praiseVisible = false;
        }
      });
    });
  }

  void _handleChoiceTap(AnimalKind animal) {
    if (!activity.interactionsEnabled) return;
    activity.notifyChoiceTap();
    activity.selectAnimal(animal);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final round = activity.round;
    final completed = activity.lastOutcome is ActivityCompletedOutcome;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;
    final profile = AnimalSoundMatchingVisualProfile.forAgeMonths(
      activity.ageMonths > 0 ? activity.ageMonths : 36,
    );

    return LayoutBuilder(
      key: AnimalSoundMatchingPlayField.fieldKey,
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimalSoundMatchingGardenScene(profile: profile),
            if (completed)
              _CompletionPanel(
                l10n: l10n,
                viewport: viewport,
                reduceMotion: reduceMotion,
                profile: profile,
                onReplay: () {
                  // ignore: discarded_futures
                  controller.restart();
                },
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 8 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(
                      key: AnimalSoundMatchingPlayField.instructionZoneKey,
                      child: _InstructionZone(
                        l10n: l10n,
                        profile: profile,
                        visualFallback: activity.usesVisualFallback,
                      ),
                    ),
                    Expanded(
                      flex: 36,
                      child: KeyedSubtree(
                        key: AnimalSoundMatchingPlayField.promptZoneKey,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: _PromptZone(
                                round: round,
                                activity: activity,
                                l10n: l10n,
                                viewport: viewport,
                                profile: profile,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IgnorePointer(
                                child: ShapeMatchingBunnyMascot(
                                  profile: profile.asBunnyProfile,
                                  mood: _mascotMood,
                                  reduceMotion: reduceMotion,
                                  size: math.min(
                                        viewport.shortestSide * 0.22,
                                        110,
                                      ) *
                                      profile.mascotScale,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 42,
                      child: KeyedSubtree(
                        key: AnimalSoundMatchingPlayField.choicesZoneKey,
                        child: _ChoicesZone(
                          round: round,
                          activity: activity,
                          l10n: l10n,
                          viewport: viewport,
                          profile: profile,
                          onTap: _handleChoiceTap,
                        ),
                      ),
                    ),
                    KeyedSubtree(
                      key: AnimalSoundMatchingPlayField.feedbackZoneKey,
                      child: _FeedbackZone(
                        activity: activity,
                        l10n: l10n,
                        praiseVisible: _praiseVisible,
                        praiseIndex: _praiseIndex,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InstructionZone extends StatelessWidget {
  const _InstructionZone({
    required this.l10n,
    required this.profile,
    required this.visualFallback,
  });

  final AppLocalizations l10n;
  final AnimalSoundMatchingVisualProfile profile;
  final bool visualFallback;

  @override
  Widget build(BuildContext context) {
    final text = visualFallback
        ? l10n.animalSoundMatchingPromptVisual
        : l10n.animalSoundMatchingPromptListen;
    return Semantics(
      key: AnimalSoundMatchingPlayField.promptKey,
      label: text,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF33691E),
              fontSize: profile.band == AnimalSoundMatchingVisualBand.toddler
                  ? 20
                  : 18,
            ),
      ),
    );
  }
}

class _PromptZone extends StatelessWidget {
  const _PromptZone({
    required this.round,
    required this.activity,
    required this.l10n,
    required this.viewport,
    required this.profile,
  });

  final AnimalSoundMatchingRound? round;
  final AnimalSoundMatchingActivity activity;
  final AppLocalizations l10n;
  final Size viewport;
  final AnimalSoundMatchingVisualProfile profile;

  @override
  Widget build(BuildContext context) {
    if (round == null) return const SizedBox.shrink();
    final promptSize = HitboxScaler.scaleLength(
      AnimalSoundMatchingConstants.designPromptSize,
      viewport: viewport,
      minLogical: 72,
    ).clamp(72.0, 140.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (activity.usesVisualFallback)
          Semantics(
            key: AnimalSoundMatchingPlayField.visualFallbackKey,
            label: l10n.animalSoundMatchingVisualFallbackLabel(
              _animalLabel(l10n, round!.targetAnimal),
            ),
            child: AnimalSoundMatchingPromptCue(
              animal: round!.targetAnimal,
              size: promptSize,
              profile: profile,
            ),
          )
        else
          Semantics(
            label: l10n.animalSoundMatchingListenCue,
            child: Icon(
              Icons.volume_up_rounded,
              size: promptSize * 0.55,
              color: const Color(0xFF558B2F),
            ),
          ),
        const SizedBox(height: 8),
        if (!activity.usesVisualFallback)
          Semantics(
            button: true,
            label: l10n.animalSoundMatchingReplaySound,
            child: TextButton.icon(
              key: AnimalSoundMatchingPlayField.replaySoundKey,
              onPressed: activity.interactionsEnabled
                  ? () {
                      // ignore: discarded_futures
                      activity.replayAnimalSound();
                    }
                  : null,
              icon: const Icon(Icons.replay_rounded),
              label: Text(l10n.animalSoundMatchingReplaySound),
            ),
          )
        else
          Text(
            l10n.animalSoundMatchingVisualFallbackHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF558B2F),
                ),
          ),
      ],
    );
  }
}

class _ChoicesZone extends StatelessWidget {
  const _ChoicesZone({
    required this.round,
    required this.activity,
    required this.l10n,
    required this.viewport,
    required this.profile,
    required this.onTap,
  });

  final AnimalSoundMatchingRound? round;
  final AnimalSoundMatchingActivity activity;
  final AppLocalizations l10n;
  final Size viewport;
  final AnimalSoundMatchingVisualProfile profile;
  final ValueChanged<AnimalKind> onTap;

  @override
  Widget build(BuildContext context) {
    if (round == null) return const SizedBox.shrink();
    final choiceSize = HitboxScaler.scaleLength(
      AnimalSoundMatchingConstants.designChoiceSize,
      viewport: viewport,
      minLogical: HitboxScaler.minLogicalSize + 8,
    ).clamp(64.0, 128.0);
    final hintTarget = activity.hintLevel >= 1 ? round!.targetAnimal : null;

    return Semantics(
      label: l10n.animalSoundMatchingChoicesLabel,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final animal in round!.choices)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ChoiceButton(
                  animal: animal,
                  size: choiceSize,
                  profile: profile,
                  l10n: l10n,
                  highlighted: hintTarget == animal,
                  enabled: activity.interactionsEnabled,
                  onTap: () => onTap(animal),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.animal,
    required this.size,
    required this.profile,
    required this.l10n,
    required this.highlighted,
    required this.enabled,
    required this.onTap,
  });

  final AnimalKind animal;
  final double size;
  final AnimalSoundMatchingVisualProfile profile;
  final AppLocalizations l10n;
  final bool highlighted;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _animalLabel(l10n, animal);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: AnimalSoundMatchingPlayField.choiceKey(animal),
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(size * 0.28),
              child: AnimalSoundMatchingAnimalCharacter(
                animal: animal,
                size: size,
                profile: profile,
                highlighted: highlighted,
              ),
            ),
          ),
          if (profile.showChoiceLabels) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF33691E),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackZone extends StatelessWidget {
  const _FeedbackZone({
    required this.activity,
    required this.l10n,
    required this.praiseVisible,
    required this.praiseIndex,
  });

  final AnimalSoundMatchingActivity activity;
  final AppLocalizations l10n;
  final bool praiseVisible;
  final int praiseIndex;

  @override
  Widget build(BuildContext context) {
    final outcome = activity.lastOutcome;
    String? message;
    Key? key;
    if (praiseVisible) {
      final praises = [
        l10n.animalSoundMatchingPraiseGreat,
        l10n.animalSoundMatchingPraiseNice,
        l10n.animalSoundMatchingPraiseAwesome,
      ];
      message = praises[praiseIndex % praises.length];
      key = AnimalSoundMatchingPlayField.praiseKey;
    } else if (outcome is EncouragementOutcome &&
        outcome.cueKey == 'try_again') {
      message = l10n.animalSoundMatchingTryAgain;
      key = AnimalSoundMatchingPlayField.tryAgainKey;
    } else if (outcome is HintOfferedOutcome || activity.hintLevel > 0) {
      message = l10n.animalSoundMatchingHintLevel(activity.hintLevel);
      key = AnimalSoundMatchingPlayField.hintKey;
    }

    return SizedBox(
      height: 28,
      child: message == null
          ? const SizedBox.shrink()
          : Text(
              key: key,
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF558B2F),
                    fontWeight: FontWeight.w600,
                  ),
            ),
    );
  }
}

class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({
    required this.l10n,
    required this.viewport,
    required this.reduceMotion,
    required this.profile,
    required this.onReplay,
  });

  final AppLocalizations l10n;
  final Size viewport;
  final bool reduceMotion;
  final AnimalSoundMatchingVisualProfile profile;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: AnimalSoundMatchingPlayField.completionKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IgnorePointer(
            child: ShapeMatchingBunnyMascot(
              profile: profile.asBunnyProfile,
              mood: BunnyMascotMood.complete,
              reduceMotion: reduceMotion,
              size: math.min(viewport.shortestSide * 0.28, 140) *
                  profile.mascotScale,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.animalSoundMatchingPromptDone,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF33691E),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: AnimalSoundMatchingPlayField.replayKey,
            onPressed: onReplay,
            child: Text(l10n.animalSoundMatchingPlayAgain),
          ),
        ],
      ),
    );
  }
}

String _animalLabel(AppLocalizations l10n, AnimalKind animal) {
  return switch (animal) {
    AnimalKind.cat => l10n.animalSoundMatchingAnimalCat,
    AnimalKind.dog => l10n.animalSoundMatchingAnimalDog,
    AnimalKind.cow => l10n.animalSoundMatchingAnimalCow,
    AnimalKind.duck => l10n.animalSoundMatchingAnimalDuck,
    AnimalKind.bird => l10n.animalSoundMatchingAnimalBird,
    AnimalKind.sheep => l10n.animalSoundMatchingAnimalSheep,
    AnimalKind.frog => l10n.animalSoundMatchingAnimalFrog,
    AnimalKind.horse => l10n.animalSoundMatchingAnimalHorse,
  };
}

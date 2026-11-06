import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_activity.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_audio.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_constants.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_garden_scene.dart';
import 'package:little_minds_mobile/animal_sound_matching/animal_sound_matching_play_field.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';
import 'package:little_minds_mobile/game/activity_play_host.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';
import 'package:little_minds_mobile/l10n/app_localizations.dart';
import 'package:little_minds_mobile/shape_matching/hub_activity_registry.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_bunny_mascot.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _setLandscape(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  final view = tester.view;
  view.physicalSize = Size(width, height);
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

Widget _host({
  required AnimalSoundMatchingActivity activity,
  Locale locale = const Locale('en', 'US'),
  bool reduceMotion = false,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      Widget tree = child!;
      if (reduceMotion) {
        final mq = MediaQuery.of(context);
        tree = MediaQuery(
          data: mq.copyWith(disableAnimations: true),
          child: tree,
        );
      }
      return tree;
    },
    home: ActivityPlayHost(
      game: StubLearningGame(),
      activity: activity,
      onClose: () {},
    ),
  );
}

AnimalSoundMatchingActivity _activityForAge(
  int ageMonths, {
  bool soundOff = false,
}) {
  return AnimalSoundMatchingActivity(
    ageMonthsProvider: () => ageMonths,
    playSessionId: '00000000-0000-4000-8000-000000000056',
    soundOff: soundOff,
    audio: AnimalSoundMatchingAudio(
      soundOff: soundOff,
      player: RecordingAnimalSoundMatchingSfxPlayer(),
      bgmPlayer: RecordingAnimalSoundMatchingBgmPlayer(),
      animalPlayer: RecordingAnimalSoundMatchingAnimalPlayer(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-ASM-W01 play field renders on compact landscape phone',
      (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    expect(find.byKey(AnimalSoundMatchingPlayField.fieldKey), findsOneWidget);
    expect(find.byKey(AnimalSoundMatchingPlayField.promptKey), findsOneWidget);
    expect(
      find.text('Listen and find the animal!'),
      findsOneWidget,
    );
    expect(find.byKey(AnimalSoundMatchingGardenScene.sceneKey), findsOneWidget);
    expect(find.byKey(ShapeMatchingBunnyMascot.mascotKey), findsOneWidget);
  });

  testWidgets('TC-ASM-W02 Turkish guidance strings', (tester) async {
    final activity = _activityForAge(32);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      _host(activity: activity, locale: const Locale('tr', 'TR')),
    );
    await _pumpFrames(tester);
    expect(find.text('Dinle ve hayvanı bul!'), findsOneWidget);
  });

  testWidgets('TC-ASM-W03 tablet landscape renders choices for age band',
      (tester) async {
    final activity = _activityForAge(50);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    expect(find.byKey(AnimalSoundMatchingPlayField.choicesZoneKey), findsOneWidget);
    expect(activity.round!.choices.length, 4);
    for (final animal in activity.round!.choices) {
      expect(find.byKey(AnimalSoundMatchingPlayField.choiceKey(animal)), findsOneWidget);
    }
  });

  testWidgets('TC-ASM-W04 tap correct choice advances', (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    final correct = activity.round!.targetAnimal;
    await tester.tap(find.byKey(AnimalSoundMatchingPlayField.choiceKey(correct)));
    await _pumpFrames(tester);
    expect(activity.roundIndex, 1);
  });

  testWidgets('TC-ASM-W05 wrong tap shows try-again without advancing',
      (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    final wrong = activity.round!.choices
        .firstWhere((c) => c != activity.round!.targetAnimal);
    await tester.tap(find.byKey(AnimalSoundMatchingPlayField.choiceKey(wrong)));
    await _pumpFrames(tester);
    expect(activity.roundIndex, 0);
    expect(find.byKey(AnimalSoundMatchingPlayField.tryAgainKey), findsOneWidget);
  });

  testWidgets('TC-ASM-W06 soundOff shows visual fallback key', (tester) async {
    final activity = _activityForAge(36, soundOff: true);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    expect(find.byKey(AnimalSoundMatchingPlayField.visualFallbackKey), findsOneWidget);
  });

  testWidgets('TC-ASM-W07 completion + replay', (tester) async {
    final activity = _activityForAge(36);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    for (var i = 0; i < AnimalSoundMatchingConstants.roundsPerSession; i++) {
      final correct = activity.round!.targetAnimal;
      await tester.tap(find.byKey(AnimalSoundMatchingPlayField.choiceKey(correct)));
      await _pumpFrames(tester);
    }
    expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
    expect(find.byKey(AnimalSoundMatchingPlayField.completionKey), findsOneWidget);
    expect(find.byKey(AnimalSoundMatchingPlayField.replayKey), findsOneWidget);
    await tester.tap(find.byKey(AnimalSoundMatchingPlayField.replayKey));
    await _pumpFrames(tester);
    expect(activity.roundIndex, 0);
    expect(find.byKey(AnimalSoundMatchingPlayField.fieldKey), findsOneWidget);
  });

  testWidgets('TC-ASM-W08 reduced motion still renders', (tester) async {
    final activity = _activityForAge(42);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity, reduceMotion: true));
    await _pumpFrames(tester);
    expect(find.byKey(AnimalSoundMatchingPlayField.fieldKey), findsOneWidget);
    expect(find.byKey(ShapeMatchingBunnyMascot.mascotKey), findsOneWidget);
  });

  testWidgets('TC-ASM-W09 bunny wrapped in IgnorePointer', (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    final mascot = find.byKey(ShapeMatchingBunnyMascot.mascotKey);
    expect(mascot, findsOneWidget);
    expect(
      find.ancestor(of: mascot, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
  });

  test('TC-ASM-U07 hub registry includes animal sound matching when age valid',
      () {
    var age = 34;
    final registry = createHubActivityRegistry(ageMonthsProvider: () => age);
    expect(registry.findById('animal_sound_matching')!.isPlayable, isTrue);
    age = 10;
    expect(registry.findById('animal_sound_matching')!.isPlayable, isFalse);
    expect(registry.findById('shape_matching'), isNotNull);
  });

  testWidgets('TC-ASM-W10 prepare fails for unsupported age closes host',
      (tester) async {
    final activity = _activityForAge(80);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActivityPlayHost(
          game: StubLearningGame(),
          activity: activity,
          onClose: () => closed = true,
        ),
      ),
    );
    await _pumpFrames(tester);
    expect(closed, isTrue);
  });

  test('TC-ASM-U08 ActivityRegistry dual registration', () {
    final registry = ActivityRegistry([
      _activityForAge(36),
    ]);
    expect(registry.findById(AnimalSoundMatchingConstants.activityId), isNotNull);
  });
}

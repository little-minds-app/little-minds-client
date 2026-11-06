import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/game/activity_play_host.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/game/scoring_neutral_outcome.dart';
import 'package:little_minds_mobile/l10n/app_localizations.dart';
import 'package:little_minds_mobile/screen_time/screen_time.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_activity.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_audio.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_bunny_mascot.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_garden_scene.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_play_field.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_shape_character.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_visual_profile.dart';
import 'package:little_minds_mobile/config/scaffolding_assumptions.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _setLandscape(WidgetTester tester, {required double width, required double height}) async {
  final view = tester.view;
  view.physicalSize = Size(width, height);
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

Widget _host({
  required ShapeMatchingActivity activity,
  ScreenTimeCoordinator? screenTime,
  Locale locale = const Locale('en', 'US'),
  bool reduceMotion = false,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      Widget tree = child!;
      if (screenTime != null) {
        tree = ScreenTimeScope(coordinator: screenTime, child: tree);
      }
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

ShapeMatchingActivity _activityForAge(int ageMonths) {
  // Widget tests inject a recording player so audioplayers platform channels
  // never block lifecycle (replay / pause / dispose) on the test binding.
  return ShapeMatchingActivity(
    ageMonthsProvider: () => ageMonths,
    playSessionId: '00000000-0000-4000-8000-000000000055',
    audio: ShapeMatchingAudio(player: RecordingShapeMatchingSfxPlayer()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-SM-W01 play field renders for age band 30 months', (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.fieldKey), findsOneWidget);
    expect(find.byKey(ShapeMatchingPlayField.promptKey), findsOneWidget);
    expect(find.text('Find the same shape!'), findsOneWidget);
  });

  testWidgets('TC-SM-W02 Turkish guidance strings', (tester) async {
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
    expect(find.text('Aynı şekli bul!'), findsOneWidget);
    expect(find.text('Bunu eşleştir'), findsOneWidget);
  });

  testWidgets('TC-SM-W10 instruction and target zones do not overlap on short landscape',
      (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(tester, width: 640, height: 320);
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    final promptBox = tester.getRect(find.byKey(ShapeMatchingPlayField.promptKey));
    final targetBox = tester.getRect(find.byKey(ShapeMatchingPlayField.targetKey));
    expect(promptBox.bottom, lessThanOrEqualTo(targetBox.top));
  });

  testWidgets('TC-SM-W11 wrong pick shows localized try-again feedback', (tester) async {
    final activity = _activityForAge(30);
    await activity.prepare();
    final wrong = activity.round!.choices
        .firstWhere((c) => c != activity.round!.target);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ShapeMatchingPlayField.choiceKey(wrong)));
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.tryAgainKey), findsOneWidget);
    expect(find.text('Try again!'), findsOneWidget);
  });

  testWidgets('TC-SM-W03 tap correct shape advances', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    final target = activity.round!.target;
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ShapeMatchingPlayField.choiceKey(target)));
    await _pumpFrames(tester);
    expect(activity.roundIndex, 1);
  });

  testWidgets('TC-SM-W04 wrong then hint path', (tester) async {
    final activity = _activityForAge(28);
    await activity.prepare();
    final round = activity.round!;
    final wrong = round.choices.firstWhere((c) => c != round.target);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ShapeMatchingPlayField.choiceKey(wrong)));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ShapeMatchingPlayField.choiceKey(wrong)));
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.hintKey), findsOneWidget);
  });

  testWidgets('TC-SM-W05 screen-time block pauses input', (tester) async {
    final activity = _activityForAge(50);
    final mono = FakeMonotonicClock(epochId: 'sm-cap');
    final wall = FakeWallClock(DateTime.utc(2026, 11, 4, 12));
    final store = InMemoryPersistentStore();
    final screenTime = ScreenTimeCoordinator.withDependencies(
      monotonicClock: mono,
      wallClock: wall,
      store: store,
      tickInterval: Duration.zero,
    );
    await screenTime.initialize();
    screenTime.setKidsModeShellActive(true);
    mono.elapse(const Duration(minutes: 30));
    screenTime.tickForTest();
    addTearDown(() {
      if (!screenTime.isDisposed) screenTime.dispose();
    });
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity, screenTime: screenTime));
    await _pumpFrames(tester);
    expect(find.byKey(ActivityPlayHost.inputBlockKey), findsOneWidget);
  });

  testWidgets('TC-SM-W06 prepare fails for unsupported age closes host', (tester) async {
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

  test('TC-SM-U07 registry playable only with valid selected age', () {
    var age = 34;
    final registry = ActivityRegistry([
      ShapeMatchingActivity(ageMonthsProvider: () => age),
    ]);
    expect(registry.findById('shape_matching')!.isPlayable, isTrue);
    age = 10;
    expect(registry.findById('shape_matching')!.isPlayable, isFalse);
  });

  testWidgets('TC-SM-W08 reduced motion host still renders choices', (tester) async {
    final activity = _activityForAge(42);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity, reduceMotion: true));
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.fieldKey), findsOneWidget);
  });

  testWidgets('TC-SM-W09 completion shows calm completion once', (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    for (var i = 0; i < 3; i++) {
      final target = activity.round!.target;
      await tester.tap(find.byKey(ShapeMatchingPlayField.choiceKey(target)));
      await _pumpFrames(tester);
    }
    expect(find.byKey(ShapeMatchingPlayField.completionKey), findsOneWidget);
    expect(find.text('You did it!'), findsOneWidget);
    expect(find.byKey(ShapeMatchingPlayField.replayKey), findsOneWidget);
  });

  testWidgets('TC-SM-W12 replay restarts session from completion', (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(
        find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
      );
      await _pumpFrames(tester);
    }
    await tester.tap(find.byKey(ShapeMatchingPlayField.replayKey));
    await _pumpFrames(tester);
    expect(activity.roundIndex, 0);
    expect(find.byKey(ShapeMatchingPlayField.targetKey), findsOneWidget);
  });

  testWidgets('TC-SM-W13 garden scene and bunny mascot render', (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingGardenScene.sceneKey), findsOneWidget);
    expect(find.byKey(ShapeMatchingBunnyMascot.mascotKey), findsOneWidget);
  });

  testWidgets('TC-SM-W14 correct pick shows localized praise', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    final target = activity.round!.target;
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ShapeMatchingPlayField.choiceKey(target)));
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.praiseKey), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == 'Great job!' ||
                w.data == 'Nice match!' ||
                w.data == 'Awesome!'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('TC-SM-W15 Turkish praise string on correct pick', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    final target = activity.round!.target;
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(
      _host(activity: activity, locale: const Locale('tr', 'TR')),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(ShapeMatchingPlayField.choiceKey(target)));
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.praiseKey), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == 'Aferin!' ||
                w.data == 'Güzel eşleşme!' ||
                w.data == 'Süper!'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('TC-SM-W16 early band shows choice labels', (tester) async {
    final activity = _activityForAge(60);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    final profile = ShapeMatchingVisualProfile.forAgeMonths(60);
    expect(profile.showChoiceLabels, isTrue);
    expect(find.text('Circle').evaluate().isNotEmpty ||
            find.text('Square').evaluate().isNotEmpty ||
            find.text('Triangle').evaluate().isNotEmpty ||
            find.text('Star').evaluate().isNotEmpty ||
            find.text('Hexagon').evaluate().isNotEmpty,
        isTrue);
  });

  testWidgets('TC-SM-W17 toddler band hides choice labels', (tester) async {
    final activity = _activityForAge(28);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    final profile = ShapeMatchingVisualProfile.forAgeMonths(28);
    expect(profile.showChoiceLabels, isFalse);
    expect(profile.band, ShapeMatchingVisualBand.toddler);
  });

  testWidgets('TC-SM-W18 shape characters present for choices', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    final choices = activity.round!.choices;
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    for (final token in choices) {
      expect(
        find.byKey(ShapeMatchingShapeCharacter.characterKey(token)),
        findsWidgets,
      );
    }
  });

  test('TC-SM-U19 visual profile age bands', () {
    expect(
      ShapeMatchingVisualProfile.forAgeMonths(30).band,
      ShapeMatchingVisualBand.toddler,
    );
    expect(
      ShapeMatchingVisualProfile.forAgeMonths(40).band,
      ShapeMatchingVisualBand.preschool,
    );
    expect(
      ShapeMatchingVisualProfile.forAgeMonths(55).band,
      ShapeMatchingVisualBand.early,
    );
  });

  testWidgets('TC-SM-W20 replay resets mascot mood and praise', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
    );
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.praiseKey), findsOneWidget);
    expect(
      find.byKey(ShapeMatchingBunnyMascot.moodKey(BunnyMascotMood.celebrate)),
      findsOneWidget,
    );

    // Finish remaining rounds → completion → replay
    while (activity.lastOutcome is! ActivityCompletedOutcome) {
      await tester.tap(
        find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
      );
      await _pumpFrames(tester);
    }
    await tester.tap(find.byKey(ShapeMatchingPlayField.replayKey));
    await _pumpFrames(tester);

    expect(activity.roundIndex, 0);
    expect(activity.correctMatchSerial, 0);
    expect(find.byKey(ShapeMatchingPlayField.praiseKey), findsNothing);
    expect(
      find.byKey(ShapeMatchingBunnyMascot.moodKey(BunnyMascotMood.idle)),
      findsOneWidget,
    );
    expect(find.byKey(ShapeMatchingPlayField.targetKey), findsOneWidget);
  });

  testWidgets('TC-SM-W21 activity replace cancels stale mood timer', (tester) async {
    final first = _activityForAge(36);
    await first.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: first));
    await _pumpFrames(tester);
    await tester.tap(
      find.byKey(ShapeMatchingPlayField.choiceKey(first.round!.target)),
    );
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.praiseKey), findsOneWidget);

    final second = _activityForAge(40);
    await second.prepare();
    await tester.pumpWidget(_host(activity: second));
    await _pumpFrames(tester);

    // Stale first-activity timer must not paint praise onto the replacement.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byKey(ShapeMatchingPlayField.praiseKey), findsNothing);
    expect(find.byKey(ShapeMatchingPlayField.targetKey), findsOneWidget);
    expect(second.correctMatchSerial, 0);
  });

  testWidgets('TC-SM-W22 rapid correct matches celebrate once each', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
    );
    await tester.pump(); // keep prior praise timer alive (no 1.2s wait)
    expect(activity.correctMatchSerial, 1);
    expect(find.byKey(ShapeMatchingPlayField.praiseKey), findsOneWidget);
    final firstPraise =
        tester.widget<Text>(find.byKey(ShapeMatchingPlayField.praiseKey)).data;

    // Immediate next-round correct while celebrate/praise still active.
    await tester.tap(
      find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
    );
    await tester.pump();
    expect(activity.correctMatchSerial, 2);
    expect(find.byKey(ShapeMatchingPlayField.praiseKey), findsOneWidget);
    expect(
      find.byKey(ShapeMatchingBunnyMascot.moodKey(BunnyMascotMood.celebrate)),
      findsOneWidget,
    );
    // Praise index advanced (rotating copy) — proves a second celebration fired.
    final secondPraise =
        tester.widget<Text>(find.byKey(ShapeMatchingPlayField.praiseKey)).data;
    expect(secondPraise, isNotNull);
    expect(
      {'Great job!', 'Nice match!', 'Awesome!'}.contains(secondPraise),
      isTrue,
    );
    expect(secondPraise, isNot(firstPraise));
  });

  testWidgets('TC-SM-W23 duplicate activity notify does not double-celebrate',
      (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);

    final target = activity.round!.target;
    await tester.tap(find.byKey(ShapeMatchingPlayField.choiceKey(target)));
    await _pumpFrames(tester);
    expect(activity.correctMatchSerial, 1);
    final praiseAfterPick =
        tester.widget<Text>(find.byKey(ShapeMatchingPlayField.praiseKey)).data;

    // Duplicate notifies with the same serial (toggle + restore) must not
    // advance praise — pickShape already double-notifies on advance as well.
    activity.setInteractionsEnabled(false);
    activity.setInteractionsEnabled(true);
    await activity.restorePlayState(activity.capturePlayState());
    await _pumpFrames(tester);

    expect(activity.correctMatchSerial, 1);
    expect(
      tester.widget<Text>(find.byKey(ShapeMatchingPlayField.praiseKey)).data,
      praiseAfterPick,
    );
  });

  testWidgets('TC-SM-W24 dispose cancels mood timer without crashing', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    await tester.tap(
      find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    // Timer would have fired — must be cancelled (no setState-after-dispose).
    await tester.pump(const Duration(milliseconds: 2000));
  });

  testWidgets('TC-SM-W25 reduce-motion celebrate is static joyful pose', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity, reduceMotion: true));
    await _pumpFrames(tester);
    await tester.tap(
      find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
    );
    await _pumpFrames(tester);
    expect(
      find.byKey(ShapeMatchingBunnyMascot.moodKey(BunnyMascotMood.celebrate)),
      findsOneWidget,
    );
    final mascot = tester.widget<ShapeMatchingBunnyMascot>(
      find.byType(ShapeMatchingBunnyMascot),
    );
    expect(mascot.reduceMotion, isTrue);
    expect(mascot.mood, BunnyMascotMood.celebrate);
  });

  testWidgets('TC-SM-W26 complete mood distinct from mid-round celebrate',
      (tester) async {
    final activity = _activityForAge(30);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
    );
    await _pumpFrames(tester);
    expect(
      find.byKey(ShapeMatchingBunnyMascot.moodKey(BunnyMascotMood.celebrate)),
      findsOneWidget,
    );
    expect(
      find.byKey(ShapeMatchingBunnyMascot.moodKey(BunnyMascotMood.complete)),
      findsNothing,
    );

    while (activity.lastOutcome is! ActivityCompletedOutcome) {
      await tester.tap(
        find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
      );
      await _pumpFrames(tester);
    }
    expect(find.byKey(ShapeMatchingPlayField.completionKey), findsOneWidget);
    expect(
      find.byKey(ShapeMatchingBunnyMascot.moodKey(BunnyMascotMood.complete)),
      findsOneWidget,
    );
    expect(
      find.byKey(ShapeMatchingBunnyMascot.moodKey(BunnyMascotMood.celebrate)),
      findsNothing,
    );
  });

  testWidgets('TC-SM-W27 small landscape early band no overflow', (tester) async {
    final activity = _activityForAge(60);
    await activity.prepare();
    await _setLandscape(tester, width: 640, height: 320);
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    expect(find.byKey(ShapeMatchingPlayField.fieldKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    final promptBox = tester.getRect(find.byKey(ShapeMatchingPlayField.promptKey));
    final targetBox = tester.getRect(find.byKey(ShapeMatchingPlayField.targetKey));
    expect(promptBox.bottom, lessThanOrEqualTo(targetBox.top + 1));
  });

  testWidgets('TC-SM-W28 drag after replay still matches', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(
        find.byKey(ShapeMatchingPlayField.choiceKey(activity.round!.target)),
      );
      await _pumpFrames(tester);
    }
    expect(find.byKey(ShapeMatchingPlayField.replayKey), findsOneWidget);
    await tester.tap(find.byKey(ShapeMatchingPlayField.replayKey));
    await _pumpFrames(tester);

    final target = activity.round!.target;
    final choice = find.byKey(ShapeMatchingPlayField.choiceKey(target));
    final drop = find.byKey(ShapeMatchingPlayField.targetKey);
    final gesture = await tester.startGesture(tester.getCenter(choice));
    await gesture.moveTo(tester.getCenter(drop));
    await gesture.up();
    await _pumpFrames(tester);
    expect(activity.roundIndex, 1);
    expect(activity.correctMatchSerial, 1);
  });

  testWidgets(
      'TC-SM-W29 target card and label stay screen-centered with bunny overlay '
      'on iPhone landscape', (tester) async {
    final activity = _activityForAge(36);
    await activity.prepare();
    // Compact phone landscape (iPhone-class) — bunny must not shift target.
    const width = ScaffoldingViewports.compactPhoneHeight;
    const height = ScaffoldingViewports.compactPhoneWidth;
    await _setLandscape(tester, width: width, height: height);
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);

    expect(find.byKey(ShapeMatchingBunnyMascot.mascotKey), findsOneWidget);
    expect(find.byKey(ShapeMatchingPlayField.targetKey), findsOneWidget);
    expect(find.byKey(ShapeMatchingPlayField.targetLabelKey), findsOneWidget);

    final screenCenterX = width / 2;
    final targetBox =
        tester.getRect(find.byKey(ShapeMatchingPlayField.targetKey));
    final labelBox =
        tester.getRect(find.byKey(ShapeMatchingPlayField.targetLabelKey));
    final mascotBox =
        tester.getRect(find.byKey(ShapeMatchingBunnyMascot.mascotKey));

    expect(
      (targetBox.center.dx - screenCenterX).abs(),
      lessThan(8),
      reason: 'target card must be horizontally centered on screen',
    );
    expect(
      (labelBox.center.dx - targetBox.center.dx).abs(),
      lessThan(8),
      reason: 'label must sit centered above the target card',
    );
    expect(
      mascotBox.center.dx,
      lessThan(targetBox.center.dx),
      reason: 'bunny remains visible to the left without owning the axis',
    );

    // Drag/drop still works with overlay bunny (IgnorePointer).
    final target = activity.round!.target;
    final choice = find.byKey(ShapeMatchingPlayField.choiceKey(target));
    final drop = find.byKey(ShapeMatchingPlayField.targetKey);
    final gesture = await tester.startGesture(tester.getCenter(choice));
    await gesture.moveTo(tester.getCenter(drop));
    await gesture.up();
    await _pumpFrames(tester);
    expect(activity.roundIndex, 1);
  });
}

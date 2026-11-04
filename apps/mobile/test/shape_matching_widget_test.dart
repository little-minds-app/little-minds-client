import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/game/activity_play_host.dart';
import 'package:little_minds_mobile/game/activity_registry.dart';
import 'package:little_minds_mobile/game/flame_host.dart';
import 'package:little_minds_mobile/l10n/app_localizations.dart';
import 'package:little_minds_mobile/screen_time/screen_time.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_activity.dart';
import 'package:little_minds_mobile/shape_matching/shape_matching_play_field.dart';
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
  return ShapeMatchingActivity(
    ageMonthsProvider: () => ageMonths,
    playSessionId: '00000000-0000-4000-8000-000000000055',
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
}

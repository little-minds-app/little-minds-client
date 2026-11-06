import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_activity.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_audio.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_constants.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_orchard_scene.dart';
import 'package:little_minds_mobile/color_sorting/color_sorting_play_field.dart';
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
  required ColorSortingActivity activity,
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

ColorSortingActivity _activityForAge(int ageMonths) {
  return ColorSortingActivity(
    ageMonthsProvider: () => ageMonths,
    playSessionId: '00000000-0000-4000-8000-000000000056',
    audio: ColorSortingAudio(
      player: RecordingColorSortingSfxPlayer(),
      bgmPlayer: RecordingColorSortingBgmPlayer(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-CS-W01 play field renders on compact landscape phone',
      (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    expect(find.byKey(ColorSortingPlayField.fieldKey), findsOneWidget);
    expect(find.byKey(ColorSortingPlayField.promptKey), findsOneWidget);
    expect(find.text('Put it in the matching basket!'), findsOneWidget);
    expect(find.byKey(ColorSortingOrchardScene.sceneKey), findsOneWidget);
    expect(find.byKey(ShapeMatchingBunnyMascot.mascotKey), findsOneWidget);
  });

  testWidgets('TC-CS-W02 Turkish guidance strings', (tester) async {
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
    expect(find.text('Eşleşen sepete koy!'), findsOneWidget);
  });

  testWidgets('TC-CS-W03 tablet landscape renders bins for age band',
      (tester) async {
    final activity = _activityForAge(50);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.tabletHeight,
      height: ScaffoldingViewports.tabletWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    expect(find.byKey(ColorSortingPlayField.binsZoneKey), findsOneWidget);
    expect(activity.round!.bins.length, 4);
    for (final bin in activity.round!.bins) {
      expect(find.byKey(ColorSortingPlayField.binKey(bin)), findsOneWidget);
    }
  });

  testWidgets('TC-CS-W04 tap bin sorts correctly and advances', (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    final correct = activity.round!.objectColor;
    await tester.tap(find.byKey(ColorSortingPlayField.binKey(correct)));
    await _pumpFrames(tester);
    expect(activity.roundIndex, 1);
  });

  testWidgets('TC-CS-W05 wrong tap shows try-again without advancing',
      (tester) async {
    final activity = _activityForAge(30);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    final wrong = activity.round!.bins
        .firstWhere((b) => b != activity.round!.objectColor);
    await tester.tap(find.byKey(ColorSortingPlayField.binKey(wrong)));
    await _pumpFrames(tester);
    expect(activity.roundIndex, 0);
    expect(find.byKey(ColorSortingPlayField.tryAgainKey), findsOneWidget);
  });

  testWidgets('TC-CS-W06 completion + replay', (tester) async {
    final activity = _activityForAge(36);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity));
    await _pumpFrames(tester);
    for (var i = 0; i < ColorSortingConstants.roundsPerSession; i++) {
      final correct = activity.round!.objectColor;
      await tester.tap(find.byKey(ColorSortingPlayField.binKey(correct)));
      await _pumpFrames(tester);
    }
    expect(activity.lastOutcome, isA<ActivityCompletedOutcome>());
    expect(find.byKey(ColorSortingPlayField.completionKey), findsOneWidget);
    expect(find.byKey(ColorSortingPlayField.replayKey), findsOneWidget);
    await tester.tap(find.byKey(ColorSortingPlayField.replayKey));
    await _pumpFrames(tester);
    expect(activity.roundIndex, 0);
    expect(find.byKey(ColorSortingPlayField.fieldKey), findsOneWidget);
  });

  testWidgets('TC-CS-W07 reduced motion still renders', (tester) async {
    final activity = _activityForAge(42);
    await _setLandscape(
      tester,
      width: ScaffoldingViewports.compactPhoneHeight,
      height: ScaffoldingViewports.compactPhoneWidth,
    );
    await tester.pumpWidget(_host(activity: activity, reduceMotion: true));
    await _pumpFrames(tester);
    expect(find.byKey(ColorSortingPlayField.fieldKey), findsOneWidget);
    expect(find.byKey(ShapeMatchingBunnyMascot.mascotKey), findsOneWidget);
  });

  testWidgets('TC-CS-W08 bunny wrapped in IgnorePointer', (tester) async {
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

  test('TC-CS-U07 hub registry includes color sorting when age valid', () {
    var age = 34;
    final registry = createHubActivityRegistry(ageMonthsProvider: () => age);
    expect(registry.findById('color_sorting')!.isPlayable, isTrue);
    age = 10;
    expect(registry.findById('color_sorting')!.isPlayable, isFalse);
    expect(registry.findById('shape_matching'), isNotNull);
  });

  testWidgets('TC-CS-W09 prepare fails for unsupported age closes host',
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

  test('TC-CS-U08 ActivityRegistry dual registration', () {
    final registry = ActivityRegistry([
      _activityForAge(36),
    ]);
    expect(registry.findById(ColorSortingConstants.activityId), isNotNull);
  });
}

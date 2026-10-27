import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'child_hub/hub_audio_guidance.dart';
import 'config/app_config.dart';
import 'config/app_config_scope.dart';
import 'game/flame_host.dart';
import 'l10n/app_localizations.dart';
import 'mentor/mentor_card.dart';
import 'mentor/mentor_card_fixtures.dart';
import 'near_far/near_far_activity.dart';
import 'screen_time/screen_time.dart';
import 'surfaces/child_hub_surface.dart';
import 'surfaces/near_far_demo_surface.dart';
import 'surfaces/near_far_mentor_surface.dart';
import 'surfaces/parent_gate_surface.dart';
import 'surfaces/parent_settings_surface.dart';
import 'surfaces/profile_selection_surface.dart';

/// Root application — MaterialApp + shell navigation (Flutter built-ins only).
///
/// State-management choice is a **scaffolding assumption** until ADR-003.
///
/// Parent path (preserve Gate): Hub → Parent Gate → Parent Settings →
/// mentor card / Near/Far demo. Near/Far is never a seventh Kids Hub tile.
///
/// Screen time (LMP-49): Kids Hub (+ in-Hub play) counts; Parent Settings,
/// Mentor, Near/Far demo, and background do not.
class LittleMindsApp extends StatefulWidget {
  LittleMindsApp({
    super.key,
    this.game,
    AppConfig? config,
    this.locale,
    this.audioGuidance,
    this.forceShowEnvBadge = false,
    this.initialNearFarDemo = false,
    this.nearFarActivity,
    this.mentorCardLoader,
    this.mentorInjectedCard,
    this.screenTime,
  }) : config = config ?? AppConfig.developmentLocal;

  final StubLearningGame? game;

  /// Public build-time environment config (LMP-28). Defaults to development.
  final AppConfig config;

  /// Optional locale override for widget tests (F-020).
  final Locale? locale;

  /// Optional Child Hub audio guidance override (tests / DI).
  final HubAudioGuidance? audioGuidance;

  /// Developer/test-only: surface LMP-28 env badge on Child Hub.
  final bool forceShowEnvBadge;

  /// Opens the dedicated Near/Far demo route (LMP-45) — not Hub catalog.
  final bool initialNearFarDemo;

  /// Optional injected Near/Far activity for widget tests.
  final NearFarActivity? nearFarActivity;

  /// Optional mentor fixture loader override (widget tests / DI).
  final MentorCardFixtureLoader? mentorCardLoader;

  /// Optional preloaded mentor card for deterministic shell widget tests.
  ///
  /// Avoids FakeAsync hangs on `rootBundle` asset I/O while preserving real
  /// Gate → Settings → Mentor navigation.
  final MentorCardV1? mentorInjectedCard;

  /// Optional screen-time coordinator (tests / production bootstrap).
  ///
  /// When null, an in-memory coordinator is created for widget-test safety.
  /// Production [main] should pass a SharedPreferences-backed instance.
  final ScreenTimeCoordinator? screenTime;

  @override
  State<LittleMindsApp> createState() => _LittleMindsAppState();
}

enum _ShellRoute {
  childHub,
  profileSelection,
  parentGate,
  parentSettings,
  nearFarDemo,
  nearFarMentor,
}

class _LittleMindsAppState extends State<LittleMindsApp> {
  late final StubLearningGame _game = widget.game ?? StubLearningGame();
  late _ShellRoute _route =
      widget.initialNearFarDemo ? _ShellRoute.nearFarDemo : _ShellRoute.childHub;

  /// Where Near/Far demo should return (mentor card or Parent Settings).
  _ShellRoute _nearFarDemoReturn = _ShellRoute.parentSettings;

  late final ScreenTimeCoordinator _screenTime;
  late final bool _ownsScreenTime;

  @override
  void initState() {
    super.initState();
    _ownsScreenTime = widget.screenTime == null;
    // Test fallback: in-memory store, no periodic timer (production wires
    // SharedPreferences + tick interval in main.dart).
    _screenTime = widget.screenTime ??
        ScreenTimeCoordinator.withDependencies(
          monotonicClock: StopwatchMonotonicClock(),
          wallClock: const SystemWallClock(),
          store: InMemoryPersistentStore(),
          tickInterval: Duration.zero,
        );
    // ignore: discarded_futures
    _bootstrapScreenTime();
  }

  Future<void> _bootstrapScreenTime() async {
    if (!_screenTime.isInitialized) {
      await _screenTime.initialize();
    }
    if (!mounted) return;
    _screenTime.setKidsModeShellActive(_isKidsModeRoute(_route));
    setState(() {});
  }

  bool _isKidsModeRoute(_ShellRoute route) {
    // Kids Hub + child profile transitions count; Parent / Mentor / Near-Far do not.
    return route == _ShellRoute.childHub ||
        route == _ShellRoute.profileSelection;
  }

  void _go(_ShellRoute route) {
    setState(() => _route = route);
    _screenTime.setKidsModeShellActive(_isKidsModeRoute(route));
  }

  void _openNearFarDemo({required _ShellRoute returnTo}) {
    setState(() {
      _nearFarDemoReturn = returnTo;
      _route = _ShellRoute.nearFarDemo;
    });
    // Near/Far demo is on the parent path — outside Kids Mode counting.
    _screenTime.setKidsModeShellActive(false);
  }

  void _closeNearFarDemo() {
    if (widget.initialNearFarDemo &&
        _nearFarDemoReturn == _ShellRoute.parentSettings) {
      _go(_ShellRoute.childHub);
      return;
    }
    _go(_nearFarDemoReturn);
  }

  @override
  void dispose() {
    if (_ownsScreenTime) {
      _screenTime.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppConfigScope(
      config: widget.config,
      child: ScreenTimeScope(
        coordinator: _screenTime,
        child: MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          locale: widget.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
            useMaterial3: true,
          ),
          home: Builder(
            builder: (context) {
              switch (_route) {
                case _ShellRoute.childHub:
                  return ChildHubSurface(
                    game: _game,
                    audioGuidance: widget.audioGuidance,
                    forceShowEnvBadge: widget.forceShowEnvBadge,
                    onOpenProfiles: () => _go(_ShellRoute.profileSelection),
                    onOpenParentGate: () => _go(_ShellRoute.parentGate),
                  );
                case _ShellRoute.profileSelection:
                  return ProfileSelectionSurface(
                    onBackToHub: () => _go(_ShellRoute.childHub),
                  );
                case _ShellRoute.parentGate:
                  return ParentGateSurface(
                    onBackToHub: () => _go(_ShellRoute.childHub),
                    onOpenSettings: () => _go(_ShellRoute.parentSettings),
                  );
                case _ShellRoute.parentSettings:
                  return ParentSettingsSurface(
                    onBack: () => _go(_ShellRoute.parentGate),
                    onOpenNearFarDemo: () => _openNearFarDemo(
                      returnTo: _ShellRoute.parentSettings,
                    ),
                    onOpenNearFarMentor: () => _go(_ShellRoute.nearFarMentor),
                  );
                case _ShellRoute.nearFarDemo:
                  return NearFarDemoSurface(
                    game: _game,
                    activity: widget.nearFarActivity,
                    onClose: _closeNearFarDemo,
                  );
                case _ShellRoute.nearFarMentor:
                  return NearFarMentorSurface(
                    onBack: () => _go(_ShellRoute.parentSettings),
                    onOpenNearFarMission: () => _openNearFarDemo(
                      returnTo: _ShellRoute.nearFarMentor,
                    ),
                    loader: widget.mentorCardLoader,
                    injectedCard: widget.mentorInjectedCard,
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

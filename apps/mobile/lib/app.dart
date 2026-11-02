import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_session.dart';
import 'auth/auth_token_store.dart';
import 'auth/parent_auth_controller.dart';
import 'auth/parent_auth_repository.dart';
import 'auth/parent_auth_scope.dart';
import 'child_hub/hub_audio_guidance.dart';
import 'child_profiles/child_profile_repository.dart';
import 'child_profiles/child_profiles_controller.dart';
import 'config/app_config.dart';
import 'config/app_config_scope.dart';
import 'game/flame_host.dart';
import 'l10n/app_localizations.dart';
import 'mentor/mentor_card.dart';
import 'mentor/mentor_card_fixtures.dart';
import 'near_far/near_far_activity.dart';
import 'parent_gate/parent_gate_api.dart';
import 'parent_gate/parent_pin_surface.dart';
import 'screen_time/screen_time.dart';
import 'surfaces/child_hub_surface.dart';
import 'surfaces/near_far_demo_surface.dart';
import 'surfaces/near_far_mentor_surface.dart';
import 'surfaces/parent_gate_surface.dart';
import 'surfaces/optional_parent_profile_surface.dart';
import 'surfaces/parent_settings_surface.dart';
import 'surfaces/profile_selection_surface.dart';
import 'surfaces/screen_time_debug_inspector_surface.dart';

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
    this.parentAuthController,
    this.childProfilesController,
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
  /// **Production:** [main] must pass a SharedPreferences-backed coordinator.
  /// **Tests/debug:** when null and not [kReleaseMode], an in-memory fallback
  /// is used. Release builds never silently fall back to in-memory (fail-closed
  /// store instead — no fresh 30-minute day).
  final ScreenTimeCoordinator? screenTime;

  /// Parent authentication (LMP-37). Production injects from [main]; tests may omit.
  final ParentAuthController? parentAuthController;

  /// Injectable state for profile widget tests and real app navigation.
  final ChildProfilesController? childProfilesController;

  @override
  State<LittleMindsApp> createState() => _LittleMindsAppState();
}

enum _ShellRoute {
  childHub,
  profileSelection,
  parentGate,
  parentPinGate,
  parentSettings,
  optionalParentProfile,
  nearFarDemo,
  nearFarMentor,
  screenTimeDebug,
}

bool get _isWidgetTestBinding =>
    WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );

class _LittleMindsAppState extends State<LittleMindsApp> with WidgetsBindingObserver {
  late final StubLearningGame _game = widget.game ?? StubLearningGame();
  late _ShellRoute _route =
      widget.initialNearFarDemo ? _ShellRoute.nearFarDemo : _ShellRoute.childHub;

  /// Where Near/Far demo should return (mentor card or Parent Settings).
  _ShellRoute _nearFarDemoReturn = _ShellRoute.parentSettings;

  late final ScreenTimeCoordinator _screenTime;
  late final bool _ownsScreenTime;
  late final ParentAuthController _parentAuth;
  late final bool _ownsParentAuth;
  late final ChildProfilesController _profiles;
  late final bool _ownsProfiles;
  bool _profileManageMode = false;
  String? _gateToken;
  String? _gateSessionId;
  DateTime? _gateExpiresAt;
  bool get _adultUnlocked => _gateToken != null &&
      _gateSessionId == _parentAuth.session?.sessionId &&
      _gateExpiresAt != null && DateTime.now().isBefore(_gateExpiresAt!);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsScreenTime = widget.screenTime == null;
    _screenTime = widget.screenTime ?? _createFallbackScreenTime();
    _ownsParentAuth = widget.parentAuthController == null;
    _parentAuth = widget.parentAuthController ??
        ParentAuthController(
          repository: ParentAuthRepository(
            config: widget.config,
            tokenStore: InMemoryAuthTokenStore(),
          ),
        );
    _ownsProfiles = widget.childProfilesController == null;
    _profiles = widget.childProfilesController ?? ChildProfilesController(
      repository: ChildProfileRepository(config: widget.config, auth: _parentAuth),
      auth: _parentAuth,
    );
    _parentAuth.addListener(_handleAuthChange);
    // ignore: discarded_futures
    _bootstrapScreenTime();
    if (_ownsParentAuth) {
      if (_isWidgetTestBinding) {
        _parentAuth.seedAuthenticatedSessionForTests(
          const AuthSession(
            accessToken: 'test-access-token',
            refreshToken: 'test-refresh-token',
            sessionId: '00000000-0000-4000-8000-000000000001',
            parentId: '00000000-0000-4000-8000-000000000002',
            expiresInSeconds: 900,
          ),
        );
      } else {
        // ignore: discarded_futures
        _parentAuth.bootstrap();
      }
    }
  }

  /// In-memory only outside release. Release without injection → fail-closed.
  static ScreenTimeCoordinator _createFallbackScreenTime() {
    if (kReleaseMode) {
      return ScreenTimeCoordinator.withDependencies(
        monotonicClock: StopwatchMonotonicClock(),
        wallClock: const SystemWallClock(),
        store: const FailClosedPersistentStore(
          'production must inject SharedPreferences screen-time store',
        ),
        tickInterval: Duration.zero,
      );
    }
    // Test / debug only.
    return ScreenTimeCoordinator.withDependencies(
      monotonicClock: StopwatchMonotonicClock(),
      wallClock: const SystemWallClock(),
      store: InMemoryPersistentStore(),
      tickInterval: Duration.zero,
    );
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
    // Kids Hub + child profile transitions count; Parent / Mentor / Near-Far /
    // debug screen-time inspector do not.
    return route == _ShellRoute.childHub ||
        (route == _ShellRoute.profileSelection && !_profileManageMode);
  }

  // LMP-42: navigation checks live parent identity, not the visibility of a
  // button on the previous screen. Child routes remain reachable signed out.
  bool _requiresParentSession(_ShellRoute route) {
    return route == _ShellRoute.parentSettings ||
        route == _ShellRoute.optionalParentProfile ||
        route == _ShellRoute.nearFarMentor ||
        route == _ShellRoute.nearFarDemo ||
        route == _ShellRoute.screenTimeDebug ||
        (route == _ShellRoute.profileSelection && _profileManageMode);
  }

  void _clearAdultGrant({bool revoke = true}) {
    final token = _gateToken;
    final session = _parentAuth.session;
    _gateToken = null;
    _gateSessionId = null;
    _gateExpiresAt = null;
    if (revoke && token != null && session != null) {
      final api = ParentGateApi(widget.config)..authorize(session);
      // ignore: discarded_futures
      api.lock().catchError((Object _) {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _clearAdultGrant();
      if (mounted && _requiresParentSession(_route)) {
        _profileManageMode = false;
        _go(_ShellRoute.parentGate);
      }
    }
  }

  void _handleAuthChange() {
    if (!mounted) return;
    if (_gateSessionId != null &&
        _parentAuth.session?.sessionId != _gateSessionId) {
      _clearAdultGrant(revoke: false);
    }
    if ((!_parentAuth.isAuthenticated || !_adultUnlocked) &&
        _requiresParentSession(_route)) {
      _profileManageMode = false;
      setState(() => _route = _ShellRoute.parentGate);
      _screenTime.setKidsModeShellActive(false);
    }
  }

  void _go(_ShellRoute route) {
    if (route == _ShellRoute.childHub || route == _ShellRoute.parentGate) {
      _clearAdultGrant();
    }
    final target = _requiresParentSession(route)
        ? (!_parentAuth.isAuthenticated ? _ShellRoute.parentGate
            : !_adultUnlocked ? _ShellRoute.parentPinGate : route)
        : route;
    if (target != route) _profileManageMode = false;
    setState(() => _route = target);
    _screenTime.setKidsModeShellActive(_isKidsModeRoute(target));
  }

  void _openNearFarDemo({required _ShellRoute returnTo}) {
    if (!_parentAuth.isAuthenticated || !_adultUnlocked) {
      _go(_ShellRoute.parentPinGate);
      return;
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _parentAuth.removeListener(_handleAuthChange);
    if (_ownsScreenTime) {
      _screenTime.dispose();
    }
    if (_ownsProfiles) {
      _profiles.dispose();
    }
    if (_ownsParentAuth) {
      _parentAuth.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ParentAuthScope(
      controller: _parentAuth,
      child: AppConfigScope(
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
                    onOpenProfiles: () { _profileManageMode = false; _go(_ShellRoute.profileSelection); },
                    onOpenParentGate: () => _go(_ShellRoute.parentGate),
                  );
                case _ShellRoute.profileSelection:
                  return ProfileSelectionSurface(
                    onBackToHub: () => _go(_profileManageMode ? _ShellRoute.parentSettings : _ShellRoute.childHub),
                    controller: _isWidgetTestBinding && widget.childProfilesController == null ? null : _profiles,
                    allowManage: _profileManageMode,
                  );
                case _ShellRoute.parentGate:
                  return ParentGateSurface(
                    onBackToHub: () => _go(_ShellRoute.childHub),
                    onOpenSettings: () => _go(_ShellRoute.parentSettings),
                  );
                case _ShellRoute.parentPinGate:
                  return ParentPinSurface(
                    auth: _parentAuth,
                    config: widget.config,
                    onBack: () => _go(_ShellRoute.childHub),
                    onUnlocked: (token) {
                      _gateToken = token;
                      _gateSessionId = _parentAuth.session?.sessionId;
                      _gateExpiresAt = DateTime.now().add(const Duration(minutes: 5));
                      _go(_ShellRoute.parentSettings);
                    },
                  );
                case _ShellRoute.optionalParentProfile:
                  return OptionalParentProfileSurface(
                    auth: _parentAuth,
                    config: widget.config,
                    onBack: () => _go(_ShellRoute.parentSettings),
                  );
                case _ShellRoute.parentSettings:
                  return ParentSettingsSurface(
                    onOpenOptionalParentProfile: () => _go(_ShellRoute.optionalParentProfile),
                    onOpenProfiles: () { _profileManageMode = true; _go(_ShellRoute.profileSelection); },
                    onBack: () => _go(_ShellRoute.parentGate),
                    onOpenNearFarDemo: () => _openNearFarDemo(
                      returnTo: _ShellRoute.parentSettings,
                    ),
                    onOpenNearFarMentor: () => _go(_ShellRoute.nearFarMentor),
                    onOpenScreenTimeDebug: kDebugMode
                        ? () => _go(_ShellRoute.screenTimeDebug)
                        : null,
                    forceShowScreenTimeDebugEntry: kDebugMode,
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
                case _ShellRoute.screenTimeDebug:
                  return ScreenTimeDebugInspectorSurface(
                    coordinator: _screenTime,
                    onBack: () => _go(_ShellRoute.parentSettings),
                    forceShowForTest: kDebugMode,
                  );
              }
            },
          ),
        ),
      ),
    ),
    );
  }
}

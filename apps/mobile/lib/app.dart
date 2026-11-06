import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_session.dart';
import 'consent/essential_play_events_consent_scope.dart';
import 'consent/essential_play_events_consent_service.dart';
import 'auth/auth_token_store.dart';
import 'auth/parent_auth_controller.dart';
import 'auth/parent_auth_repository.dart';
import 'auth/parent_auth_scope.dart';
import 'child_hub/hub_audio_guidance.dart';
import 'child_profiles/child_profile_repository.dart';
import 'child_profiles/child_profiles_controller.dart';
import 'config/app_config.dart';
import 'theme/little_minds_parent_theme.dart';
import 'config/app_config_scope.dart';
import 'game/activity_registry.dart';
import 'game/flame_host.dart';
import 'shape_matching/hub_activity_registry.dart';
import 'shape_matching/hub_device_child_binding.dart';
import 'shape_matching/hub_production_telemetry.dart';
import 'l10n/app_localizations.dart';
import 'mentor/mentor_card.dart';
import 'mentor/mentor_card_fixtures.dart';
import 'near_far/near_far_activity.dart';
import 'offline/activity_outbox_sync.dart';
import 'parent_gate/parent_gate_api.dart';
import 'parent_gate/parent_pin_surface.dart';
import 'screen_time/screen_time.dart';
import 'surfaces/child_hub_surface.dart';
import 'surfaces/near_far_demo_surface.dart';
import 'surfaces/near_far_mentor_surface.dart';
import 'surfaces/parent_gate_surface.dart';
import 'surfaces/optional_parent_profile_surface.dart';
import 'parent_dashboard/mission_status_repository.dart';
import 'parent_dashboard/session_kpi_repository.dart';
import 'surfaces/parent_dashboard_surface.dart';
import 'surfaces/essential_play_events_consent_surface.dart';
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
    this.testOnlyAdultAccess = false,
    this.nearFarActivity,
    this.mentorCardLoader,
    this.mentorInjectedCard,
    this.screenTime,
    this.parentAuthController,
    this.offlineSync,
    this.childProfilesController,
    this.parentGateApi,
    this.sessionKpiRepository,
    this.missionStatusRepository,
    this.hubTelemetry,
    this.hubDeviceChildBinding,
    this.essentialPlayConsent,
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

  /// Test fixture only; ignored in release builds and outside Flutter widget tests.
  final bool testOnlyAdultAccess;

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

  /// LMP-51: flush only the current authenticated parent's durable outbox.
  final ActivityOutboxSync? offlineSync;

  /// Injectable state for profile widget tests and real app navigation.
  final ChildProfilesController? childProfilesController;

  /// Widget tests may inject a gate API double (LMP-42 / LMP-53 route guards).
  final ParentGateApi? parentGateApi;

  /// Widget tests may inject session KPI repository (LMP-53 dashboard).
  final SessionKpiRepository? sessionKpiRepository;

  /// Widget tests may inject mission status repository (LMP-53 delivery B).
  final MissionStatusRepository? missionStatusRepository;

  /// LMP-134: optional hub production telemetry coordinator (production [main]).
  final HubProductionTelemetryCoordinator? hubTelemetry;

  /// LMP-134: mirrors server `devices.child_id` before production reconcile.
  final HubDeviceChildBindingService? hubDeviceChildBinding;

  /// LMP-134 server-attested play telemetry consent (production [main]).
  final EssentialPlayEventsConsentService? essentialPlayConsent;

  @override
  State<LittleMindsApp> createState() => _LittleMindsAppState();
}

enum _ShellRoute {
  childHub,
  profileSelection,
  parentGate,
  parentPinGate,
  parentSettings,
  parentDashboard,
  optionalParentProfile,
  nearFarDemo,
  nearFarMentor,
  screenTimeDebug,
  essentialPlayConsent,
}

bool get _isWidgetTestBinding =>
    WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );

/// Mutable bridge so hub registry can read the selected child after bootstrap.
final class _HubChildAgeBridge {
  ChildProfilesController? profiles;
  int? get ageMonths => profiles?.selected?.ageMonths;
}

class _LittleMindsAppState extends State<LittleMindsApp> with WidgetsBindingObserver {
  final _hubChildAge = _HubChildAgeBridge();
  late final ActivityRegistry _hubRegistry = widget.game?.registry ??
      createHubActivityRegistry(
        ageMonthsProvider: () => _hubChildAge.ageMonths,
        options: HubActivityRegistryOptions(
          localeTag: widget.locale?.toLanguageTag() ?? 'en-US',
          telemetryCoordinator: widget.hubTelemetry,
        ),
      );
  late final StubLearningGame _game =
      widget.game ?? StubLearningGame(registry: _hubRegistry);
  late _ShellRoute _route =
      widget.initialNearFarDemo && widget.testOnlyAdultAccess &&
              _isWidgetTestBinding && !kReleaseMode
          ? _ShellRoute.nearFarDemo
          : widget.initialNearFarDemo ? _ShellRoute.parentGate : _ShellRoute.childHub;

  /// Where Near/Far demo should return (mentor card or Parent Settings).
  _ShellRoute _nearFarDemoReturn = _ShellRoute.parentSettings;

  late final ScreenTimeCoordinator _screenTime;
  late final bool _ownsScreenTime;
  late final ParentAuthController _parentAuth;
  late final bool _ownsParentAuth;
  late final ChildProfilesController _profiles;
  late final bool _ownsProfiles;
  bool _profileManageMode = false;
  Timer? _gateTimer;
  Timer? _revokeRetryTimer;
  Timer? _offlineSyncTimer;
  final List<({String token, AuthSession session, DateTime expiresAt})> _pendingRevokes = [];
  bool _revokeInFlight = false;
  int _hubTelemetryReconcileGeneration = 0;
  String? _lastAuthenticatedParentId;

  /// Never reuse a prior session or outbox buffer when launching another play.
  Future<LearningActivity?> _freshActivityForPlay(String activityId) async {
    if (widget.hubTelemetry == null || widget.game != null) {
      return _hubRegistry.findById(activityId);
    }
    final previous = _hubRegistry.findById(activityId);
    await _reconcileHubTelemetry();
    final fresh = _hubRegistry.findById(activityId);
    if (identical(previous, fresh)) return null; // Fail closed on stale telemetry.
    return fresh;
  }

  Future<void> _reconcileHubTelemetry() async {
    final coordinator = widget.hubTelemetry;
    if (coordinator == null || widget.game != null) return;
    final generation = ++_hubTelemetryReconcileGeneration;
    try {
      String? installationId;
      String? scopedDeviceId;
      if (_parentAuth.isAuthenticated) {
        try {
          installationId = await _parentAuth.resolveInstallationId();
          scopedDeviceId = await _parentAuth.resolveScopedDeviceId();
        } catch (_) {
          installationId = null;
          scopedDeviceId = null;
        }
      }
      await widget.hubDeviceChildBinding?.synchronizeSelectedChild(
        readSession: () => _parentAuth.session,
        installationId: installationId,
        scopedDeviceId: scopedDeviceId,
        selectedChildId: _profiles.selectedId,
      );
      if (generation != _hubTelemetryReconcileGeneration) return;
      await coordinator.reconcileHubRegistry(
        registry: _hubRegistry,
        ageMonthsProvider: () => _hubChildAge.ageMonths,
        session: _parentAuth.session,
        selectedChildId: _profiles.selectedId,
        deviceId: scopedDeviceId,
        localeTag: widget.locale?.toLanguageTag() ?? 'en-US',
      );
      if (mounted && generation == _hubTelemetryReconcileGeneration) {
        setState(() {});
      }
    } catch (_) {
      // Hub reconcile must not surface as an unhandled async error from listeners.
    }
  }

  /// A storage/codec failure must not become an unhandled asynchronous error
  /// from a lifecycle callback or timer. Outbox data remains on disk for
  /// explicit diagnosis and subsequent retry.
  void _flushOfflineSafely() {
    final sync = widget.offlineSync;
    if (sync == null) return;
    unawaited(sync.flush().catchError((Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('LMP-51 offline flush failed: ${error.runtimeType}');
      }
    }));
  }

  Future<void> _flushPendingRevokes() async {
    if (_revokeInFlight) return;
    _revokeInFlight = true;
    try {
      for (final item in List.of(_pendingRevokes)) {
        if (DateTime.now().isAfter(item.expiresAt)) {
          _pendingRevokes.remove(item);
          continue;
        }
        try {
          await (ParentGateApi(widget.config)..authorize(item.session)).lock(item.token);
          _pendingRevokes.remove(item);
        } catch (_) {
          // Keep the old grant queued; retry on resume and until server TTL.
        }
      }
    } finally {
      _revokeInFlight = false;
      if (_pendingRevokes.isEmpty) {
        _revokeRetryTimer?.cancel();
        _revokeRetryTimer = null;
      }
    }
  }

  String? _gateToken;
  String? _gateSessionId;
  AuthSession? _gateSession;
  DateTime? _gateExpiresAt;
  bool get _adultUnlocked =>
      (widget.testOnlyAdultAccess && _isWidgetTestBinding && !kReleaseMode &&
          _parentAuth.isAuthenticated) ||
      (_gateToken != null &&
      _gateSessionId == _parentAuth.session?.sessionId &&
      _gateExpiresAt != null && DateTime.now().isBefore(_gateExpiresAt!));

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
      repository: ChildProfileRepository(
        config: widget.config,
        auth: _parentAuth,
        gateTokenProvider: () => _gateToken,
      ),
      auth: _parentAuth,
    );
    _hubChildAge.profiles = _profiles;
    _parentAuth.addListener(_handleAuthChange);
    _profiles.addListener(_reconcileHubTelemetry);
    widget.essentialPlayConsent?.addListener(_reconcileHubTelemetry);
    if (widget.offlineSync != null) {
      _flushOfflineSafely();
      _offlineSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (mounted && _parentAuth.isAuthenticated) {
          _flushOfflineSafely();
        }
      });
    }
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
    // ignore: discarded_futures
    _reconcileHubTelemetry();
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
        route == _ShellRoute.parentDashboard ||
        route == _ShellRoute.optionalParentProfile ||
        route == _ShellRoute.essentialPlayConsent ||
        route == _ShellRoute.nearFarMentor ||
        route == _ShellRoute.nearFarDemo ||
        route == _ShellRoute.screenTimeDebug ||
        (route == _ShellRoute.profileSelection && _profileManageMode);
  }

  void _clearAdultGrant({bool revoke = true}) {
    final token = _gateToken;
    final session = _gateSession;
    _gateTimer?.cancel();
    _gateTimer = null;
    _gateToken = null;
    _gateSessionId = null;
    _gateSession = null;
    _gateExpiresAt = null;
    if (revoke && token != null && session != null) {
      _pendingRevokes.add((
        token: token,
        session: session,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      ));
      _revokeRetryTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _flushPendingRevokes(),
      );
      // ignore: discarded_futures
      _flushPendingRevokes();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: discarded_futures
      _flushPendingRevokes();
      if (widget.offlineSync != null) {
        _flushOfflineSafely();
      }
    }
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
    final session = _parentAuth.session;
    if (session == null && _lastAuthenticatedParentId != null) {
      // ignore: discarded_futures
      widget.hubDeviceChildBinding?.onParentLoggedOut(_lastAuthenticatedParentId!);
      widget.essentialPlayConsent?.clearForLogout();
      _lastAuthenticatedParentId = null;
    } else if (session != null) {
      _lastAuthenticatedParentId = session.parentId;
      // ignore: discarded_futures
      widget.essentialPlayConsent?.refresh(session);
    }
    if (_parentAuth.isAuthenticated && widget.offlineSync != null) {
      _flushOfflineSafely();
    }
    // ignore: discarded_futures
    _reconcileHubTelemetry();
    if (_gateSessionId != null &&
        _parentAuth.session?.sessionId != _gateSessionId) {
      _clearAdultGrant();
      if (_route == _ShellRoute.parentPinGate) {
        _go(_ShellRoute.parentGate);
        return;
      }
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
    _gateTimer?.cancel();
    _revokeRetryTimer?.cancel();
    _offlineSyncTimer?.cancel();
    _parentAuth.removeListener(_handleAuthChange);
    _profiles.removeListener(_reconcileHubTelemetry);
    widget.essentialPlayConsent?.removeListener(_reconcileHubTelemetry);
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

  Widget _wrapConsentScope(Widget child) {
    final consent = widget.essentialPlayConsent;
    if (consent == null) return child;
    return EssentialPlayEventsConsentScope(
      notifier: consent,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParentAuthScope(
      controller: _parentAuth,
      child: AppConfigScope(
        config: widget.config,
        child: ScreenTimeScope(
          coordinator: _screenTime,
          child: _wrapConsentScope(
            MaterialApp(
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
          theme: LittleMindsParentTheme.theme(),
          home: Builder(
            builder: (context) {
              switch (_route) {
                case _ShellRoute.childHub:
                  return ChildHubSurface(
                    game: _game,
                    resolveActivityForPlay: _freshActivityForPlay,
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
                    api: widget.parentGateApi,
                    onBack: () => _go(_ShellRoute.childHub),
                    onUnlocked: (token) {
                      _gateToken = token;
                      _gateSessionId = _parentAuth.session?.sessionId;
                      _gateSession = _parentAuth.session;
                      _gateExpiresAt = DateTime.now().add(const Duration(minutes: 5));
                      _gateTimer?.cancel();
                      _gateTimer = Timer(const Duration(minutes: 5), () {
                        if (!mounted) return;
                        _clearAdultGrant();
                        _profileManageMode = false;
                        _go(_ShellRoute.parentGate);
                      });
                      _go(_ShellRoute.parentSettings);
                    },
                  );
                case _ShellRoute.optionalParentProfile:
                  return OptionalParentProfileSurface(
                    auth: _parentAuth,
                    config: widget.config,
                    gateToken: _gateToken,
                    onBack: () => _go(_ShellRoute.parentSettings),
                  );
                case _ShellRoute.parentSettings:
                  return ParentSettingsSurface(
                    onOpenOptionalParentProfile: () => _go(_ShellRoute.optionalParentProfile),
                    onOpenEssentialPlayConsent: widget.essentialPlayConsent != null
                        ? () => _go(_ShellRoute.essentialPlayConsent)
                        : null,
                    onOpenProfiles: () { _profileManageMode = true; _go(_ShellRoute.profileSelection); },
                    onOpenParentDashboard: () => _go(_ShellRoute.parentDashboard),
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
                case _ShellRoute.parentDashboard:
                  return ParentDashboardSurface(
                    auth: _parentAuth,
                    profiles: _profiles,
                    repository: widget.sessionKpiRepository ??
                        SessionKpiRepository(
                          config: widget.config,
                          auth: _parentAuth,
                        ),
                    missionRepository: widget.missionStatusRepository ??
                        MissionStatusRepository(
                          config: widget.config,
                          auth: _parentAuth,
                        ),
                    onBack: () => _go(_ShellRoute.parentSettings),
                    onManageProfiles: () {
                      _profileManageMode = true;
                      _go(_ShellRoute.profileSelection);
                    },
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
                case _ShellRoute.essentialPlayConsent:
                  return EssentialPlayEventsConsentSurface(
                    onBack: () => _go(_ShellRoute.parentSettings),
                    onCompleted: () {
                      // ignore: discarded_futures
                      _reconcileHubTelemetry();
                      _go(_ShellRoute.parentSettings);
                    },
                  );
              }
            },
          ),
        ),
      ),
    ),
    ),
    );
  }
}

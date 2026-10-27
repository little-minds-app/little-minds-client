import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'child_hub/hub_audio_guidance.dart';
import 'config/app_config.dart';
import 'config/app_config_scope.dart';
import 'game/flame_host.dart';
import 'l10n/app_localizations.dart';
import 'near_far/near_far_activity.dart';
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

  void _go(_ShellRoute route) => setState(() => _route = route);

  void _openNearFarDemo({required _ShellRoute returnTo}) {
    setState(() {
      _nearFarDemoReturn = returnTo;
      _route = _ShellRoute.nearFarDemo;
    });
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
  Widget build(BuildContext context) {
    return AppConfigScope(
      config: widget.config,
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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
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
                );
            }
          },
        ),
      ),
    );
  }
}

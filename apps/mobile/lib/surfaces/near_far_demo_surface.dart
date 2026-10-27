import 'package:flutter/material.dart';

import '../game/activity_session_controller.dart';
import '../game/flame_host.dart';
import '../game/game_lifecycle_phase.dart';
import '../game/scoring_neutral_outcome.dart';
import '../l10n/app_localizations.dart';
import '../near_far/near_far_activity.dart';
import '../near_far/near_far_mission_handoff.dart';
import '../near_far/near_far_mission_handoff_panel.dart';
import '../near_far/near_far_play_field.dart';
import '../near_far/near_far_spoken_labels.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';

/// Dedicated Kids Mode Near/Far demo route (LMP-45).
///
/// Separate from the six-game Hub catalog / [ActivityRegistry]. Reuses the
/// shared Flame [ActivitySessionController] lifecycle without registering a
/// seventh Hub tile or flipping Coming Soon cards.
class NearFarDemoSurface extends StatefulWidget {
  const NearFarDemoSurface({
    super.key,
    required this.onClose,
    this.activity,
    this.controller,
    this.game,
    this.soundOff = false,
  });

  final VoidCallback onClose;
  final NearFarActivity? activity;
  final ActivitySessionController? controller;
  final StubLearningGame? game;
  final bool soundOff;

  static const Key surfaceKey = Key('surface-near-far-demo');
  static const Key closeKey = Key('near-far-demo-close');
  static const Key pauseKey = Key('near-far-demo-pause');
  static const Key resumeKey = Key('near-far-demo-resume');
  static const Key restartKey = Key('near-far-demo-restart');
  static const Key phaseKey = Key('near-far-demo-phase');
  static const Key loadingKey = Key('near-far-demo-loading');
  static const Key spokenBlockedKey = Key('near-far-spoken-blocked');

  @override
  State<NearFarDemoSurface> createState() => _NearFarDemoSurfaceState();
}

class _NearFarDemoSurfaceState extends State<NearFarDemoSurface>
    with WidgetsBindingObserver {
  late final StubLearningGame _game;
  late final ActivitySessionController _controller;
  late final bool _ownsController;
  NearFarActivity? _activity;
  var _enterStarted = false;
  var _activityBound = false;
  var _completionReported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = widget.game ?? StubLearningGame();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ActivitySessionController();
    _controller.attachGame(_game);
    _controller.addListener(_onChanged);
    if (widget.activity != null) {
      _activity = widget.activity;
      _activity!.addListener(_onChanged);
      _activityBound = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureEntered());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_activityBound) {
      return;
    }
    final locale = Localizations.localeOf(context);
    _activity = NearFarActivity(
      soundOff: widget.soundOff,
      localeTag: nearFarLocaleTag(locale),
    );
    _activity!.addListener(_onChanged);
    _activityBound = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureEntered());
  }

  Future<void> _ensureEntered() async {
    if (_enterStarted || !mounted) {
      return;
    }
    _enterStarted = true;
    final activity = _activity;
    if (activity == null) {
      return;
    }
    final ok = await _controller.enter(activity);
    if (!mounted || _controller.isDisposed) {
      return;
    }
    if (!ok && _controller.phase == GameLifecyclePhase.idle) {
      widget.onClose();
    }
  }

  void _onChanged() {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    final outcome = _activity?.lastOutcome;
    if (!_completionReported && outcome is ActivityCompletedOutcome) {
      _completionReported = true;
      _controller.reportOutcome(outcome);
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    // ignore: discarded_futures
    _controller.handleAppLifecycle(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activity?.removeListener(_onChanged);
    _controller.removeListener(_onChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _onClose() async {
    await _controller.exit();
    if (mounted) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phase = _controller.phase;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final activity = _activity;
    if (activity == null) {
      return const SizedBox.shrink(key: NearFarDemoSurface.surfaceKey);
    }
    final showHandoff = activity.missionHandoff.handoff.state ==
            NearFarMissionHandoffState.offered ||
        activity.missionHandoff.handoff.state ==
            NearFarMissionHandoffState.opened ||
        (_controller.lastOutcome is ActivityCompletedOutcome);

    return OrientationBinder(
      surface: AppSurface.miniGame,
      child: KeyedSubtree(
        key: NearFarDemoSurface.surfaceKey,
        child: Column(
          children: [
            _DemoChrome(
              l10n: l10n,
              phase: phase,
              onClose: _onClose,
              onPause: _controller.pause,
              onResume: _controller.resume,
              onRestart: _controller.restart,
            ),
            if (!activity.spokenAssetsReady &&
                phase != GameLifecyclePhase.preparing &&
                phase != GameLifecyclePhase.idle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  key: NearFarDemoSurface.spokenBlockedKey,
                  l10n.nearFarSpokenAssetsBlocked,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (phase == GameLifecyclePhase.preparing ||
                      phase == GameLifecyclePhase.idle)
                    const Center(
                      key: NearFarDemoSurface.loadingKey,
                      child: CircularProgressIndicator.adaptive(),
                    )
                  else
                    NearFarPlayField(
                      activity: activity,
                      reduceMotion: reduceMotion,
                    ),
                  if (showHandoff &&
                      activity.missionHandoff.handoff.state !=
                          NearFarMissionHandoffState.dismissed)
                    NearFarMissionHandoffPanel(
                      activity: activity,
                      onDismiss: _onClose,
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        key: NearFarDemoSurface.phaseKey,
                        _phaseLabel(l10n, phase),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(AppLocalizations l10n, GameLifecyclePhase phase) {
    switch (phase) {
      case GameLifecyclePhase.idle:
        return l10n.activityPhaseIdle;
      case GameLifecyclePhase.preparing:
        return l10n.activityPhasePreparing;
      case GameLifecyclePhase.running:
        return l10n.activityPhasePlaying;
      case GameLifecyclePhase.paused:
        return l10n.activityPhasePaused;
      case GameLifecyclePhase.backgrounded:
        return l10n.activityPhaseBackground;
      case GameLifecyclePhase.completed:
        return l10n.activityPhaseCompleted;
      case GameLifecyclePhase.disposed:
        return l10n.activityPhaseIdle;
    }
  }
}

class _DemoChrome extends StatelessWidget {
  const _DemoChrome({
    required this.l10n,
    required this.phase,
    required this.onClose,
    required this.onPause,
    required this.onResume,
    required this.onRestart,
  });

  final AppLocalizations l10n;
  final GameLifecyclePhase phase;
  final VoidCallback onClose;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final canPause = phase == GameLifecyclePhase.running;
    final canResume = phase == GameLifecyclePhase.paused;
    final canRestart = phase.canRestart;

    return Material(
      color: const Color(0xFFE8F5E9),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
          child: Row(
            children: [
              TextButton.icon(
                key: NearFarDemoSurface.closeKey,
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(l10n.nearFarBack),
              ),
              Expanded(
                child: Text(
                  l10n.nearFarTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (canPause)
                IconButton(
                  key: NearFarDemoSurface.pauseKey,
                  tooltip: l10n.activityPause,
                  onPressed: onPause,
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                ),
              if (canResume)
                IconButton(
                  key: NearFarDemoSurface.resumeKey,
                  tooltip: l10n.activityResume,
                  onPressed: onResume,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                ),
              if (canRestart)
                IconButton(
                  key: NearFarDemoSurface.restartKey,
                  tooltip: l10n.activityRestart,
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

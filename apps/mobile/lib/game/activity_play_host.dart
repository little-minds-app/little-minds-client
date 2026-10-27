import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../config/env_config_badge.dart';
import '../l10n/app_localizations.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../screen_time/screen_time.dart';
import 'activity_session_controller.dart';
import 'activity_session_snapshot.dart';
import 'flame_host.dart';
import 'game_lifecycle_phase.dart';
import 'learning_activity.dart';

/// Landscape mini-game host with shared Flame lifecycle (LMP-44 / ADR-018).
///
/// Does not hard-code activity ids — callers pass a playable [LearningActivity]
/// resolved via [ActivityRegistry] (or test DI). Production bootstrap keeps the
/// registry empty so Child Hub cards stay passive.
class ActivityPlayHost extends StatefulWidget {
  const ActivityPlayHost({
    super.key,
    required this.game,
    required this.activity,
    required this.onClose,
    this.showEnvBadge = false,
    this.controller,
  });

  final StubLearningGame game;
  final LearningActivity activity;
  final VoidCallback onClose;
  final bool showEnvBadge;

  /// Optional injected controller (tests). When null, a private one is created.
  final ActivitySessionController? controller;

  static const Key hostKey = Key('activity-play-host');
  static const Key closeKey = Key('hub-close-play-host');
  static const Key pauseKey = Key('activity-play-pause');
  static const Key resumeKey = Key('activity-play-resume');
  static const Key restartKey = Key('activity-play-restart');
  static const Key phaseKey = Key('activity-play-phase');
  static const Key errorKey = Key('activity-play-error');
  static const Key loadingKey = Key('activity-play-loading');

  @override
  State<ActivityPlayHost> createState() => _ActivityPlayHostState();
}

class _ActivityPlayHostState extends State<ActivityPlayHost>
    with WidgetsBindingObserver {
  late final ActivitySessionController _controller;
  late final bool _ownsController;
  ActivitySessionSnapshot? _orientationSnapshot;
  Size? _lastViewport;
  var _enterStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ActivitySessionController();
    _controller.attachGame(widget.game);
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureEntered());
  }

  Future<void> _ensureEntered() async {
    if (_enterStarted || !mounted) {
      return;
    }
    _enterStarted = true;
    final ok = await _controller.enter(widget.activity);
    if (!mounted || _controller.isDisposed) {
      return;
    }
    if (!ok && _controller.phase == GameLifecyclePhase.idle) {
      // Offline prepare failed — return to hub safely.
      widget.onClose();
    }
  }

  void _onControllerChanged() {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    ScreenTimeScope.maybeOf(context)?.setGameplayPhase(_controller.phase);
    final screenTime = ScreenTimeScope.maybeOf(context);
    if (screenTime != null &&
        !screenTime.allowsChildPlay &&
        _controller.phase == GameLifecyclePhase.running) {
      // Cap / trust fail-closed mid-session — pause; do not resume.
      // ignore: discarded_futures
      _controller.pause();
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
  void didUpdateWidget(covariant ActivityPlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      _controller.attachGame(widget.game);
    }
    if (oldWidget.activity.id != widget.activity.id) {
      _enterStarted = false;
      _ensureEntered();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
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

  Future<void> _onPause() => _controller.pause();

  Future<void> _onResume() async {
    final screenTime = ScreenTimeScope.maybeOf(context);
    if (screenTime != null && !screenTime.allowsChildPlay) {
      return;
    }
    await _controller.resume();
  }

  Future<void> _onRestart() async {
    final screenTime = ScreenTimeScope.maybeOf(context);
    if (screenTime != null && !screenTime.allowsChildPlay) {
      return;
    }
    await _controller.restart();
  }

  Future<void> _handleViewport(Size viewport) async {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    if (_lastViewport == null) {
      _lastViewport = viewport;
      return;
    }
    if (_lastViewport == viewport) {
      return;
    }
    // Preserve play state across window / orientation size changes (ADR-018).
    _orientationSnapshot = _controller.captureSnapshot();
    _lastViewport = viewport;
    final snap = _orientationSnapshot;
    if (snap == null) {
      return;
    }
    await _controller.restoreSnapshot(snap);
    if (!mounted || _controller.isDisposed) {
      return;
    }
  }

  static const Key inputBlockKey = Key('activity-play-input-blocked');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phase = _controller.phase;
    final screenTime = ScreenTimeScope.maybeOf(context);
    final blockInput = screenTime != null && !screenTime.allowsChildPlay;

    return OrientationBinder(
      surface: AppSurface.miniGame,
      child: KeyedSubtree(
        key: ActivityPlayHost.hostKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              // ignore: discarded_futures
              _handleViewport(viewport);
            });

            return Column(
              children: [
                _PlayChrome(
                  l10n: l10n,
                  phase: phase,
                  allowSessionControls: !blockInput,
                  onClose: _onClose,
                  onPause: _onPause,
                  onResume: _onResume,
                  onRestart: _onRestart,
                ),
                if (widget.showEnvBadge)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: EnvConfigBadge(forceVisible: true),
                  ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AbsorbPointer(
                        absorbing: blockInput,
                        child: GameWidget(game: widget.game),
                      ),
                      if (blockInput)
                        const ModalBarrier(
                          key: inputBlockKey,
                          dismissible: false,
                          color: Color(0x33000000),
                        ),
                      if (phase == GameLifecyclePhase.preparing)
                        const Center(
                          key: ActivityPlayHost.loadingKey,
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      if (_controller.lastError != null)
                        Center(
                          key: ActivityPlayHost.errorKey,
                          child: Text(
                            l10n.activitySessionUnavailable,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Quiet status for a11y / tests — never a numeric score.
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            key: ActivityPlayHost.phaseKey,
                            _phaseLabel(l10n, phase),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.black54,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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

class _PlayChrome extends StatelessWidget {
  const _PlayChrome({
    required this.l10n,
    required this.phase,
    required this.allowSessionControls,
    required this.onClose,
    required this.onPause,
    required this.onResume,
    required this.onRestart,
  });

  final AppLocalizations l10n;
  final GameLifecyclePhase phase;
  final bool allowSessionControls;
  final VoidCallback onClose;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final canPause =
        allowSessionControls && phase == GameLifecyclePhase.running;
    final canResume =
        allowSessionControls && phase == GameLifecyclePhase.paused;
    final canRestart = allowSessionControls && phase.canRestart;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          TextButton.icon(
            key: ActivityPlayHost.closeKey,
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(l10n.activityBackToHub),
          ),
          const Spacer(),
          if (canPause)
            IconButton(
              key: ActivityPlayHost.pauseKey,
              tooltip: l10n.activityPause,
              onPressed: onPause,
              icon: const Icon(Icons.pause_circle_outline_rounded),
            ),
          if (canResume)
            IconButton(
              key: ActivityPlayHost.resumeKey,
              tooltip: l10n.activityResume,
              onPressed: onResume,
              icon: const Icon(Icons.play_circle_outline_rounded),
            ),
          if (canRestart)
            IconButton(
              key: ActivityPlayHost.restartKey,
              tooltip: l10n.activityRestart,
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}

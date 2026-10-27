import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config_scope.dart';
import '../config/app_environment.dart';
import '../l10n/app_localizations.dart';
import '../mentor/mentor_card.dart';
import '../mentor/mentor_card_fixtures.dart';
import '../mentor/mentor_card_view.dart';
import '../near_far/near_far_spoken_labels.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Parent Near/Far mentor card surface (LMP-48).
///
/// Loads pinned localized fixtures via [MentorCardFixtureLoader]. Caregiver-
/// ready presentation is gated by [MentorCardReviewGate]; draft fixtures use
/// an explicit debug/development preview only — never on staging/production.
///
/// Optional [onOpenNearFarMission] opens the existing Near/Far demo + mission
/// handoff (no duplicate mission UI, no Kids Hub tile).
class NearFarMentorSurface extends StatefulWidget {
  const NearFarMentorSurface({
    super.key,
    this.onBack,
    this.onOpenNearFarMission,
    this.loader,
    this.forceDraftPreview = false,
    this.childAgeMonths,
    this.injectedCard,
  });

  final VoidCallback? onBack;

  /// Opens the existing Near/Far Kids Mode demo (digital play + mission).
  final VoidCallback? onOpenNearFarMission;

  /// Optional fixture loader override (tests / DI).
  final MentorCardFixtureLoader? loader;

  /// Test-only override to preview draft without relying on debug/dev gates.
  final bool forceDraftPreview;

  /// Optional child age for age-applicability messaging.
  final int? childAgeMonths;

  /// Optional preloaded card (widget tests / approved synthetic fixtures).
  final MentorCardV1? injectedCard;

  static const Key surfaceKey = Key('surface-near-far-mentor');
  static const Key loadingKey = Key('near-far-mentor-loading');
  static const Key errorKey = Key('near-far-mentor-error');
  static const Key scrollKey = Key('near-far-mentor-scroll');

  @override
  State<NearFarMentorSurface> createState() => _NearFarMentorSurfaceState();
}

class _NearFarMentorSurfaceState extends State<NearFarMentorSurface> {
  late final MentorCardFixtureLoader _loader =
      widget.loader ?? MentorCardFixtureLoader();

  MentorCardV1? _card;
  Object? _error;
  bool _loading = true;
  String? _loadedLocaleTag;
  bool _loadStarted = false;

  /// Draft preview is isolated to debug + development (or explicit test force).
  /// Staging/production never treat draft as caregiver-ready content.
  bool _allowDraftPreview(BuildContext context) {
    if (widget.forceDraftPreview) return true;
    if (!kDebugMode) return false;
    final env = AppConfigScope.maybeOf(context)?.environment;
    return env == null || env == AppEnvironment.development;
  }

  @override
  void initState() {
    super.initState();
    if (widget.injectedCard != null) {
      _card = widget.injectedCard;
      _loading = false;
      _loadStarted = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.injectedCard != null) {
      return;
    }
    final localeTag = nearFarLocaleTag(Localizations.localeOf(context));
    if (!_loadStarted || _loadedLocaleTag != localeTag) {
      _load(localeTag);
    }
  }

  Future<void> _load(String localeTag) async {
    _loadStarted = true;
    _loadedLocaleTag = localeTag;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final card = await _loader.requireNearFar(locale: localeTag);
      if (!mounted) return;
      // Ignore stale responses after a locale change.
      if (_loadedLocaleTag != localeTag) return;
      setState(() {
        _card = card;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (_loadedLocaleTag != localeTag) return;
      setState(() {
        _error = error;
        _card = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OrientationBinder(
      surface: AppSurface.parentSettings,
      child: AdaptiveShell(
        title: l10n.mentorCardSurfaceTitle,
        actions: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
            child: TextButton(
              key: const Key('nav-back-from-mentor'),
              onPressed: widget.onBack,
              child: Text(l10n.mentorCardBack),
            ),
          ),
        ],
        body: KeyedSubtree(
          key: NearFarMentorSurface.surfaceKey,
          child: _buildBody(context, l10n),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return Center(
        key: NearFarMentorSurface.loadingKey,
        child: Semantics(
          liveRegion: true,
          label: l10n.mentorCardLoading,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _card == null) {
      return Center(
        key: NearFarMentorSurface.errorKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.mentorCardLoadError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 148),
                child: FilledButton(
                  onPressed: () {
                    final localeTag =
                        nearFarLocaleTag(Localizations.localeOf(context));
                    _load(localeTag);
                  },
                  child: Text(l10n.mentorCardRetry),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        key: NearFarMentorSurface.scrollKey,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: MentorCardView(
              card: _card!,
              childAgeMonths: widget.childAgeMonths,
              allowDraftPreview: _allowDraftPreview(context),
              onOpenMission: widget.onOpenNearFarMission,
            ),
          ),
        ),
      ),
    );
  }
}

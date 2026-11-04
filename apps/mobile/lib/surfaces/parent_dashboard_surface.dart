import 'package:flutter/material.dart';

import '../child_profiles/child_profiles_controller.dart';
import '../l10n/app_localizations.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../parent_dashboard/mission_status_repository.dart';
import '../parent_dashboard/mission_status_view_data.dart';
import '../parent_dashboard/parent_dashboard_controller.dart';
import '../parent_dashboard/parent_dashboard_view_data.dart';
import '../parent_dashboard/session_kpi_repository.dart';
import '../parent_dashboard/widgets/session_composition_donut.dart';
import '../shell/adaptive_shell.dart';
import '../auth/parent_auth_controller.dart';
import '../feedback/parent_feedback_banner.dart';

/// Authenticated parent overview — real session KPIs from LMP-52 (LMP-53).
class ParentDashboardSurface extends StatefulWidget {
  const ParentDashboardSurface({
    super.key,
    required this.auth,
    required this.profiles,
    required this.repository,
    required this.missionRepository,
    this.controller,
    this.onBack,
    this.onManageProfiles,
  });

  final ParentAuthController auth;
  final ChildProfilesController profiles;
  final SessionKpiRepository repository;
  final MissionStatusRepository missionRepository;
  final ParentDashboardController? controller;
  final VoidCallback? onBack;
  final VoidCallback? onManageProfiles;

  static const Key surfaceKey = Key('surface-parent-dashboard');
  static const Key loadingKey = Key('parent-dashboard-loading');
  static const Key contentKey = Key('parent-dashboard-content');
  static const Key emptyKey = Key('parent-dashboard-empty');
  static const Key errorKey = Key('parent-dashboard-error');
  static const Key kpiErrorKey = Key('parent-dashboard-kpi-error');
  static const Key kpiRetryKey = Key('parent-dashboard-kpi-retry');
  static const Key missionUnavailableKey = Key('parent-dashboard-mission-unavailable');
  static const Key missionLoadingKey = Key('parent-dashboard-mission-loading');
  static const Key missionContentKey = Key('parent-dashboard-mission-content');
  static const Key missionEmptyKey = Key('parent-dashboard-mission-empty');
  static const Key missionTruncatedKey = Key('parent-dashboard-mission-truncated');
  static const Key missionRowKey = Key('parent-dashboard-mission-row');
  static const Key refreshKey = Key('parent-dashboard-refresh');
  static const Key childPromptKey = Key('parent-dashboard-child-prompt');
  static const Key emptyBannerKey = Key('parent-dashboard-empty-banner');
  static const Key activityChartKey = Key('parent-dashboard-activity-chart');
  static const Key childSwitcherKey = Key('parent-dashboard-child-switcher');

  @override
  State<ParentDashboardSurface> createState() => _ParentDashboardSurfaceState();
}

class _ParentDashboardSurfaceState extends State<ParentDashboardSurface> {
  late final ParentDashboardController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ParentDashboardController(
          repository: widget.repository,
          missionRepository: widget.missionRepository,
          auth: widget.auth,
          profiles: widget.profiles,
        );
    // ignore: discarded_futures
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBinder(
      surface: AppSurface.parentDashboard,
      child: AdaptiveShell(
        title: 'Ebeveyn Özeti',
        actions: [
          IconButton(
            key: ParentDashboardSurface.refreshKey,
            tooltip: 'Yenile',
            onPressed: _controller.phase == ParentDashboardPhase.loading ||
                    _controller.phase == ParentDashboardPhase.initial
                ? null
                : () => _controller.refresh(),
            icon: const Icon(Icons.refresh),
          ),
          if (widget.onBack != null)
            TextButton(
              key: const Key('nav-back-from-dashboard'),
              onPressed: widget.onBack,
              child: const Text('Geri'),
            ),
        ],
        body: KeyedSubtree(
          key: ParentDashboardSurface.surfaceKey,
          child: AnimatedBuilder(
            animation: Listenable.merge([_controller, widget.profiles]),
            builder: (context, _) => _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_controller.needsChildSelection) {
      return Center(
        key: ParentDashboardSurface.childPromptKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Özet için bir çocuk profili seçin veya oluşturun.',
                textAlign: TextAlign.center,
              ),
              if (widget.profiles.children.isNotEmpty) ...[
                const SizedBox(height: 16),
                _childProfileSwitcher(context, allowSingleSelect: true),
              ],
              if (widget.onManageProfiles != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onManageProfiles,
                  child: const Text('Çocuk profillerini yönet'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_controller.phase == ParentDashboardPhase.loading ||
        _controller.phase == ParentDashboardPhase.initial) {
      return const Center(
        key: ParentDashboardSurface.loadingKey,
        child: CircularProgressIndicator(),
      );
    }

    if (_showOverviewWithKpiFailure) {
      return _overview(context, empty: false, kpiFailed: true);
    }

    switch (_controller.phase) {
      case ParentDashboardPhase.unauthorized:
      case ParentDashboardPhase.childNotFound:
      case ParentDashboardPhase.error:
        return Center(
          key: ParentDashboardSurface.errorKey,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ParentFeedbackBanner(
                kind: ParentFeedbackKind.error,
                title: 'Özet yüklenemedi',
                message: _controller.failure?.userMessage ?? 'Veriler yüklenemedi.',
                onRetry: () => _controller.refresh(),
              ),
            ),
          ),
        );
      case ParentDashboardPhase.empty:
        return _overview(context, empty: true);
      case ParentDashboardPhase.loaded:
        return _overview(context, empty: false);
      case ParentDashboardPhase.loading:
      case ParentDashboardPhase.initial:
        return const SizedBox.shrink();
    }
  }

  /// Keep mission visible only for recoverable KPI outages (network/5xx), not auth/ownership failures.
  bool get _showOverviewWithKpiFailure {
    final missionReady = _controller.missionPhase == MissionStatusPhase.loaded ||
        _controller.missionPhase == MissionStatusPhase.empty;
    return missionReady &&
        _controller.phase == ParentDashboardPhase.error &&
        _controller.failure is SessionKpiNetwork;
  }

  Widget _overview(BuildContext context, {required bool empty, bool kpiFailed = false}) {
    final view = _controller.view;
    return SingleChildScrollView(
      key: empty ? ParentDashboardSurface.emptyKey : ParentDashboardSurface.contentKey,
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.profiles.children.isNotEmpty) ...[
                _childProfileSwitcher(context),
                const SizedBox(height: 8),
              ],
              if (kpiFailed)
                ParentFeedbackBanner(
                  key: ParentDashboardSurface.kpiErrorKey,
                  kind: ParentFeedbackKind.error,
                  title: 'Oturum özeti kullanılamıyor',
                  message: _controller.failure?.userMessage ??
                      'Oturum özeti yüklenemedi.',
                  onRetry: () => _controller.refresh(),
                  retryLabel: 'Oturum özetini yeniden dene',
                  retryKey: ParentDashboardSurface.kpiRetryKey,
                )
              else if (view != null) ...[
                if (empty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ParentFeedbackBanner(
                      key: ParentDashboardSurface.emptyBannerKey,
                      kind: ParentFeedbackKind.info,
                      title: 'Henüz oturum yok',
                      message: 'Bu pencerede uygun oturum bulunamadı. Zaman aralığı ve örnek bilgileri sunucudan gelmektedir.',
                    ),
                  ),
                _kpiCard(context, view),
              ],
              const SizedBox(height: 24),
              _missionPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missionPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gerçek dünya görevleri',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Sunucu kayıtlı etkileşim ve ebeveyn bildirimi (Near/Far yerel durumu değil).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            switch (_controller.missionPhase) {
              MissionStatusPhase.initial ||
              MissionStatusPhase.loading =>
                const Center(
                  key: ParentDashboardSurface.missionLoadingKey,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              MissionStatusPhase.unavailable => Text(
                  key: ParentDashboardSurface.missionUnavailableKey,
                  _controller.missionFailure?.userMessage ??
                      ParentDashboardController.missionStatusUnavailableMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              MissionStatusPhase.empty => Text(
                  key: ParentDashboardSurface.missionEmptyKey,
                  'Bu pencerede görev kaydı yok.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              MissionStatusPhase.loaded => _missionLoaded(context),
            },
          ],
        ),
      ),
    );
  }

  Widget _missionLoaded(BuildContext context) {
    final mission = _controller.missionView;
    if (mission == null) {
      return Text(
        key: ParentDashboardSurface.missionUnavailableKey,
        ParentDashboardController.missionStatusUnavailableMessage,
      );
    }
    return KeyedSubtree(
      key: ParentDashboardSurface.missionContentKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pencere: ${mission.windowLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Sunucu üretimi: ${mission.freshnessLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (mission.truncated)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                key: ParentDashboardSurface.missionTruncatedKey,
                'Liste sınırı nedeniyle daha fazla kayıt olabilir.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.orange.shade800,
                    ),
              ),
            ),
          for (final row in mission.rows)
            ListTile(
              key: ParentDashboardSurface.missionRowKey,
              dense: true,
              title: Text('${row.missionId} · ${row.occurrenceId}'),
              subtitle: Text(
                '${row.interactionLabel}\n${row.reportLabel}',
              ),
              leading: Icon(
                switch (row.reportPresentation) {
                  MissionReportPresentation.reported => Icons.check_circle_outline,
                  MissionReportPresentation.noReport => Icons.info_outline,
                  MissionReportPresentation.interactionOnly => Icons.play_circle_outline,
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpiCard(BuildContext context, ParentDashboardViewData view) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Oturum istatistikleri', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricTile(context, 'Uygun oturum', '${view.eligibleSessions}', emphasized: true),
                _metricTile(context, 'Tamamlanan', '${view.completedSessions}'),
                _metricTile(context, 'Yarıda kalan', '${view.interruptedSessions}'),
                _metricTile(context, 'Devam eden', '${view.inProgressSessions}'),
                _metricTile(context, 'Toplam oyun süresi', view.totalPlayDurationLabel, emphasized: true),
                _metricTile(
                  context,
                  'Tamamlanma oranı',
                  view.completedRateLabel,
                  unavailable: view.completedRateUnavailable,
                ),
                _metricTile(context, 'Farklı oyun günü', '${view.distinctPlayDays}'),
                _metricTile(
                  context,
                  'İlk deneme doğruluğu',
                  view.firstAttemptAccuracyLabel,
                  unavailable: view.firstAttemptAccuracyUnavailable,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SessionCompositionDonut(
              eligible: view.eligibleSessions,
              completed: view.completedSessions,
              interrupted: view.interruptedSessions,
              inProgress: view.inProgressSessions,
              abandoned: view.abandonedSessions,
            ),
            const SizedBox(height: 16),
            Text('Oyun süresi dağılımı', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (view.activityRows.isEmpty)
              Text(
                'Bu dönemde etkinlik bazlı oyun süresi kaydı yok.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              _activityChart(context, view),
            const SizedBox(height: 12),
            Text('Pencere: ${view.windowLabel}', style: Theme.of(context).textTheme.bodySmall),
            Text(
              'Tazelik: ${view.freshnessLabel} · Bütünlük: ${view.completenessLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(view.sampleLabel, style: Theme.of(context).textTheme.bodySmall),
            if (view.isStale)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ParentFeedbackBanner(
                  kind: ParentFeedbackKind.warning,
                  title: 'Güncellik uyarısı',
                  message: 'Veriler güncel olmayabilir.',
                ),
              ),
            if (view.isPartial)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ParentFeedbackBanner(
                  kind: ParentFeedbackKind.warning,
                  title: 'Kısmi veri',
                  message: 'Veri seti kısmi olabilir.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activityChart(BuildContext context, ParentDashboardViewData view) {
    final maxSeconds = view.maxActivityPlaySeconds;
    final trackColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final fillColor = Theme.of(context).colorScheme.primary;
    return KeyedSubtree(
      key: ParentDashboardSurface.activityChartKey,
      child: Semantics(
        label: 'Etkinlik oyun süresi dağılımı',
        child: Column(
          children: [
            for (final row in view.activityRows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(row.activityId, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    _activityDurationBar(
                      seconds: row.playDurationSeconds,
                      maxSeconds: maxSeconds,
                      trackColor: trackColor,
                      fillColor: fillColor,
                    ),
                    Text(
                      '${row.sessionCount} oturum · ${row.playDurationLabel}',
                      key: Key('activity-chart-meta-${row.activityId}'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activityDurationBar({
    required int seconds,
    required int maxSeconds,
    required Color trackColor,
    required Color fillColor,
  }) {
    if (maxSeconds <= 0) {
      return Container(
        key: const Key('activity-chart-zero-track'),
        height: 10,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    if (seconds <= 0) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          flex: seconds,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        if (maxSeconds > seconds)
          Expanded(
            flex: maxSeconds - seconds,
            child: const SizedBox(height: 10),
          ),
      ],
    );
  }

  Widget _childProfileSwitcher(
    BuildContext context, {
    bool allowSingleSelect = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final children = widget.profiles.children;
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedId = widget.profiles.selectedId;
    final value = children.any((child) => child.childId == selectedId)
        ? selectedId
        : null;
    final loading = _controller.phase == ParentDashboardPhase.loading ||
        (_controller.phase == ParentDashboardPhase.initial && !allowSingleSelect);
    final canSwitch = !loading &&
        (children.length > 1 || (allowSingleSelect && children.isNotEmpty));

    return Semantics(
      key: ParentDashboardSurface.childSwitcherKey,
      label: l10n.parentDashboardChildSelectorLabel,
      hint: l10n.parentDashboardChildSelectorHint,
      child: DropdownButtonFormField<String>(
        key: ValueKey('parent-dashboard-child-switcher-field-$selectedId'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.parentDashboardChildSelectorLabel,
        ),
        items: [
          for (final child in children)
            DropdownMenuItem<String>(
              value: child.childId,
              key: Key('parent-dashboard-child-option-${child.childId}'),
              child: Text(child.nickname ?? child.childId),
            ),
        ],
        onChanged: canSwitch
            ? (next) {
                if (next == null || next == widget.profiles.selectedId) return;
                widget.profiles.select(next);
              }
            : null,
      ),
    );
  }

  Widget _metricTile(
    BuildContext context,
    String label,
    String value, {
    bool unavailable = false,
    bool emphasized = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasized ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontStyle: unavailable ? FontStyle.italic : null,
                ),
          ),
        ],
      ),
    );
  }

}

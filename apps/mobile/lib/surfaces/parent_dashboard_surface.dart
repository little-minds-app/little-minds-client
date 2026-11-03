import 'package:flutter/material.dart';

import '../child_profiles/child_profiles_controller.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../parent_dashboard/mission_status_repository.dart';
import '../parent_dashboard/mission_status_view_data.dart';
import '../parent_dashboard/parent_dashboard_controller.dart';
import '../parent_dashboard/session_kpi_repository.dart';
import '../shell/adaptive_shell.dart';
import '../auth/parent_auth_controller.dart';

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
            animation: _controller,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _controller.failure?.userMessage ?? 'Veriler yüklenemedi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: ParentDashboardSurface.kpiRetryKey,
                  onPressed: () => _controller.refresh(),
                  child: const Text('Yeniden dene'),
                ),
              ],
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

  bool get _showOverviewWithKpiFailure {
    final missionReady = _controller.missionPhase == MissionStatusPhase.loaded ||
        _controller.missionPhase == MissionStatusPhase.empty;
    final kpiFailed = switch (_controller.phase) {
      ParentDashboardPhase.error ||
      ParentDashboardPhase.unauthorized ||
      ParentDashboardPhase.childNotFound =>
        true,
      _ => false,
    };
    return missionReady && kpiFailed;
  }

  Widget _overview(BuildContext context, {required bool empty, bool kpiFailed = false}) {
    final view = _controller.view;
    final selected = widget.profiles.selected;
    return SingleChildScrollView(
      key: empty ? ParentDashboardSurface.emptyKey : ParentDashboardSurface.contentKey,
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selected != null)
                Text(
                  'Profil: ${selected.nickname}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              const SizedBox(height: 8),
              if (kpiFailed)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          key: ParentDashboardSurface.kpiErrorKey,
                          _controller.failure?.userMessage ??
                              'Oturum özeti yüklenemedi.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: ParentDashboardSurface.kpiRetryKey,
                          onPressed: () => _controller.refresh(),
                          child: const Text('Oturum özetini yeniden dene'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (empty)
                const Text(
                  'Bu pencerede uygun oturum bulunamadı.',
                  textAlign: TextAlign.center,
                )
              else if (view != null) ...[
                _metricRow('Uygun oturum', '${view.eligibleSessions}'),
                _metricRow('Tamamlanan', '${view.completedSessions}'),
                _metricRow('Yarıda kalan', '${view.interruptedSessions}'),
                _metricRow('Devam eden', '${view.inProgressSessions}'),
                _metricRow('Toplam oyun süresi', view.totalPlayDurationLabel),
                _metricRow(
                  'Tamamlanma oranı',
                  view.completedRateLabel,
                  unavailable: view.completedRateUnavailable,
                ),
                _metricRow('Farklı oyun günü', '${view.distinctPlayDays}'),
                _metricRow(
                  'İlk deneme doğruluğu',
                  view.firstAttemptAccuracyLabel,
                  unavailable: view.firstAttemptAccuracyUnavailable,
                ),
                const SizedBox(height: 12),
                Text(
                  'Pencere: ${view.windowLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Tazelik: ${view.freshnessLabel} · Bütünlük: ${view.completenessLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  view.sampleLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (view.isStale)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Veriler güncel olmayabilir.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.orange.shade800,
                          ),
                    ),
                  ),
                if (view.isPartial)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Veri seti kısmi olabilir.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (view.activityRows.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Etkinlik özeti',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final row in view.activityRows)
                    ListTile(
                      dense: true,
                      title: Text(row.activityId),
                      subtitle: Text(
                        '${row.sessionCount} oturum · ${row.playDurationLabel}',
                      ),
                    ),
                ],
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

  Widget _metricRow(String label, String value, {bool unavailable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: unavailable ? const TextStyle(fontStyle: FontStyle.italic) : null,
            ),
          ),
        ],
      ),
    );
  }
}

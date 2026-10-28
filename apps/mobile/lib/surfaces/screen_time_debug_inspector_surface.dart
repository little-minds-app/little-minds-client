import 'package:flutter/material.dart';

import '../config/scaffolding_assumptions.dart';
import '../l10n/app_localizations.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../screen_time/screen_time.dart';
import '../shell/adaptive_shell.dart';

/// Debug-only live screen-time inspector + iPad/phone QA controls (LMP-49 3.2).
///
/// Parent Settings path only — never Hub / Mentor / child surfaces. Outside
/// Kids Mode counting. Hidden unless [kDebugMode] or [forceShowForTest].
class ScreenTimeDebugInspectorSurface extends StatefulWidget {
  const ScreenTimeDebugInspectorSurface({
    super.key,
    required this.coordinator,
    this.onBack,
    this.forceShowForTest = false,
    this.mutationsAllowed,
  });

  final ScreenTimeCoordinator coordinator;
  final VoidCallback? onBack;

  /// Widget tests run in debug; still allow forcing the surface contract.
  final bool forceShowForTest;

  /// Injectable runtime guard for unit/widget tests of release refusal.
  final bool Function()? mutationsAllowed;

  static const Key surfaceKey = Key('surface-screen-time-debug-inspector');
  static const Key debugOnlyBannerKey = Key('st-debug-only-banner');
  static const Key budgetSectionKey = Key('st-debug-section-budget');
  static const Key lifecycleSectionKey = Key('st-debug-section-lifecycle');
  static const Key trustSectionKey = Key('st-debug-section-trust');
  static const Key qaSectionKey = Key('st-debug-section-qa');
  static const Key fieldTableKey = Key('st-debug-field-table');
  static const Key qaNearCapKey = Key('st-debug-qa-near-cap');
  static const Key qaAtCapKey = Key('st-debug-qa-at-cap');
  static const Key qaResetKey = Key('st-debug-qa-reset');
  static const Key qaReloadKey = Key('st-debug-qa-reload');
  static const Key qaPersistKey = Key('st-debug-qa-persist');
  static const Key qaResetConfirmDialogKey = Key('st-debug-qa-reset-confirm');
  static const Key qaStatusKey = Key('st-debug-qa-status');
  static const Key scrollKey = Key('st-debug-inspector-scroll');

  @override
  State<ScreenTimeDebugInspectorSurface> createState() =>
      _ScreenTimeDebugInspectorSurfaceState();
}

class _ScreenTimeDebugInspectorSurfaceState
    extends State<ScreenTimeDebugInspectorSurface> {
  late final ScreenTimeDebugQa _qa;
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _qa = ScreenTimeDebugQa(
      widget.coordinator,
      mutationsAllowed: widget.mutationsAllowed,
    );
    widget.coordinator.addListener(_onCoordinatorChanged);
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onCoordinatorChanged);
    super.dispose();
  }

  void _onCoordinatorChanged() {
    if (mounted) setState(() {});
  }

  bool get _allowed =>
      ScreenTimeDebugQa.showEntry(forceShowEntryForTest: widget.forceShowForTest);

  /// Local + coordinator busy — disable conflicting QA while a chain op runs.
  bool get _qaEnabled => !_busy && !_qa.isBusy;

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    if (!_qaEnabled) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _status = okMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: ScreenTimeDebugInspectorSurface.qaResetConfirmDialogKey,
          title: Text(l10n.screenTimeDebugResetConfirmTitle),
          content: Text(l10n.screenTimeDebugResetConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.screenTimeDebugResetCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.screenTimeDebugResetConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _run(_qa.resetBudget, l10n.screenTimeDebugStatusReset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= ScaffoldingBreakpoints.expandedMinWidth;
    final maxContentWidth = isTablet ? 720.0 : 520.0;

    return OrientationBinder(
      surface: AppSurface.parentSettings,
      child: AdaptiveShell(
        title: l10n.screenTimeDebugTitle,
        actions: [
          TextButton(
            key: const Key('nav-back-from-st-debug'),
            onPressed: widget.onBack,
            child: Text(l10n.screenTimeDebugBack),
          ),
        ],
        body: KeyedSubtree(
          key: ScreenTimeDebugInspectorSurface.surfaceKey,
          child: !_allowed
              ? Center(child: Text(l10n.screenTimeDebugUnavailable))
              : ListenableBuilder(
                  listenable: widget.coordinator,
                  builder: (context, _) {
                    final c = widget.coordinator;
                    final a = c.accountant;
                    return SingleChildScrollView(
                      key: ScreenTimeDebugInspectorSurface.scrollKey,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 32 : 24,
                        vertical: 24,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContentWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Material(
                                key: ScreenTimeDebugInspectorSurface
                                    .debugOnlyBannerKey,
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    l10n.screenTimeDebugOnlyBanner,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Section(
                                key: ScreenTimeDebugInspectorSurface
                                    .budgetSectionKey,
                                title: l10n.screenTimeDebugSectionBudget,
                                child: _FieldTable(
                                  key: ScreenTimeDebugInspectorSurface
                                      .fieldTableKey,
                                  rows: [
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldDayKey,
                                      a.isRestored ? a.dayKey : '—',
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldAccumulated,
                                      _fmtSeconds(a.accumulatedActiveSeconds),
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldRemaining,
                                      _fmtSeconds(c.remainingSeconds),
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldCap,
                                      _fmtSeconds(a.policy.dailyCapSeconds),
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldCapReached,
                                      c.isCapReached.toString(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Section(
                                key: ScreenTimeDebugInspectorSurface
                                    .lifecycleSectionKey,
                                title: l10n.screenTimeDebugSectionLifecycle,
                                child: _FieldTable(
                                  rows: [
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldKidsMode,
                                      c.kidsModeShellActive.toString(),
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldCounting,
                                      c.isCounting.toString(),
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldForeground,
                                      c.isAppForeground.toString(),
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldGameplayPhase,
                                      c.gameplayPhase?.name ?? 'null',
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldInitialized,
                                      c.isInitialized.toString(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Section(
                                key: ScreenTimeDebugInspectorSurface
                                    .trustSectionKey,
                                title: l10n.screenTimeDebugSectionTrust,
                                child: _FieldTable(
                                  rows: [
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldTrustState,
                                      a.isRestored
                                          ? a.trustState.wireName
                                          : '—',
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldClockSkew,
                                      a.isRestored
                                          ? a.clockSkewDetected.toString()
                                          : '—',
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldCorrupt,
                                      a.isRestored
                                          ? a.isCorruptPersistence.toString()
                                          : '—',
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldStorageFailed,
                                      c.storageFailed.toString(),
                                    ),
                                    _FieldRow(
                                      l10n.screenTimeDebugFieldAllowsPlay,
                                      c.allowsChildPlay.toString(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Section(
                                key: ScreenTimeDebugInspectorSurface
                                    .qaSectionKey,
                                title: l10n.screenTimeDebugSectionQa,
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _QaButton(
                                      key: ScreenTimeDebugInspectorSurface
                                          .qaNearCapKey,
                                      label: l10n.screenTimeDebugQaNearCap,
                                      enabled: _qaEnabled,
                                      onPressed: () => _run(
                                        _qa.setNearCap,
                                        l10n.screenTimeDebugStatusNearCap,
                                      ),
                                    ),
                                    _QaButton(
                                      key: ScreenTimeDebugInspectorSurface
                                          .qaAtCapKey,
                                      label: l10n.screenTimeDebugQaAtCap,
                                      enabled: _qaEnabled,
                                      onPressed: () => _run(
                                        _qa.setAtCap,
                                        l10n.screenTimeDebugStatusAtCap,
                                      ),
                                    ),
                                    _QaButton(
                                      key: ScreenTimeDebugInspectorSurface
                                          .qaResetKey,
                                      label: l10n.screenTimeDebugQaReset,
                                      enabled: _qaEnabled,
                                      onPressed: () => _confirmReset(l10n),
                                    ),
                                    _QaButton(
                                      key: ScreenTimeDebugInspectorSurface
                                          .qaReloadKey,
                                      label: l10n.screenTimeDebugQaReload,
                                      enabled: _qaEnabled,
                                      onPressed: () => _run(
                                        _qa.reloadFromStore,
                                        l10n.screenTimeDebugStatusReload,
                                      ),
                                    ),
                                    _QaButton(
                                      key: ScreenTimeDebugInspectorSurface
                                          .qaPersistKey,
                                      label: l10n.screenTimeDebugQaPersist,
                                      enabled: _qaEnabled,
                                      onPressed: () => _run(
                                        _qa.persistNow,
                                        l10n.screenTimeDebugStatusPersist,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_status != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  key: ScreenTimeDebugInspectorSurface
                                      .qaStatusKey,
                                  _status!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  static String _fmtSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')} ($seconds s)';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _FieldRow {
  const _FieldRow(this.label, this.value);
  final String label;
  final String value;
}

class _FieldTable extends StatelessWidget {
  const _FieldTable({super.key, required this.rows});

  final List<_FieldRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.8),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(row.label, style: theme.textTheme.bodyMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  row.value,
                  key: Key('st-debug-value-${row.label}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _QaButton extends StatelessWidget {
  const _QaButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 160),
      child: FilledButton.tonal(
        onPressed: enabled ? onPressed : null,
        child: Text(label),
      ),
    );
  }
}

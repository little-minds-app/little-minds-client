import 'package:flutter/foundation.dart';

import 'screen_time_accountant.dart';
import 'screen_time_coordinator.dart';
import 'trust_recovery.dart';

/// Debug/QA-only mutations for the screen-time inspector (LMP-49 Step 3.2–3.4).
///
/// ## Guards
/// - **Compile / UI:** Parent Settings entry and inspector route are wrapped in
///   [kDebugMode] (and optional [forceShowEntryForTest]).
/// - **Runtime dual-gate:** [screenTimeDebugMutationsPermitted] —
///   `kDebugMode && (mutationsAllowed?.call() ?? true)`. Release builds refuse
///   even if a caller injects `mutationsAllowed: () => true`.
/// - **Lowest boundary:** [ScreenTimeAccountant.applyDebugQaAccumulatedSeconds]
///   and coordinator debug entry points enforce the same dual-gate independently.
///
/// ## Serialization
/// Apply / reload / persist go through [ScreenTimeCoordinator]'s `_persistChain`
/// so a delayed store cannot interleave a stale restore with a newer write.
///
/// ## Non-goals
/// - Not a production parent control surface / no alt production route.
/// - [setNearCap] / [setAtCap] do **not** recover trust or clear corrupt evidence.
/// - [resetBudget] is the sole debug path that may recover via
///   [TrustRecovery.forceNewLocalDay] (still dual-gated; not a child surface).
/// - Does not expose prefs keys.
final class ScreenTimeDebugQa {
  ScreenTimeDebugQa(
    this._coordinator, {
    this.mutationsAllowed,
  });

  /// Used seconds for “set 29:50” — 10 seconds of remaining on a 30m cap.
  static const int nearCapUsedSeconds = (29 * 60) + 50;

  /// Used seconds for “set 30:00” — daily cap exhausted.
  static const int atCapUsedSeconds = 30 * 60;

  /// UI entry visibility: debug builds, or widget tests that force the entry.
  static bool showEntry({bool forceShowEntryForTest = false}) =>
      kDebugMode || forceShowEntryForTest;

  final ScreenTimeCoordinator _coordinator;

  /// Optional injectable allow flag (ANDed with [kDebugMode]).
  final bool Function()? mutationsAllowed;

  ScreenTimeCoordinator get coordinator => _coordinator;

  /// True while a serialized QA op is in flight (disable conflicting controls).
  bool get isBusy => _coordinator.isDebugQaBusy;

  void _ensureDebug() {
    if (!screenTimeDebugMutationsPermitted(
      mutationsAllowed: mutationsAllowed,
    )) {
      throw UnsupportedError(
        'Screen-time debug QA mutations are debug-only',
      );
    }
    if (_coordinator.isDisposed || _coordinator.isShuttingDown) {
      throw StateError('ScreenTimeCoordinator is unavailable');
    }
  }

  void _ensureMutableTrust() {
    final accountant = _coordinator.accountant;
    if (_coordinator.storageFailed ||
        accountant.isCorruptPersistence ||
        accountant.isTrustDegraded) {
      throw StateError(
        'Debug QA refuses budget mutation while persistence/trust is fail-closed',
      );
    }
  }

  /// Set accumulated used time to 29:50 (remaining ≈ 10s on default policy).
  Future<void> setNearCap() => _applyUsed(nearCapUsedSeconds);

  /// Set accumulated used time to 30:00 (cap reached).
  Future<void> setAtCap() => _applyUsed(atCapUsedSeconds);

  /// Reset used time / unblock Kids Mode for the current local wall day.
  ///
  /// Debug/QA only — not a production parent reset API. When trust is already
  /// trusted, zeros accumulated seconds. When trust is degraded/corrupt
  /// (e.g. cross-day restart → uncertain + clockSkew), recovers via
  /// [TrustRecovery.forceNewLocalDay] so UAT Reset Budget can restore play.
  Future<void> resetBudget() async {
    _ensureDebug();
    if (_coordinator.storageFailed) {
      throw StateError(
        'Debug QA refuses budget reset while storage is fail-closed',
      );
    }
    // Parent-path inspector: stop Kids Mode counting before rewriting budget.
    if (_coordinator.kidsModeShellActive) {
      _coordinator.setKidsModeShellActive(false);
    }
    await _coordinator.debugResetBudgetForQa(
      mutationsAllowed: mutationsAllowed,
    );
  }

  Future<void> _applyUsed(int usedSeconds) async {
    _ensureDebug();
    _ensureMutableTrust();
    // Parent-path inspector: stop Kids Mode counting before rewriting budget.
    if (_coordinator.kidsModeShellActive) {
      _coordinator.setKidsModeShellActive(false);
    }
    await _coordinator.debugApplyQaAccumulatedSeconds(
      usedSeconds,
      mutationsAllowed: mutationsAllowed,
    );
  }

  /// Re-read durable snapshot on the serialized persist chain (no stale restore).
  Future<void> reloadFromStore() async {
    _ensureDebug();
    if (_coordinator.kidsModeShellActive) {
      _coordinator.setKidsModeShellActive(false);
    }
    await _coordinator.debugReloadAccountantForQa(
      mutationsAllowed: mutationsAllowed,
    );
  }

  /// Enqueue a serialized persist of the current in-memory checkpoint.
  Future<void> persistNow() async {
    _ensureDebug();
    await _coordinator.debugPersistForQa(
      mutationsAllowed: mutationsAllowed,
    );
  }
}

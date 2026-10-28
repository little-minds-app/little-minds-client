import 'package:flutter/foundation.dart';

import 'screen_time_coordinator.dart';

/// Debug/QA-only mutations for the screen-time inspector (LMP-49 Step 3.2).
///
/// ## Guards
/// - **Compile / UI:** Parent Settings entry and inspector route are wrapped in
///   [kDebugMode] (and optional [forceShowEntryForTest]).
/// - **Runtime:** every mutation calls [_ensureDebug] and throws outside debug
///   (or when [mutationsAllowed] returns false in tests).
///
/// ## Non-goals
/// - Not a production parent control surface.
/// - Does **not** recover trust, clear corrupt evidence, or expose prefs keys.
/// - Persist goes through [ScreenTimeCoordinator.persist] (serialized chain).
final class ScreenTimeDebugQa {
  ScreenTimeDebugQa(
    this._coordinator, {
    bool Function()? mutationsAllowed,
  }) : _mutationsAllowed = mutationsAllowed ?? (() => kDebugMode);

  /// Used seconds for “set 29:50” — 10 seconds of remaining on a 30m cap.
  static const int nearCapUsedSeconds = (29 * 60) + 50;

  /// Used seconds for “set 30:00” — daily cap exhausted.
  static const int atCapUsedSeconds = 30 * 60;

  /// UI entry visibility: debug builds, or widget tests that force the entry.
  static bool showEntry({bool forceShowEntryForTest = false}) =>
      kDebugMode || forceShowEntryForTest;

  final ScreenTimeCoordinator _coordinator;
  final bool Function() _mutationsAllowed;

  ScreenTimeCoordinator get coordinator => _coordinator;

  void _ensureDebug() {
    if (!_mutationsAllowed()) {
      throw UnsupportedError(
        'Screen-time debug QA mutations are debug-only',
      );
    }
    if (_coordinator.isDisposed || _coordinator.isShuttingDown) {
      throw StateError('ScreenTimeCoordinator is unavailable');
    }
  }

  /// Set accumulated used time to 29:50 (remaining ≈ 10s on default policy).
  Future<void> setNearCap() => _applyUsed(nearCapUsedSeconds);

  /// Set accumulated used time to 30:00 (cap reached).
  Future<void> setAtCap() => _applyUsed(atCapUsedSeconds);

  /// Reset used time to 0 for the current local day (trusted path only).
  Future<void> resetBudget() => _applyUsed(0);

  Future<void> _applyUsed(int usedSeconds) async {
    _ensureDebug();
    final accountant = _coordinator.accountant;
    if (accountant.isCorruptPersistence || _coordinator.storageFailed) {
      throw StateError(
        'Debug QA refuses budget mutation while storage/trust is fail-closed',
      );
    }
    // Parent-path inspector: stop Kids Mode counting before rewriting budget.
    if (_coordinator.kidsModeShellActive) {
      _coordinator.setKidsModeShellActive(false);
    }
    accountant.applyDebugQaAccumulatedSeconds(usedSeconds);
    await _coordinator.persist();
    // Keep UI listeners in sync after an out-of-band accountant write.
    _coordinator.debugNotifyListenersForQa();
  }

  /// Re-read durable snapshot (same store) without inventing a fresh day.
  Future<void> reloadFromStore() async {
    _ensureDebug();
    if (_coordinator.kidsModeShellActive) {
      _coordinator.setKidsModeShellActive(false);
    }
    await _coordinator.debugReloadAccountantForQa();
  }

  /// Enqueue a serialized persist of the current in-memory checkpoint.
  Future<void> persistNow() async {
    _ensureDebug();
    await _coordinator.persist();
  }
}

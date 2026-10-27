/// Local screen-time accounting core (LMP-49 Step 1 / F-010 / ADR-016 §35.3).
///
/// Pure Dart SSoT for daily Kids Mode active seconds. No UI, Flame, navigation,
/// Hub, Healthy Ending, backend, or audio wiring in this library.
///
/// **Not tamper-proof offline** — see [ScreenTimeAccountant] dartdoc.
library;

export 'daily_policy.dart';
export 'monotonic_clock.dart';
export 'persistent_store.dart';
export 'screen_time_accountant.dart';
export 'screen_time_snapshot.dart';
export 'snapshot_load_result.dart';
export 'trust_recovery.dart';
export 'trust_state.dart';
export 'wall_clock.dart';

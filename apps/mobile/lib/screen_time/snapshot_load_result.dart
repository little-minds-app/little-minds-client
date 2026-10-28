import 'screen_time_snapshot.dart';

/// Outcome of reading the durable snapshot key.
///
/// Distinguishes **missing** (legitimate first run) from **present-but-invalid**
/// (corrupt / incomplete). Invalid MUST NOT be treated as a silent fresh day.
enum SnapshotPresence {
  /// Key absent or empty — first run / cleared store.
  missing,

  /// Key present and decoded to a valid [ScreenTimeSnapshot].
  valid,

  /// Key present but JSON/schema invalid — fail closed.
  invalid,
}

/// Typed load result for [ScreenTimeSnapshot.storeKey].
final class SnapshotLoadResult {
  const SnapshotLoadResult._({
    required this.presence,
    this.snapshot,
    this.raw,
  });

  const SnapshotLoadResult.missing()
      : this._(presence: SnapshotPresence.missing);

  const SnapshotLoadResult.valid(ScreenTimeSnapshot snapshot)
      : this._(presence: SnapshotPresence.valid, snapshot: snapshot);

  const SnapshotLoadResult.invalid(String raw)
      : this._(presence: SnapshotPresence.invalid, raw: raw);

  final SnapshotPresence presence;
  final ScreenTimeSnapshot? snapshot;

  /// Original bytes when [presence] is [SnapshotPresence.invalid].
  final String? raw;

  bool get isMissing => presence == SnapshotPresence.missing;
  bool get isValid => presence == SnapshotPresence.valid;
  bool get isInvalid => presence == SnapshotPresence.invalid;
}

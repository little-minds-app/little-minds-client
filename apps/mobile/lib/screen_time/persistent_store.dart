/// Minimal key-value persistence port for screen-time snapshots.
///
/// Production uses [SharedPreferencesPersistentStore]. [InMemoryPersistentStore]
/// is **test-only**. [FailClosedPersistentStore] is used when platform storage
/// cannot open — callers must not treat that as a silent first-run empty day.
///
/// **Offline / tamper limits:** any on-device store can be cleared or edited by
/// a determined user. Local persistence is **not** tamper-proof; quality flags
/// and later server reconciliation (ADR-016) are required for stronger trust.
abstract class PersistentStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Throws on every operation — fail-closed stand-in when storage is unavailable.
final class FailClosedPersistentStore implements PersistentStore {
  const FailClosedPersistentStore([
    this.message = 'screen-time persistent store unavailable',
  ]);

  final String message;

  Never _fail() => throw StateError(message);

  @override
  Future<String?> read(String key) async => _fail();

  @override
  Future<void> write(String key, String value) async => _fail();

  @override
  Future<void> delete(String key) async => _fail();
}

/// In-memory [PersistentStore] for deterministic tests.
final class InMemoryPersistentStore implements PersistentStore {
  InMemoryPersistentStore([Map<String, String>? seed])
      : _data = Map<String, String>.from(seed ?? const {});

  final Map<String, String> _data;

  Map<String, String> get debugView => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  void seed(String key, String value) => _data[key] = value;

  void corrupt(String key, String value) => _data[key] = value;

  void clear() => _data.clear();
}

import 'package:shared_preferences/shared_preferences.dart';

import 'persistent_store.dart';

/// Production [PersistentStore] backed by [SharedPreferences].
///
/// Missing keys return `null` (first-run). Read/write I/O failures throw —
/// callers ([ScreenTimeCoordinator]) must fail closed and must **not** treat
/// errors as a silent fresh day. Not tamper-proof (ADR-016).
final class SharedPreferencesPersistentStore implements PersistentStore {
  SharedPreferencesPersistentStore(this._prefs);

  final SharedPreferences _prefs;

  /// Opens platform prefs. On failure, returns [FailClosedPersistentStore] so
  /// restore cannot be mistaken for an empty first-run.
  static Future<PersistentStore> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SharedPreferencesPersistentStore(prefs);
    } catch (_) {
      return const FailClosedPersistentStore();
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return _prefs.getString(key);
    } catch (error, stack) {
      Error.throwWithStackTrace(
        StateError('screen-time prefs read failed: $error'),
        stack,
      );
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      final ok = await _prefs.setString(key, value);
      if (!ok) {
        throw StateError('screen-time prefs write returned false for $key');
      }
    } catch (error, stack) {
      Error.throwWithStackTrace(
        StateError('screen-time prefs write failed: $error'),
        stack,
      );
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _prefs.remove(key);
    } catch (error, stack) {
      Error.throwWithStackTrace(
        StateError('screen-time prefs delete failed: $error'),
        stack,
      );
    }
  }
}

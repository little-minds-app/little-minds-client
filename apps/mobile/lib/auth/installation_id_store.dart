import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Installation identity is an untrusted correlation hint, not authorization.
/// It must survive logout so different parent accounts use the same installation.
abstract class InstallationIdStore {
  Future<String> getOrCreate();
}

final class SecureInstallationIdStore implements InstallationIdStore {
  SecureInstallationIdStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static const _key = 'little_minds_installation_id_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && Uuid.isValidUUID(fromString: existing)) {
      return existing;
    }
    final id = const Uuid().v4();
    await _storage.write(key: _key, value: id);
    return id;
  }
}

final class MemoryInstallationIdStore implements InstallationIdStore {
  MemoryInstallationIdStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final Uuid _uuid;
  String? _id;

  @override
  Future<String> getOrCreate() async => _id ??= _uuid.v4();
}

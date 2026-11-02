import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Authenticated encryption of queued event payloads. The encryption key is
/// stored in the platform Keychain/Keystore, never alongside outbox records.
abstract class ActivityPayloadCodec {
  Future<String> seal(String parentId, Map<String, dynamic> plain);
  Future<Map<String, dynamic>> open(String parentId, String encoded);
  Future<void> forgetParent(String parentId);
}

class SecureActivityPayloadCodec implements ActivityPayloadCodec {
  SecureActivityPayloadCodec({FlutterSecureStorage? storage,
      Future<SecretKey> Function(String)? testKeyProvider})
      : _testKeyProvider = testKeyProvider,
        _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final FlutterSecureStorage _storage;
  final Future<SecretKey> Function(String)? _testKeyProvider;
  final AesGcm _cipher = AesGcm.with256bits();
  final _random = Random.secure();
  static const _prefix = 'lm_activity_outbox_key_v1_';

  Future<SecretKey> _key(String parentId) async {
    if (_testKeyProvider != null) return _testKeyProvider(parentId);
    final keyName = '$_prefix$parentId';
    final stored = await _storage.read(key: keyName);
    if (stored != null) {
      final bytes = base64Decode(stored);
      if (bytes.length != 32) throw StateError('outbox.key_invalid');
      return SecretKey(bytes);
    }
    // The caller's account-partition queue serializes local writes. A unique
    // secure key is created on first use and persisted before any ciphertext.
    final bytes = Uint8List.fromList(
        List<int>.generate(32, (_) => _random.nextInt(256)));
    await _storage.write(key: keyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }

  @override
  Future<void> forgetParent(String parentId) async {
    if (_testKeyProvider != null) return;
    await _storage.delete(key: '$_prefix$parentId');
  }

  @override
  Future<String> seal(String parentId, Map<String, dynamic> plain) async {
    final nonce = Uint8List.fromList(
        List<int>.generate(12, (_) => _random.nextInt(256)));
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(plain)),
      secretKey: await _key(parentId),
      nonce: nonce,
      aad: utf8.encode('little-minds-outbox-v1:$parentId'),
    );
    return jsonEncode({
      'v': 1,
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    });
  }

  @override
  Future<Map<String, dynamic>> open(String parentId, String encoded) async {
    final envelope = jsonDecode(encoded);
    if (envelope is! Map<String, dynamic> || envelope['v'] != 1) {
      throw const FormatException('outbox.invalid_ciphertext_envelope');
    }
    final box = SecretBox(
      base64Decode(envelope['c'] as String),
      nonce: base64Decode(envelope['n'] as String),
      mac: Mac(base64Decode(envelope['m'] as String)),
    );
    final bytes = await _cipher.decrypt(box,
      secretKey: await _key(parentId),
      aad: utf8.encode('little-minds-outbox-v1:$parentId'));
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}

/// Unit-test adapter; never use for production, and never imports platform keys.
class TestPlainActivityPayloadCodec implements ActivityPayloadCodec {
  const TestPlainActivityPayloadCodec();
  @override
  Future<void> forgetParent(String parentId) async {}
  @override
  Future<String> seal(String parentId, Map<String, dynamic> plain) async =>
      jsonEncode(plain);
  @override
  Future<Map<String, dynamic>> open(String parentId, String encoded) async =>
      jsonDecode(encoded) as Map<String, dynamic>;
}

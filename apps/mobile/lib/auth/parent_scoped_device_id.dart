import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Matches backend `scopedDeviceId` (session-issuer.service.ts).
String parentScopedDeviceId(String installationId, String parentId) {
  final digest = sha256.convert(
    utf8.encode('little-minds/parent-device/v1:$installationId:$parentId'),
  );
  final hash = List<int>.from(digest.bytes.sublist(0, 16));
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  final h = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

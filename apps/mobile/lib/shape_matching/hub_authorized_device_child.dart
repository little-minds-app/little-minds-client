/// Server-mirrored `devices.child_id` for a parent-scoped installation device row.
abstract class HubAuthorizedDeviceChildCatalog {
  Future<String?> authorizedChildId({
    required String parentId,
    required String scopedDeviceId,
  });

  Future<void> applyServerAuthorizedChild({
    required String parentId,
    required String scopedDeviceId,
    required String? childId,
  });

  Future<void> clearParent(String parentId);
}

/// In-memory mirror; cleared on logout per parent. Does not touch outbox partitions.
final class MemoryHubAuthorizedDeviceChildCatalog
    implements HubAuthorizedDeviceChildCatalog {
  final Map<String, String> _byKey = {};

  static String _key(String parentId, String scopedDeviceId) =>
      '${parentId.toLowerCase()}:${scopedDeviceId.toLowerCase()}';

  @override
  Future<String?> authorizedChildId({
    required String parentId,
    required String scopedDeviceId,
  }) async =>
      _byKey[_key(parentId, scopedDeviceId)];

  @override
  Future<void> applyServerAuthorizedChild({
    required String parentId,
    required String scopedDeviceId,
    required String? childId,
  }) async {
    final key = _key(parentId, scopedDeviceId);
    if (childId == null || childId.isEmpty) {
      _byKey.remove(key);
      return;
    }
    _byKey[key] = childId;
  }

  @override
  Future<void> clearParent(String parentId) async {
    final prefix = '${parentId.toLowerCase()}:';
    _byKey.removeWhere((key, _) => key.startsWith(prefix));
  }
}

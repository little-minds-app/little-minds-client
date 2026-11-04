import '../auth/auth_session.dart';
import 'hub_authorized_device_child.dart';

/// Result of a server-side device↔child binding attempt.
sealed class HubDeviceChildBindingResult {
  const HubDeviceChildBindingResult();
}

final class HubDeviceChildBound extends HubDeviceChildBindingResult {
  const HubDeviceChildBound(this.childId);
  final String childId;
}

final class HubDeviceChildBindingFailed extends HubDeviceChildBindingResult {
  const HubDeviceChildBindingFailed();
}

/// Binds the selected hub child to the parent-scoped device row on the server.
abstract class HubDeviceChildBindingClient {
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String scopedDeviceId,
    required String selectedChildId,
  });
}

/// Fail closed until an OpenAPI device binding route ships.
final class FailClosedHubDeviceChildBindingClient
    implements HubDeviceChildBindingClient {
  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String scopedDeviceId,
    required String selectedChildId,
  }) async =>
      const HubDeviceChildBindingFailed();
}

/// Test double — simulates a successful server bind and mirror.
final class FakeHubDeviceChildBindingClient implements HubDeviceChildBindingClient {
  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String scopedDeviceId,
    required String selectedChildId,
  }) async =>
      HubDeviceChildBound(selectedChildId);
}

/// Keeps the local catalog aligned with server-authorized `device.childId`.
final class HubDeviceChildBindingService {
  HubDeviceChildBindingService({
    required this.catalog,
    required this.client,
  });

  final HubAuthorizedDeviceChildCatalog catalog;
  final HubDeviceChildBindingClient client;

  Future<void> synchronizeSelectedChild({
    required AuthSession? session,
    required String? scopedDeviceId,
    required String? selectedChildId,
  }) async {
    if (session == null || scopedDeviceId == null || scopedDeviceId.isEmpty) {
      return;
    }
    if (selectedChildId == null || selectedChildId.isEmpty) {
      await catalog.applyServerAuthorizedChild(
        parentId: session.parentId,
        scopedDeviceId: scopedDeviceId,
        childId: null,
      );
      return;
    }
    final result = await client.bindSelectedChild(
      session: session,
      scopedDeviceId: scopedDeviceId,
      selectedChildId: selectedChildId,
    );
    switch (result) {
      case HubDeviceChildBound(:final childId):
        await catalog.applyServerAuthorizedChild(
          parentId: session.parentId,
          scopedDeviceId: scopedDeviceId,
          childId: childId,
        );
      case HubDeviceChildBindingFailed():
        break;
    }
  }

  Future<void> onParentLoggedOut(String parentId) =>
      catalog.clearParent(parentId);
}

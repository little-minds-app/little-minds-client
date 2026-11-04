import 'dart:async';

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
    required String installationId,
    required String selectedChildId,
    Future<void>? abortTrigger,
  });
}

/// Fail closed until an OpenAPI device binding route ships.
final class FailClosedHubDeviceChildBindingClient
    implements HubDeviceChildBindingClient {
  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String installationId,
    required String selectedChildId,
    Future<void>? abortTrigger,
  }) async =>
      const HubDeviceChildBindingFailed();
}

/// Test double — simulates a successful server bind and mirror.
final class FakeHubDeviceChildBindingClient implements HubDeviceChildBindingClient {
  @override
  Future<HubDeviceChildBindingResult> bindSelectedChild({
    required AuthSession session,
    required String installationId,
    required String selectedChildId,
    Future<void>? abortTrigger,
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

  int _bindGeneration = 0;
  Completer<void>? _inFlightAbort;

  Future<void> synchronizeSelectedChild({
    required AuthSession? Function() readSession,
    required String? installationId,
    required String? scopedDeviceId,
    required String? selectedChildId,
  }) async {
    final session = readSession();
    if (session == null ||
        installationId == null ||
        installationId.isEmpty ||
        scopedDeviceId == null ||
        scopedDeviceId.isEmpty) {
      return;
    }

    _inFlightAbort?.complete();
    final abort = Completer<void>();
    _inFlightAbort = abort;

    final token = ++_bindGeneration;
    final intentParentId = session.parentId;
    final intentChildId = selectedChildId;
    final intentScopedDeviceId = scopedDeviceId;

    if (intentChildId == null || intentChildId.isEmpty) {
      if (!_stillLatestBind(token, readSession, intentParentId)) {
        return;
      }
      await catalog.applyServerAuthorizedChild(
        parentId: intentParentId,
        scopedDeviceId: intentScopedDeviceId,
        childId: null,
      );
      return;
    }

    final result = await client.bindSelectedChild(
      session: session,
      installationId: installationId,
      selectedChildId: intentChildId,
      abortTrigger: abort.future,
    );

    if (!_stillLatestBind(token, readSession, intentParentId)) {
      return;
    }

    switch (result) {
      case HubDeviceChildBound(:final childId):
        if (childId != intentChildId) {
          break;
        }
        await catalog.applyServerAuthorizedChild(
          parentId: intentParentId,
          scopedDeviceId: intentScopedDeviceId,
          childId: childId,
        );
      case HubDeviceChildBindingFailed():
        break;
    }
  }

  bool _stillLatestBind(
    int token,
    AuthSession? Function() readSession,
    String intentParentId,
  ) {
    if (token != _bindGeneration) {
      return false;
    }
    final sessionAfter = readSession();
    if (sessionAfter == null || sessionAfter.parentId != intentParentId) {
      return false;
    }
    return true;
  }

  Future<void> onParentLoggedOut(String parentId) =>
      catalog.clearParent(parentId);
}

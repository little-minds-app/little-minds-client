// ignore_for_file: prefer_initializing_formals

import 'package:little_minds_api/api.dart';

import '../auth/auth_api_clients.dart';
import '../auth/parent_auth_controller.dart';
import '../config/app_config.dart';
import 'session_kpi_window.dart';

/// Default page size for mission status list (bounded contract `limit`).
const missionStatusDefaultLimit = 50;

/// Fetches canonical mission status via generated [MissionsApi] only (LMP-130 / LMP-53).
class MissionStatusRepository {
  MissionStatusRepository({
    required AppConfig config,
    required ParentAuthController auth,
    AuthApiClients? clients,
    MissionsApi? missions,
    this.defaultLimit = missionStatusDefaultLimit,
  })  : _auth = auth,
        _clients = clients ?? AuthApiClients(basePath: config.apiBaseUrlString),
        _missionsOverride = missions;

  final ParentAuthController _auth;
  final AuthApiClients _clients;
  final MissionsApi? _missionsOverride;
  final int defaultLimit;

  MissionsApi get _missions => _missionsOverride ?? _clients.missions;

  Future<MissionStatusListResponse> fetch({
    required String childId,
    required SessionKpiWindow window,
    int? limit,
  }) async {
    return _authorized((api) async {
      final result = await api.listChildMissionStatus(
        childId,
        window.fromUtc,
        window.toUtcExclusive,
        limit: limit ?? defaultLimit,
      );
      if (result == null) {
        throw StateError('Invalid mission status response');
      }
      return result;
    });
  }

  Future<T> _authorized<T>(Future<T> Function(MissionsApi api) request) async {
    final session = _auth.session;
    if (session == null) throw StateError('Parent authentication required');
    _clients.setAccessToken(session.accessToken);
    try {
      return await request(_missions);
    } on ApiException catch (error) {
      if (error.code != 401) rethrow;
      if (_auth.session?.parentId != session.parentId ||
          _auth.session?.sessionId != session.sessionId) {
        throw StateError('Parent account changed');
      }
      final refreshed = await _auth.refreshForChildProfiles();
      if (refreshed == null ||
          _auth.session?.parentId != session.parentId ||
          _auth.session?.sessionId != session.sessionId) {
        throw StateError('Parent session expired or changed');
      }
      _clients.setAccessToken(refreshed);
      return request(_missions);
    }
  }
}

/// Typed failure for mission fetch paths (no token/PII in messages).
sealed class MissionStatusFailure implements Exception {
  const MissionStatusFailure(this.userMessage);
  final String userMessage;
}

final class MissionStatusUnauthorized extends MissionStatusFailure {
  const MissionStatusUnauthorized() : super('Oturum süresi doldu. Yeniden giriş yapın.');
}

final class MissionStatusChildNotFound extends MissionStatusFailure {
  const MissionStatusChildNotFound()
      : super('Seçili çocuk profili bulunamadı veya erişim yok.');
}

final class MissionStatusNetwork extends MissionStatusFailure {
  const MissionStatusNetwork([String? detail])
      : super(detail ?? 'Bağlantı hatası. Yeniden deneyin.');
}

MissionStatusFailure mapMissionStatusException(Object error) {
  if (error is ApiException) {
    if (error.code == 401) return const MissionStatusUnauthorized();
    if (error.code == 403 || error.code == 404) {
      return const MissionStatusChildNotFound();
    }
    if (error.code >= 500) {
      return const MissionStatusNetwork('Sunucu yanıt vermedi. Yeniden deneyin.');
    }
    return MissionStatusNetwork('İstek başarısız (${error.code}). Yeniden deneyin.');
  }
  if (error is StateError) {
    final message = error.message;
    if (message.contains('expired') || message.contains('authentication')) {
      return const MissionStatusUnauthorized();
    }
    if (message.contains('changed')) {
      return const MissionStatusUnauthorized();
    }
  }
  return const MissionStatusNetwork();
}

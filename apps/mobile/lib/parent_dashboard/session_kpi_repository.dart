// ignore_for_file: prefer_initializing_formals

import 'package:little_minds_api/api.dart';

import '../auth/auth_api_clients.dart';
import '../auth/parent_auth_controller.dart';
import '../config/app_config.dart';
import 'session_kpi_window.dart';

/// Fetches canonical session KPIs via generated [InsightsApi] only (LMP-52).
class SessionKpiRepository {
  SessionKpiRepository({
    required AppConfig config,
    required ParentAuthController auth,
    AuthApiClients? clients,
  })  : _auth = auth,
        _clients = clients ?? AuthApiClients(basePath: config.apiBaseUrlString);

  final ParentAuthController _auth;
  final AuthApiClients _clients;

  Future<SessionKpiResponse> fetch({
    required SessionKpiWindow window,
    String? childId,
  }) async {
    return _authorized((api) async {
      final result = await api.getSessionKpis(
        window.fromUtc,
        window.toUtcExclusive,
        window.timezone,
        childId: childId,
      );
      if (result == null) {
        throw StateError('Invalid session KPI response');
      }
      return result;
    });
  }

  Future<T> _authorized<T>(Future<T> Function(InsightsApi api) request) async {
    final session = _auth.session;
    if (session == null) throw StateError('Parent authentication required');
    _clients.setAccessToken(session.accessToken);
    try {
      return await request(_clients.insights);
    } on ApiException catch (error) {
      if (error.code != 401) rethrow;
      if (_auth.session?.parentId != session.parentId) {
        throw StateError('Parent account changed');
      }
      final refreshed = await _auth.refreshForChildProfiles();
      if (refreshed == null ||
          _auth.session?.parentId != session.parentId) {
        throw StateError('Parent session expired or changed');
      }
      _clients.setAccessToken(refreshed);
      return request(_clients.insights);
    }
  }
}

/// Typed failure for dashboard fetch paths (no token/PII in messages).
sealed class SessionKpiFailure implements Exception {
  const SessionKpiFailure(this.userMessage);
  final String userMessage;
}

final class SessionKpiUnauthorized extends SessionKpiFailure {
  const SessionKpiUnauthorized() : super('Oturum süresi doldu. Yeniden giriş yapın.');
}

final class SessionKpiChildNotFound extends SessionKpiFailure {
  const SessionKpiChildNotFound()
      : super('Seçili çocuk profili bulunamadı veya erişim yok.');
}

final class SessionKpiNetwork extends SessionKpiFailure {
  const SessionKpiNetwork([String? detail])
      : super(detail ?? 'Bağlantı hatası. Yeniden deneyin.');
}

SessionKpiFailure mapSessionKpiException(Object error) {
  if (error is ApiException) {
    if (error.code == 401) return const SessionKpiUnauthorized();
    if (error.code == 403 || error.code == 404) {
      return const SessionKpiChildNotFound();
    }
    if (error.code >= 500) {
      return const SessionKpiNetwork('Sunucu yanıt vermedi. Yeniden deneyin.');
    }
    return SessionKpiNetwork('İstek başarısız (${error.code}). Yeniden deneyin.');
  }
  if (error is StateError) {
    final message = error.message;
    if (message.contains('expired') || message.contains('authentication')) {
      return const SessionKpiUnauthorized();
    }
    if (message.contains('changed')) {
      return const SessionKpiUnauthorized();
    }
  }
  return const SessionKpiNetwork();
}

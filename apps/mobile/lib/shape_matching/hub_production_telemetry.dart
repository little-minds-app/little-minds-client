import 'package:uuid/uuid.dart';

import '../core/canonical_rfc4122_uuid.dart';
import '../auth/auth_privacy_notice.dart';
import '../auth/auth_session.dart';
import '../game/activity_registry.dart';
import '../offline/activity_event_emitter.dart';
import '../offline/activity_file_outbox.dart';
import '../offline/activity_telemetry_diagnostics.dart';
import 'hub_authorized_device_child.dart';
import 'published_content_registry.dart';
import 'shape_matching_activity.dart';
import 'shape_matching_constants.dart';
import 'shape_matching_events.dart';
import 'shape_matching_production_consent.dart';
import 'shape_matching_production_event_buffer.dart';

/// Why hub production telemetry remains on the local buffer.
enum HubProductionTelemetryBlockReason {
  noParentSession,
  noSelectedChild,
  noOutbox,
  noDeviceId,
  deviceIdNotUuid,
  deviceChildNotAuthorized,
  selectedChildMismatch,
  noPublishedContentVersion,
  contentVersionNotUuid,
}

/// Snapshot of inputs required to construct a production Shape Matching buffer.
class HubProductionTelemetrySnapshot {
  const HubProductionTelemetrySnapshot({
    required this.allowed,
    this.reason,
    this.session,
    this.deviceId,
    this.contentVersionId,
    this.playSessionId,
    this.consentPolicyVersion,
  });

  final bool allowed;
  final HubProductionTelemetryBlockReason? reason;
  final AuthSession? session;
  final String? deviceId;
  final String? contentVersionId;
  final String? playSessionId;
  final String? consentPolicyVersion;
}

/// Evaluates LMP-51 production gates for Kids Hub Shape Matching (LMP-134).
abstract final class HubProductionTelemetryGate {
  static bool isUuid(String value) => CanonicalRfc4122Uuid.isValid(value);

  static HubProductionTelemetrySnapshot evaluate({
    required AuthSession? session,
    required String? selectedChildId,
    required String? deviceId,
    required String? authorizedDeviceChildId,
    required String? publishedContentVersionId,
  }) {
    if (session == null) {
      return const HubProductionTelemetrySnapshot(
        allowed: false,
        reason: HubProductionTelemetryBlockReason.noParentSession,
      );
    }
    if (selectedChildId == null || selectedChildId.isEmpty) {
      return const HubProductionTelemetrySnapshot(
        allowed: false,
        reason: HubProductionTelemetryBlockReason.noSelectedChild,
      );
    }
    if (deviceId == null || deviceId.isEmpty) {
      return const HubProductionTelemetrySnapshot(
        allowed: false,
        reason: HubProductionTelemetryBlockReason.noDeviceId,
      );
    }
    if (!isUuid(deviceId)) {
      return HubProductionTelemetrySnapshot(
        allowed: false,
        reason: HubProductionTelemetryBlockReason.deviceIdNotUuid,
        session: session,
        deviceId: deviceId,
      );
    }
    if (authorizedDeviceChildId == null || authorizedDeviceChildId.isEmpty) {
      return HubProductionTelemetrySnapshot(
        allowed: false,
        reason: HubProductionTelemetryBlockReason.deviceChildNotAuthorized,
        session: session,
        deviceId: deviceId,
      );
    }
    if (selectedChildId != authorizedDeviceChildId) {
      return HubProductionTelemetrySnapshot(
        allowed: false,
        reason: HubProductionTelemetryBlockReason.selectedChildMismatch,
        session: session,
        deviceId: deviceId,
      );
    }
    if (publishedContentVersionId == null ||
        publishedContentVersionId.isEmpty) {
      return HubProductionTelemetrySnapshot(
        allowed: false,
        reason: HubProductionTelemetryBlockReason.noPublishedContentVersion,
        session: session,
        deviceId: deviceId,
      );
    }
    if (!isUuid(publishedContentVersionId)) {
      return HubProductionTelemetrySnapshot(
        allowed: false,
        reason: HubProductionTelemetryBlockReason.contentVersionNotUuid,
        session: session,
        deviceId: deviceId,
        contentVersionId: publishedContentVersionId,
      );
    }
    return HubProductionTelemetrySnapshot(
      allowed: true,
      session: session,
      deviceId: deviceId,
      contentVersionId: publishedContentVersionId,
      playSessionId: const Uuid().v4(),
      consentPolicyVersion: null,
    );
  }
}

/// Builds Shape Matching activities with production or local event buffers.
class HubProductionTelemetryCoordinator {
  HubProductionTelemetryCoordinator({
    required this.outbox,
    required this.contentRegistry,
    required this.deviceChildCatalog,
    this.consentPolicyVersion = AuthPrivacyNotice.version,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final ActivityFileOutbox outbox;
  final PublishedContentRegistry contentRegistry;
  final HubAuthorizedDeviceChildCatalog deviceChildCatalog;
  final String consentPolicyVersion;
  final Uuid _uuid;
  final DateTime Function() _clock;

  HubProductionTelemetrySnapshot? _lastSnapshot;
  int _reconcileGeneration = 0;

  HubProductionTelemetrySnapshot? get lastSnapshot => _lastSnapshot;

  Future<HubProductionTelemetrySnapshot> resolveSnapshot({
    required AuthSession? session,
    required String? selectedChildId,
    required String? deviceId,
    required int reconcileToken,
  }) async {
    final bound = reconcileToken;
    if (session == null) {
      _lastSnapshot = HubProductionTelemetryGate.evaluate(
        session: null,
        selectedChildId: selectedChildId,
        deviceId: deviceId,
        authorizedDeviceChildId: null,
        publishedContentVersionId: null,
      );
      return _lastSnapshot!;
    }
    final authorizedChildId = deviceId == null
        ? null
        : await deviceChildCatalog.authorizedChildId(
            parentId: session.parentId,
            scopedDeviceId: deviceId,
          );
    if (bound != _reconcileGeneration) {
      return _lastSnapshot ??
          HubProductionTelemetryGate.evaluate(
            session: session,
            selectedChildId: selectedChildId,
            deviceId: deviceId,
            authorizedDeviceChildId: authorizedChildId,
            publishedContentVersionId: null,
          );
    }
    final publication = await contentRegistry.publicationForActivity(
      ShapeMatchingConstants.activityId,
    );
    if (bound != _reconcileGeneration) {
      return _lastSnapshot ??
          HubProductionTelemetryGate.evaluate(
            session: session,
            selectedChildId: selectedChildId,
            deviceId: deviceId,
            authorizedDeviceChildId: authorizedChildId,
            publishedContentVersionId: null,
          );
    }
    if (publication == null) {
      _lastSnapshot = HubProductionTelemetryGate.evaluate(
        session: session,
        selectedChildId: selectedChildId,
        deviceId: deviceId,
        authorizedDeviceChildId: authorizedChildId,
        publishedContentVersionId: null,
      );
      return _lastSnapshot!;
    }
    _lastSnapshot = HubProductionTelemetryGate.evaluate(
      session: session,
      selectedChildId: selectedChildId,
      deviceId: deviceId,
      authorizedDeviceChildId: authorizedChildId,
      publishedContentVersionId: publication.contentVersionId,
    );
    if (_lastSnapshot!.allowed) {
      _lastSnapshot = HubProductionTelemetrySnapshot(
        allowed: true,
        session: _lastSnapshot!.session,
        deviceId: _lastSnapshot!.deviceId,
        contentVersionId: _lastSnapshot!.contentVersionId,
        playSessionId: _lastSnapshot!.playSessionId,
        consentPolicyVersion: publication.consentPolicyVersion,
      );
    }
    return _lastSnapshot!;
  }

  Future<ShapeMatchingActivity> buildShapeMatchingActivity({
    required int? Function() ageMonthsProvider,
    required HubProductionTelemetrySnapshot snapshot,
    String localeTag = 'en-US',
    bool soundOff = false,
  }) async {
    final buffer = _eventBufferFor(snapshot);
    final playSessionId = snapshot.playSessionId ??
        'session-${_clock().toUtc().microsecondsSinceEpoch}';
    return ShapeMatchingActivity(
      ageMonthsProvider: ageMonthsProvider,
      eventBuffer: buffer,
      localeTag: localeTag,
      soundOff: soundOff,
      playSessionId: playSessionId,
      sessionIdFactory: () => _uuid.v4(),
    );
  }

  /// Refreshes the registry entry for Shape Matching when gates or child scope change.
  Future<void> reconcileHubRegistry({
    required ActivityRegistry registry,
    required int? Function() ageMonthsProvider,
    required AuthSession? session,
    required String? selectedChildId,
    required String? deviceId,
    String localeTag = 'en-US',
    bool soundOff = false,
  }) async {
    final bound = ++_reconcileGeneration;
    final snapshot = await resolveSnapshot(
      session: session,
      selectedChildId: selectedChildId,
      deviceId: deviceId,
      reconcileToken: bound,
    );
    if (bound != _reconcileGeneration) return;
    final activity = await buildShapeMatchingActivity(
      ageMonthsProvider: ageMonthsProvider,
      snapshot: snapshot,
      localeTag: localeTag,
      soundOff: soundOff,
    );
    if (bound != _reconcileGeneration) return;
    registry.register(activity);
    if (snapshot.allowed) {
      ActivityTelemetryDiagnostics.bufferMode(production: true);
    } else if (snapshot.reason != null) {
      ActivityTelemetryDiagnostics.gateBlocked(snapshot.reason!.name);
      ActivityTelemetryDiagnostics.bufferMode(production: false);
    } else {
      ActivityTelemetryDiagnostics.bufferMode(production: false);
    }
  }

  ShapeMatchingLocalEventBuffer _eventBufferFor(
    HubProductionTelemetrySnapshot snapshot,
  ) {
    if (!snapshot.allowed ||
        snapshot.session == null ||
        snapshot.deviceId == null ||
        snapshot.contentVersionId == null ||
        snapshot.playSessionId == null) {
      return ShapeMatchingLocalEventBuffer();
    }
    final session = snapshot.session!;
    final deviceId = snapshot.deviceId!;
    final contentVersionId = snapshot.contentVersionId!;
    final playSessionId = snapshot.playSessionId!;
    final policyVersion =
        snapshot.consentPolicyVersion ?? consentPolicyVersion;
    final startedAt = _clock().toUtc();
    final emitter = ActivityEventEmitter(
      outbox: outbox,
      session: session,
      deviceId: deviceId,
      contentVersionId: contentVersionId,
      consentPolicyVersion: policyVersion,
      clock: _clock,
    );
    final sessionPayload = <String, dynamic>{
      'schema_version': '1.0.0',
      'play_session_id': playSessionId,
      'device_id': deviceId,
      'content_version_id': contentVersionId,
      'started_at': startedAt.toIso8601String().replaceFirst('+00:00', 'Z'),
      'completion_status': 'started',
      'consent': {
        'purpose': ShapeMatchingProductionConsent.purpose,
        'consent_scope': ShapeMatchingProductionConsent.scope,
        'policy_version': policyVersion,
        'decision': 'granted',
      },
      'provenance': {
        'emitter': 'kids_mode_client',
        'capture_channel': 'offline_queue',
        'clock_trust': 'wall_clock_only',
      },
    };
    return ShapeMatchingProductionEventBuffer(
      emitter: emitter,
      sessionPayload: sessionPayload,
      deviceId: deviceId,
      contentVersionId: contentVersionId,
    );
  }
}

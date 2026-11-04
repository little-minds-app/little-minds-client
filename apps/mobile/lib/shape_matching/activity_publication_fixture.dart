import 'dart:convert';

import 'package:flutter/services.dart';

import 'activity_publication_pin.dart';
import 'shape_matching_constants.dart';

/// Parsed backend publication fixture (mirrors `content/fixtures/activity-publications/`).
class ActivityPublicationRecord {
  const ActivityPublicationRecord({
    required this.hubActivityId,
    required this.contentVersionId,
    required this.consentPolicyVersion,
    required this.reviewStatus,
  });

  final String hubActivityId;
  final String contentVersionId;
  final String consentPolicyVersion;
  final String reviewStatus;

  bool get isPublished => reviewStatus == 'published';
}

/// Loads pinned activity publication JSON from Flutter assets.
class ActivityPublicationFixtureLoader {
  ActivityPublicationFixtureLoader({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<Map<String, Object?>> loadRawShapeMatching() async {
    final raw = await _bundle.loadString(
      ActivityPublicationPin.fixtureAssetPath(
        ActivityPublicationPin.shapeMatchingFixture,
      ),
    );
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException(
        'Activity publication fixture is not a JSON object: '
        '${ActivityPublicationPin.shapeMatchingFixture}',
      );
    }
    return Map<String, Object?>.from(decoded);
  }

  ActivityPublicationRecord parseShapeMatching(Map<String, Object?> raw) {
    final hubId = raw['hub_activity_id']?.toString();
    final contentVersionId = raw['content_version_id']?.toString();
    final consent = raw['consent_policy_version']?.toString();
    final review = raw['review_status']?.toString();
    if (hubId == null || hubId.isEmpty) {
      throw FormatException('missing hub_activity_id in publication fixture');
    }
    if (hubId != ShapeMatchingConstants.activityId) {
      throw FormatException(
        'Shape Matching publication hub_activity_id mismatch: $hubId',
      );
    }
    if (contentVersionId == null || contentVersionId.isEmpty) {
      throw FormatException('missing content_version_id in publication fixture');
    }
    if (consent == null || consent.isEmpty) {
      throw FormatException('missing consent_policy_version in publication fixture');
    }
    if (review == null || review.isEmpty) {
      throw FormatException('missing review_status in publication fixture');
    }
    return ActivityPublicationRecord(
      hubActivityId: hubId,
      contentVersionId: contentVersionId,
      consentPolicyVersion: consent,
      reviewStatus: review,
    );
  }

  Future<ActivityPublicationRecord> requireShapeMatching() async {
    final raw = await loadRawShapeMatching();
    final record = parseShapeMatching(raw);
    if (!record.isPublished) {
      throw StateError(
        'Shape Matching publication fixture is not published: '
        '${record.reviewStatus}',
      );
    }
    return record;
  }
}

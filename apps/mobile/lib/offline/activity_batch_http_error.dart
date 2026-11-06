import 'dart:convert';

/// Sanitized HTTP 400 diagnostics for LMP-51 batch ingest (no tokens or payloads).
class ActivityBatchHttpErrorSummary {
  const ActivityBatchHttpErrorSummary({
    this.topLevelCode,
    this.fieldPaths = const [],
    this.validationCategories = const [],
  });

  final String? topLevelCode;
  final List<String> fieldPaths;
  final List<String> validationCategories;
}

final RegExp _safeBatchCode = RegExp(r'^[a-z][a-z0-9_.-]{0,100}$');
final RegExp _safeFieldPath = RegExp(
  r'^(sessions|events)(\.(\d+|[a-z][a-z0-9_]*)){0,12}$',
);

ActivityBatchHttpErrorSummary parseActivityBatchHttpError({
  required int status,
  required String body,
}) {
  if (status != 400 || body.trim().isEmpty) {
    return const ActivityBatchHttpErrorSummary();
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return const ActivityBatchHttpErrorSummary(
      validationCategories: ['response.not_json'],
    );
  }
  if (decoded is! Map) {
    return const ActivityBatchHttpErrorSummary(
      validationCategories: ['response.not_object'],
    );
  }
  final map = decoded.cast<String, dynamic>();
  final paths = <String>{};
  final categories = <String>{};
  String? topLevel;

  final message = map['message'];
  if (message is String) {
    _ingestMessage(message, paths, categories, (code) => topLevel ??= code);
  } else if (message is List) {
    for (final item in message) {
      if (item is String) {
        _ingestMessage(item, paths, categories, (code) => topLevel ??= code);
      }
    }
  }

  final error = map['error'];
  if (error is String && _safeBatchCode.hasMatch(error)) {
    categories.add('error.$error');
  }

  final details = map['details'];
  if (details is List) {
    for (final detail in details) {
      if (detail is! Map) continue;
      final path = detail['path'];
      if (path is String && _safeFieldPath.hasMatch(path)) {
        paths.add(path);
      } else if (path is List) {
        final joined = _joinDetailPath(path);
        if (joined != null) paths.add(joined);
      }
      final code = detail['code'] ?? detail['reason'];
      if (code is String && _safeBatchCode.hasMatch(code)) {
        categories.add(code);
      }
    }
  }

  return ActivityBatchHttpErrorSummary(
    topLevelCode: topLevel,
    fieldPaths: paths.take(8).toList(growable: false),
    validationCategories: categories.take(8).toList(growable: false),
  );
}

void _ingestMessage(
  String message,
  Set<String> paths,
  Set<String> categories,
  void Function(String code) rememberTopLevel,
) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return;
  if (_safeBatchCode.hasMatch(trimmed)) {
    rememberTopLevel(trimmed);
    return;
  }
  final pathMatch = RegExp(
    r'^(sessions|events)(?:\.\d+(?:\.[a-z][a-z0-9_]*)*)?',
  ).firstMatch(trimmed);
  if (pathMatch != null) {
    final candidate = pathMatch.group(0)!;
    if (_safeFieldPath.hasMatch(candidate)) {
      paths.add(candidate);
    }
  }
  final lower = trimmed.toLowerCase();
  if (lower.contains('must match pattern') || lower.contains('pattern')) {
    categories.add('schema.pattern');
  } else if (lower.contains('must be') || lower.contains('required')) {
    categories.add('schema.required');
  } else if (lower.contains('enum')) {
    categories.add('schema.enum');
  } else if (lower.contains('additional properties')) {
    categories.add('schema.additional_properties');
  } else {
    categories.add('schema.validation');
  }
}

String? _joinDetailPath(List<dynamic> segments) {
  final parts = <String>[];
  for (final segment in segments) {
    if (segment is int) {
      if (parts.isEmpty) return null;
      parts.add('$segment');
    } else if (segment is String &&
        RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(segment)) {
      parts.add(segment);
    } else {
      return null;
    }
  }
  if (parts.isEmpty) return null;
  final joined = parts.join('.');
  return _safeFieldPath.hasMatch(joined) ? joined : null;
}

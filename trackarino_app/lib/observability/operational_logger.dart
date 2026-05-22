import 'dart:convert';

import 'package:flutter/foundation.dart';

enum OperationalLogCategory {
  app,
  connectivity,
  lifecycle,
  realtime,
  sync,
  replay,
  queue,
  security,
  map,
  routing,
}

class OperationalLogger {
  const OperationalLogger._();

  static void info(
    OperationalLogCategory category,
    String event, {
    Map<String, Object?> fields = const {},
  }) {
    _write('info', category, event, fields);
  }

  static void warning(
    OperationalLogCategory category,
    String event, {
    Map<String, Object?> fields = const {},
  }) {
    _write('warning', category, event, fields);
  }

  static void error(
    OperationalLogCategory category,
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    _write('error', category, event, {
      ...fields,
      if (error != null) 'errorType': error.runtimeType.toString(),
      if (error != null) 'error': _sanitizeValue(error.toString()),
      if (stackTrace != null && kDebugMode) 'stack': stackTrace.toString(),
    });
  }

  static void _write(
    String level,
    OperationalLogCategory category,
    String event,
    Map<String, Object?> fields,
  ) {
    if (kReleaseMode && level == 'info') return;

    final payload = <String, Object?>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'category': category.name,
      'event': event,
      ..._sanitizeFields(fields),
    };

    debugPrint(jsonEncode(payload));
  }

  static Map<String, Object?> _sanitizeFields(Map<String, Object?> fields) {
    return fields.map((key, value) {
      final lowerKey = key.toLowerCase();
      if (lowerKey.contains('token') ||
          lowerKey.contains('authorization') ||
          lowerKey.contains('password') ||
          lowerKey.contains('secret') ||
          lowerKey.contains('payload')) {
        return MapEntry(key, '[redacted]');
      }
      return MapEntry(key, _sanitizeValue(value));
    });
  }

  static Object? _sanitizeValue(Object? value) {
    if (value is Map<String, Object?>) return _sanitizeFields(value);
    if (value is Iterable) return value.map(_sanitizeValue).toList();
    if (value is String && value.length > 500) {
      return '${value.substring(0, 500)}...';
    }
    return value;
  }
}

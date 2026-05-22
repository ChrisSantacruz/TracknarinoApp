import 'dart:async';

import 'package:flutter/foundation.dart';

import 'operational_logger.dart';

enum OperationalErrorType {
  appStartup,
  asyncZone,
  flutterFramework,
  lifecycle,
  realtime,
  syncReplay,
  connectivity,
}

typedef ErrorCaptureHook =
    Future<void> Function(
      Object error,
      StackTrace stackTrace,
      Map<String, String> tags,
    );

class ErrorReporter {
  ErrorReporter._();

  static ErrorCaptureHook? captureHook;

  static Future<void> capture(
    Object error,
    StackTrace stackTrace, {
    required OperationalErrorType type,
    Map<String, String> tags = const {},
  }) async {
    final safeTags = {
      'type': type.name,
      ...tags.map((key, value) => MapEntry(key, _sanitizeTag(value))),
    };

    OperationalLogger.error(
      _categoryFor(type),
      'operational_error',
      error: error,
      stackTrace: stackTrace,
      fields: safeTags,
    );

    final hook = captureHook;
    if (hook == null) return;

    try {
      await hook(error, stackTrace, safeTags);
    } catch (hookError, hookStack) {
      OperationalLogger.error(
        OperationalLogCategory.app,
        'error_reporter_hook_failed',
        error: hookError,
        stackTrace: hookStack,
        fields: {'originalType': type.name},
      );
    }
  }

  static void installFlutterHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        capture(
          details.exception,
          details.stack ?? StackTrace.current,
          type: OperationalErrorType.flutterFramework,
          tags: {'library': details.library ?? 'unknown'},
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(
        capture(error, stackTrace, type: OperationalErrorType.asyncZone),
      );
      return true;
    };
  }

  static OperationalLogCategory _categoryFor(OperationalErrorType type) {
    switch (type) {
      case OperationalErrorType.lifecycle:
        return OperationalLogCategory.lifecycle;
      case OperationalErrorType.realtime:
        return OperationalLogCategory.realtime;
      case OperationalErrorType.syncReplay:
        return OperationalLogCategory.replay;
      case OperationalErrorType.connectivity:
        return OperationalLogCategory.connectivity;
      case OperationalErrorType.appStartup:
      case OperationalErrorType.asyncZone:
      case OperationalErrorType.flutterFramework:
        return OperationalLogCategory.app;
    }
  }

  static String _sanitizeTag(String value) {
    if (value.length <= 120) return value;
    return value.substring(0, 120);
  }
}

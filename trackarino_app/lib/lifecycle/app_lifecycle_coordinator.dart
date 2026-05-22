import 'dart:async';

import 'package:flutter/widgets.dart';

import '../observability/error_reporter.dart';
import '../observability/operational_logger.dart';
import '../offline/sync_engine.dart';
import '../services/realtime_service.dart';

class AppLifecycleCoordinator with WidgetsBindingObserver {
  AppLifecycleCoordinator._();

  static final AppLifecycleCoordinator instance = AppLifecycleCoordinator._();

  bool _initialized = false;
  DateTime? _lastResumeRecoveryAt;

  static const Duration _minimumResumeRecoverySpacing = Duration(seconds: 3);

  void initialize() {
    if (_initialized) return;
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    OperationalLogger.info(
      OperationalLogCategory.lifecycle,
      'app_lifecycle_coordinator_initialized',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    OperationalLogger.info(
      OperationalLogCategory.lifecycle,
      'app_lifecycle_state_changed',
      fields: {'state': state.name},
    );

    if (state == AppLifecycleState.resumed) {
      _recoverAfterResume();
    }
  }

  void _recoverAfterResume() {
    final now = DateTime.now();
    if (_lastResumeRecoveryAt != null &&
        now.difference(_lastResumeRecoveryAt!) <
            _minimumResumeRecoverySpacing) {
      return;
    }
    _lastResumeRecoveryAt = now;

    try {
      SyncEngine.instance.triggerSyncSoon(reason: 'app_resumed');
      unawaited(
        RealtimeService.instance.connect().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          ErrorReporter.capture(
            error,
            stackTrace,
            type: OperationalErrorType.lifecycle,
            tags: {'phase': 'realtime_resume_connect'},
          );
        }),
      );
    } catch (error, stackTrace) {
      ErrorReporter.capture(
        error,
        stackTrace,
        type: OperationalErrorType.lifecycle,
        tags: {'phase': 'resume_recovery'},
      );
    }
  }

  void dispose() {
    if (!_initialized) return;
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
  }
}

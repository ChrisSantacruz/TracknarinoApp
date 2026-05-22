import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../api_service.dart';
import '../observability/error_reporter.dart';
import '../observability/operational_logger.dart';
import '../services/auth_service.dart';
import 'app_database.dart';
import 'connectivity_service.dart';
import 'outbound_sync_repository.dart';
import 'sync_types.dart';

typedef SyncItemSender =
    Future<dynamic> Function(OutboundQueueItem item, Map<String, dynamic> body);

class SyncEngine {
  SyncEngine._({
    required OutboundSyncRepository repository,
    required ConnectivityService connectivity,
    Future<ConnectivityHealth> Function()? refreshConnectivity,
    bool Function()? hasInternetReachability,
    Future<String?> Function()? tokenReader,
    Future<String?> Function()? userIdReader,
    SyncItemSender? itemSender,
  }) : _repository = repository,
       _connectivity = connectivity,
       _refreshConnectivity = refreshConnectivity,
       _hasInternetReachability = hasInternetReachability,
       _tokenReader = tokenReader,
       _userIdReader = userIdReader,
       _itemSender = itemSender;

  static final SyncEngine instance = SyncEngine._(
    repository: OutboundSyncRepository.instance,
    connectivity: ConnectivityService.instance,
  );

  static const int maxGpsQueueDepth = 1000;
  static const Duration _minimumSyncSpacing = Duration(seconds: 5);

  final OutboundSyncRepository _repository;
  final ConnectivityService _connectivity;
  final Future<ConnectivityHealth> Function()? _refreshConnectivity;
  final bool Function()? _hasInternetReachability;
  final Future<String?> Function()? _tokenReader;
  final Future<String?> Function()? _userIdReader;
  final SyncItemSender? _itemSender;

  StreamSubscription<ConnectivityHealth>? _connectivitySubscription;
  Timer? _scheduledSync;
  DateTime? _lastSyncAttemptAt;
  bool _isRunning = false;

  Stream<SyncQueueSummary> get summaryStream => _repository.watchSummary();
  Stream<ConnectivityHealth> get connectivityStream =>
      _connectivity.healthStream;
  ConnectivityHealth get connectivityHealth => _connectivity.current;

  @visibleForTesting
  factory SyncEngine.test({
    required OutboundSyncRepository repository,
    required Future<ConnectivityHealth> Function() refreshConnectivity,
    required bool Function() hasInternetReachability,
    required Future<String?> Function() tokenReader,
    required Future<String?> Function() userIdReader,
    required SyncItemSender itemSender,
  }) {
    return SyncEngine._(
      repository: repository,
      connectivity: ConnectivityService.instance,
      refreshConnectivity: refreshConnectivity,
      hasInternetReachability: hasInternetReachability,
      tokenReader: tokenReader,
      userIdReader: userIdReader,
      itemSender: itemSender,
    );
  }

  Future<void> initialize() async {
    await _repository.resetInterruptedSyncs();
    await _connectivity.initialize();

    _connectivitySubscription ??= _connectivity.healthStream.listen((health) {
      if (health == ConnectivityHealth.internetReachable) {
        triggerSyncSoon(reason: 'connectivity_restored');
      }
    });

    if (_connectivity.hasInternetReachability) {
      triggerSyncSoon(reason: 'startup');
    }

    OperationalLogger.info(
      OperationalLogCategory.sync,
      'sync_engine_initialized',
      fields: {'connectivity': _connectivity.current.name},
    );
  }

  Future<EnqueueResult> enqueueGps({
    required String endpoint,
    required Map<String, dynamic> payload,
    required String clientEventId,
    required DateTime clientTimestamp,
    required int sequence,
  }) async {
    final unsentGps = await _repository.countUnsentGps();
    if (unsentGps >= maxGpsQueueDepth) {
      OperationalLogger.warning(
        OperationalLogCategory.queue,
        'gps_queue_depth_cap_reached',
        fields: {'maxDepth': maxGpsQueueDepth},
      );
      return const EnqueueResult(id: -1, duplicate: true);
    }

    final result = await _repository.enqueue(
      operationType: SyncOperationType.gpsLocation,
      method: 'POST',
      endpoint: endpoint,
      payload: {...payload, 'source': 'offline_sync'},
      clientEventId: clientEventId,
      clientTimestamp: clientTimestamp,
      sequence: sequence,
      priority: 200,
      requiresFifo: true,
    );
    _logEnqueueResult(
      operationType: SyncOperationType.gpsLocation,
      result: result,
      clientEventId: clientEventId,
    );
    triggerSyncSoon(reason: 'gps_enqueued');
    return result;
  }

  Future<EnqueueResult> enqueueAlert({
    required String endpoint,
    required Map<String, dynamic> payload,
    required String clientEventId,
    required DateTime clientTimestamp,
  }) async {
    final result = await _repository.enqueue(
      operationType: SyncOperationType.alert,
      method: 'POST',
      endpoint: endpoint,
      payload: payload,
      clientEventId: clientEventId,
      clientTimestamp: clientTimestamp,
      priority: 10,
      requiresFifo: false,
    );
    _logEnqueueResult(
      operationType: SyncOperationType.alert,
      result: result,
      clientEventId: clientEventId,
    );
    triggerSyncSoon(reason: 'alert_enqueued');
    return result;
  }

  Future<EnqueueResult> enqueueTripAction({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    required String clientEventId,
    required DateTime clientTimestamp,
  }) async {
    final result = await _repository.enqueue(
      operationType: SyncOperationType.tripAction,
      method: method,
      endpoint: endpoint,
      payload: payload,
      clientEventId: clientEventId,
      clientTimestamp: clientTimestamp,
      priority: 20,
      requiresFifo: true,
    );
    _logEnqueueResult(
      operationType: SyncOperationType.tripAction,
      result: result,
      clientEventId: clientEventId,
    );
    triggerSyncSoon(reason: 'trip_action_enqueued');
    return result;
  }

  void triggerSyncSoon({required String reason}) {
    _scheduledSync?.cancel();
    OperationalLogger.info(
      OperationalLogCategory.sync,
      'sync_scheduled',
      fields: {'reason': reason},
    );
    _scheduledSync = Timer(const Duration(milliseconds: 750), () {
      syncNow(reason: reason);
    });
  }

  Future<void> syncNow({String reason = 'manual'}) async {
    if (_isRunning) {
      OperationalLogger.info(
        OperationalLogCategory.sync,
        'sync_skipped_already_running',
        fields: {'reason': reason},
      );
      return;
    }

    final health =
        await (_refreshConnectivity?.call() ?? _connectivity.refresh());
    if (health != ConnectivityHealth.internetReachable) {
      OperationalLogger.info(
        OperationalLogCategory.connectivity,
        'sync_skipped_connectivity',
        fields: {'reason': reason, 'health': health.name},
      );
      return;
    }

    final token = await (_tokenReader?.call() ?? AuthService.getToken());
    if (token == null || token.isEmpty) {
      OperationalLogger.warning(
        OperationalLogCategory.security,
        'sync_skipped_missing_token',
        fields: {'reason': reason},
      );
      return;
    }

    final now = DateTime.now();
    if (_lastSyncAttemptAt != null &&
        now.difference(_lastSyncAttemptAt!) < _minimumSyncSpacing) {
      _scheduledSync?.cancel();
      _scheduledSync = Timer(_minimumSyncSpacing, () {
        syncNow(reason: 'spacing_delay');
      });
      return;
    }

    _lastSyncAttemptAt = now;
    _isRunning = true;

    try {
      OperationalLogger.info(
        OperationalLogCategory.sync,
        'sync_started',
        fields: {'reason': reason},
      );

      while (_hasInternetReachability?.call() ??
          _connectivity.hasInternetReachability) {
        final dueItems = await _repository.getDueItems(limit: 20);
        if (dueItems.isEmpty) break;

        for (final item in dueItems) {
          await _syncItem(item);
        }

        await _repository.trimSyncedGps();
      }
    } catch (error, stackTrace) {
      await ErrorReporter.capture(
        error,
        stackTrace,
        type: OperationalErrorType.syncReplay,
        tags: {'reason': reason},
      );
      rethrow;
    } finally {
      _isRunning = false;
      OperationalLogger.info(
        OperationalLogCategory.sync,
        'sync_finished',
        fields: {'reason': reason},
      );
    }
  }

  Future<void> _syncItem(OutboundQueueItem item) async {
    await _repository.markSyncing(item.id);

    try {
      OperationalLogger.info(
        OperationalLogCategory.replay,
        'replay_attempt_started',
        fields: {
          'id': item.id,
          'operationType': item.operationType,
          'attempts': item.attempts,
        },
      );
      final response = await _send(item);
      await _repository.markSynced(item.id, response);
      OperationalLogger.info(
        OperationalLogCategory.replay,
        'replay_attempt_synced',
        fields: {'id': item.id, 'operationType': item.operationType},
      );
    } catch (error) {
      final retryDelay = _retryDelayFor(item, error);
      await _repository.markFailed(item, error, retryDelay: retryDelay);
      OperationalLogger.warning(
        OperationalLogCategory.replay,
        'replay_attempt_failed',
        fields: {
          'id': item.id,
          'operationType': item.operationType,
          'retryDelaySeconds': retryDelay.inSeconds,
          'retryable': error is ApiException ? error.isRetryable : true,
        },
      );
    }
  }

  Future<dynamic> _send(OutboundQueueItem item) async {
    final decoded = jsonDecode(item.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Payload local inválido para sincronización');
    }

    final currentUserId =
        await (_userIdReader?.call() ?? AuthService.getStoredUserId());
    final queuedUserId =
        (decoded['localUserId'] ?? decoded['camioneroId'])?.toString();
    if (currentUserId != null &&
        queuedUserId != null &&
        queuedUserId != currentUserId) {
      throw const ApiException(
        'Operación local pertenece a otra sesión. No se sincronizó para evitar corrupción.',
      );
    }
    decoded.remove('localUserId');

    final customSender = _itemSender;
    if (customSender != null) {
      return customSender(item, decoded);
    }

    switch (item.method.toUpperCase()) {
      case 'POST':
        return ApiService.post(item.endpoint, decoded);
      case 'PUT':
        return ApiService.put(item.endpoint, decoded);
      case 'DELETE':
        return ApiService.delete(item.endpoint);
      default:
        throw ApiException(
          'Método de sincronización no soportado: ${item.method}',
        );
    }
  }

  Duration _retryDelayFor(OutboundQueueItem item, Object error) {
    if (error is ApiException && !error.isRetryable) {
      return const Duration(hours: 12);
    }

    final exponent = math.min(item.attempts, 6);
    final seconds = math.min(30 * math.pow(2, exponent).toInt(), 1800);
    final jitter = (item.id % 7) * 3;
    return Duration(seconds: seconds + jitter);
  }

  Future<void> dispose() async {
    _scheduledSync?.cancel();
    await _connectivitySubscription?.cancel();
  }

  void _logEnqueueResult({
    required String operationType,
    required EnqueueResult result,
    required String clientEventId,
  }) {
    OperationalLogger.info(
      OperationalLogCategory.queue,
      result.duplicate ? 'queue_duplicate_ignored' : 'queue_item_enqueued',
      fields: {
        'operationType': operationType,
        'id': result.id,
        'clientEventIdHash': clientEventId.hashCode,
      },
    );
  }
}

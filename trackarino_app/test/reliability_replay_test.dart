import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackarino_app/api_service.dart';
import 'package:trackarino_app/offline/app_database.dart';
import 'package:trackarino_app/offline/connectivity_service.dart';
import 'package:trackarino_app/offline/outbound_sync_repository.dart';
import 'package:trackarino_app/offline/sync_engine.dart';
import 'package:trackarino_app/offline/sync_types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 replay reliability integration', () {
    late Directory tempDir;
    late File dbFile;
    late AppDatabase db;
    late OutboundSyncRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tracknarino_replay_');
      dbFile = File('${tempDir.path}/sync.sqlite');
      db = AppDatabase(NativeDatabase(dbFile));
      repository = OutboundSyncRepository(db);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('queue survives restart and preserves replay order', () async {
      await repository.enqueue(
        operationType: SyncOperationType.gpsLocation,
        method: 'POST',
        endpoint: 'https://example.test/api/ubicacion/actualizar',
        payload: _gpsPayload('gps-1', sequence: 1),
        clientEventId: 'gps-1',
        clientTimestamp: DateTime.utc(2026, 5, 22, 10),
        sequence: 1,
        priority: 200,
        requiresFifo: true,
      );
      await repository.enqueue(
        operationType: SyncOperationType.alert,
        method: 'POST',
        endpoint: 'https://example.test/api/alertas',
        payload: _alertPayload('alert-1'),
        clientEventId: 'alert-1',
        clientTimestamp: DateTime.utc(2026, 5, 22, 10, 1),
        priority: 10,
      );
      await db.close();

      db = AppDatabase(NativeDatabase(dbFile));
      repository = OutboundSyncRepository(db);

      final dueItems = await repository.getDueItems(limit: 10);

      expect(dueItems.map((item) => item.clientEventId), ['alert-1', 'gps-1']);
      expect(dueItems.map((item) => item.status).toSet(), {SyncStatus.pending});
    });

    test('duplicate clientEventId is not replayed twice', () async {
      final first = await repository.enqueue(
        operationType: SyncOperationType.alert,
        method: 'POST',
        endpoint: 'https://example.test/api/alertas',
        payload: _alertPayload('alert-dup'),
        clientEventId: 'alert-dup',
        clientTimestamp: DateTime.utc(2026, 5, 22, 10),
        priority: 10,
      );
      final duplicate = await repository.enqueue(
        operationType: SyncOperationType.alert,
        method: 'POST',
        endpoint: 'https://example.test/api/alertas',
        payload: _alertPayload('alert-dup'),
        clientEventId: 'alert-dup',
        clientTimestamp: DateTime.utc(2026, 5, 22, 10),
        priority: 10,
      );

      expect(first.duplicate, isFalse);
      expect(duplicate.duplicate, isTrue);

      final sentIds = <String>[];
      final engine = _testEngine(
        repository,
        sentIds: sentIds,
        sender: (item, body) async {
          sentIds.add(item.clientEventId);
          return {'ack': true, 'clientEventId': item.clientEventId};
        },
      );

      await engine.syncNow(reason: 'duplicate_replay_test');

      expect(sentIds, ['alert-dup']);
      expect((await repository.getSummary()).visibleCount, 0);
    });

    test('retryable replay failure remains recoverable', () async {
      await repository.enqueue(
        operationType: SyncOperationType.tripAction,
        method: 'PUT',
        endpoint: 'https://example.test/api/oportunidades/trip-1/iniciar',
        payload: {
          'clientEventId': 'trip-start-1',
          'localUserId': 'driver-1',
          'action': 'iniciar',
        },
        clientEventId: 'trip-start-1',
        clientTimestamp: DateTime.utc(2026, 5, 22, 10),
        priority: 20,
        requiresFifo: true,
      );

      final engine = _testEngine(
        repository,
        sender: (_, __) async {
          throw const ApiException('temporary backend outage', statusCode: 503);
        },
      );

      await engine.syncNow(reason: 'retryable_failure_test');

      final summary = await repository.getSummary();
      final rows = await db.select(db.outboundQueueItems).get();

      expect(summary.failed, 1);
      expect(rows.single.attempts, 1);
      expect(rows.single.nextRetryAt, isNotNull);
      expect(rows.single.lastError, contains('temporary backend outage'));
    });

    test('interrupted syncing rows reset on restart recovery', () async {
      final result = await repository.enqueue(
        operationType: SyncOperationType.gpsLocation,
        method: 'POST',
        endpoint: 'https://example.test/api/ubicacion/actualizar',
        payload: _gpsPayload('gps-interrupted', sequence: 1),
        clientEventId: 'gps-interrupted',
        clientTimestamp: DateTime.utc(2026, 5, 22, 10),
        sequence: 1,
        priority: 200,
        requiresFifo: true,
      );
      await repository.markSyncing(result.id);

      await repository.resetInterruptedSyncs();

      final rows = await db.select(db.outboundQueueItems).get();
      expect(rows.single.status, SyncStatus.pending);
    });
  });
}

SyncEngine _testEngine(
  OutboundSyncRepository repository, {
  List<String>? sentIds,
  Future<dynamic> Function(OutboundQueueItem item, Map<String, dynamic> body)?
  sender,
}) {
  return SyncEngine.test(
    repository: repository,
    refreshConnectivity: () async => ConnectivityHealth.internetReachable,
    hasInternetReachability: () => true,
    tokenReader: () async => 'test-token',
    userIdReader: () async => 'driver-1',
    itemSender:
        sender ??
        (item, body) async {
          sentIds?.add(item.clientEventId);
          return {'ack': true, 'body': jsonEncode(body)};
        },
  );
}

Map<String, Object?> _gpsPayload(
  String clientEventId, {
  required int sequence,
}) {
  return {
    'lat': 1.2136,
    'lng': -77.2811,
    'timestamp': DateTime.utc(2026, 5, 22, 10).toIso8601String(),
    'clientEventId': clientEventId,
    'camioneroId': 'driver-1',
    'localUserId': 'driver-1',
    'sequence': sequence,
  };
}

Map<String, Object?> _alertPayload(String clientEventId) {
  return {
    'tipo': 'seguridad',
    'coords': {'lat': 1.2136, 'lng': -77.2811},
    'timestamp': DateTime.utc(2026, 5, 22, 10).toIso8601String(),
    'clientEventId': clientEventId,
    'localUserId': 'driver-1',
  };
}

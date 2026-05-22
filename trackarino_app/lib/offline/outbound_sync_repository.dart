import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'sync_types.dart';

class OutboundSyncRepository {
  OutboundSyncRepository(this._db);

  static final OutboundSyncRepository instance = OutboundSyncRepository(
    AppDatabase.instance,
  );

  final AppDatabase _db;

  Future<EnqueueResult> enqueue({
    required String operationType,
    required String method,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String clientEventId,
    required DateTime clientTimestamp,
    int? sequence,
    int priority = 100,
    bool requiresFifo = false,
  }) async {
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.outboundQueueItems)..where(
            (item) => item.clientEventId.equals(clientEventId),
          )).getSingleOrNull();

      if (existing != null) {
        return EnqueueResult(id: existing.id, duplicate: true);
      }

      final id = await _db
          .into(_db.outboundQueueItems)
          .insert(
            OutboundQueueItemsCompanion.insert(
              clientEventId: clientEventId,
              operationType: operationType,
              method: method.toUpperCase(),
              endpoint: endpoint,
              payloadJson: jsonEncode(payload),
              createdAt: DateTime.now().toUtc(),
              clientTimestamp: clientTimestamp.toUtc(),
              sequence: Value(sequence),
              priority: Value(priority),
              requiresFifo: Value(requiresFifo),
            ),
          );

      return EnqueueResult(id: id, duplicate: false);
    });
  }

  Stream<SyncQueueSummary> watchSummary() {
    return _db.select(_db.outboundQueueItems).watch().map(_summarize);
  }

  Stream<List<OutboundQueueItem>> watchRecentItems({int limit = 40}) {
    final query =
        _db.select(_db.outboundQueueItems)
          ..orderBy([
            (item) => OrderingTerm.desc(item.createdAt),
            (item) => OrderingTerm.desc(item.id),
          ])
          ..limit(limit);

    return query.watch();
  }

  Future<SyncQueueSummary> getSummary() async {
    final rows = await _db.select(_db.outboundQueueItems).get();
    return _summarize(rows);
  }

  Future<List<OutboundQueueItem>> getDueItems({int limit = 25}) async {
    final now = DateTime.now().toUtc();
    final query =
        _db.select(_db.outboundQueueItems)
          ..where(
            (item) =>
                (item.status.equals(SyncStatus.pending) |
                    item.status.equals(SyncStatus.failed)) &
                (item.nextRetryAt.isNull() |
                    item.nextRetryAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([
            (item) => OrderingTerm.asc(item.priority),
            (item) => OrderingTerm.asc(item.createdAt),
            (item) => OrderingTerm.asc(item.sequence),
          ])
          ..limit(limit);

    return query.get();
  }

  Future<void> markSyncing(int id) async {
    await (_db.update(_db.outboundQueueItems)
      ..where((item) => item.id.equals(id))).write(
      const OutboundQueueItemsCompanion(
        status: Value(SyncStatus.syncing),
        lastError: Value(null),
      ),
    );
  }

  Future<void> markSynced(int id, dynamic serverAck) async {
    await (_db.update(_db.outboundQueueItems)
      ..where((item) => item.id.equals(id))).write(
      OutboundQueueItemsCompanion(
        status: const Value(SyncStatus.synced),
        syncedAt: Value(DateTime.now().toUtc()),
        serverAckJson: Value(jsonEncode(serverAck ?? <String, dynamic>{})),
        nextRetryAt: const Value(null),
        lastError: const Value(null),
      ),
    );
  }

  Future<void> markFailed(
    OutboundQueueItem item,
    Object error, {
    required Duration retryDelay,
  }) async {
    final attempts = item.attempts + 1;
    await (_db.update(_db.outboundQueueItems)
      ..where((row) => row.id.equals(item.id))).write(
      OutboundQueueItemsCompanion(
        status: const Value(SyncStatus.failed),
        attempts: Value(attempts),
        nextRetryAt: Value(DateTime.now().toUtc().add(retryDelay)),
        lastError: Value(error.toString()),
      ),
    );
  }

  Future<void> resetInterruptedSyncs() async {
    await (_db.update(_db.outboundQueueItems)
      ..where((item) => item.status.equals(SyncStatus.syncing))).write(
      const OutboundQueueItemsCompanion(status: Value(SyncStatus.pending)),
    );
  }

  Future<int> resetFailedForRetry({List<int>? ids}) {
    final update = _db.update(_db.outboundQueueItems)..where((item) {
      final failed = item.status.equals(SyncStatus.failed);
      if (ids == null || ids.isEmpty) return failed;
      return failed & item.id.isIn(ids);
    });

    return update.write(
      const OutboundQueueItemsCompanion(
        status: Value(SyncStatus.pending),
        nextRetryAt: Value(null),
        lastError: Value(null),
      ),
    );
  }

  Future<void> trimSyncedGps({int keepLatest = 250}) async {
    final syncedGps =
        await (_db.select(_db.outboundQueueItems)
              ..where(
                (item) =>
                    item.operationType.equals(SyncOperationType.gpsLocation) &
                    item.status.equals(SyncStatus.synced),
              )
              ..orderBy([(item) => OrderingTerm.desc(item.createdAt)]))
            .get();

    if (syncedGps.length <= keepLatest) return;
    final idsToDelete =
        syncedGps.skip(keepLatest).map((item) => item.id).toList();
    await (_db.delete(_db.outboundQueueItems)
      ..where((item) => item.id.isIn(idsToDelete))).go();
  }

  Future<int> countUnsentGps() async {
    final rows =
        await (_db.select(_db.outboundQueueItems)..where(
          (item) =>
              item.operationType.equals(SyncOperationType.gpsLocation) &
              item.status.isNotIn([SyncStatus.synced]),
        )).get();
    return rows.length;
  }

  SyncQueueSummary _summarize(List<OutboundQueueItem> rows) {
    var pending = 0;
    var syncing = 0;
    var failed = 0;
    DateTime? oldestPendingAt;

    for (final row in rows) {
      if (row.status == SyncStatus.pending) {
        pending += 1;
        if (oldestPendingAt == null ||
            row.createdAt.isBefore(oldestPendingAt)) {
          oldestPendingAt = row.createdAt;
        }
      } else if (row.status == SyncStatus.syncing) {
        syncing += 1;
      } else if (row.status == SyncStatus.failed) {
        failed += 1;
      }
    }

    return SyncQueueSummary(
      pending: pending,
      syncing: syncing,
      failed: failed,
      oldestPendingAt: oldestPendingAt,
    );
  }
}

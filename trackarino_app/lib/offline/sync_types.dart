class SyncOperationType {
  static const gpsLocation = 'gps_location';
  static const alert = 'alert';
  static const tripAction = 'trip_action';
}

class SyncStatus {
  static const pending = 'pending';
  static const syncing = 'syncing';
  static const synced = 'synced';
  static const failed = 'failed';
}

class SyncQueueSummary {
  final int pending;
  final int syncing;
  final int failed;
  final DateTime? oldestPendingAt;

  const SyncQueueSummary({
    required this.pending,
    required this.syncing,
    required this.failed,
    required this.oldestPendingAt,
  });

  bool get hasPending => pending > 0 || syncing > 0;
  bool get hasFailures => failed > 0;
  int get visibleCount => pending + syncing + failed;
}

class EnqueueResult {
  final int id;
  final bool duplicate;

  const EnqueueResult({required this.id, required this.duplicate});
}

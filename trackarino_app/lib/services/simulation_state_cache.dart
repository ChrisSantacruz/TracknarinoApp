import 'dart:convert';

import '../offline/app_database.dart';
import '../simulation/simulation_route_controller.dart';

class SimulationPersistedState {
  final double traveledMeters;
  final double speedKmh;
  final SimulationStatus status;
  final String? stopReason;
  final int stopsMade;
  final int alertsCreated;
  final int deviations;
  final DateTime savedAt;

  const SimulationPersistedState({
    required this.traveledMeters,
    required this.speedKmh,
    required this.status,
    this.stopReason,
    required this.stopsMade,
    required this.alertsCreated,
    required this.deviations,
    required this.savedAt,
  });
}

/// Persists in-progress simulation progress so the driver can resume after navigation.
abstract final class SimulationStateCache {
  static String _key(String oportunidadId) => 'simulation_state_$oportunidadId';

  static Future<void> save({
    required String oportunidadId,
    required SimulationPersistedState state,
  }) async {
    final payload = jsonEncode({
      'traveledMeters': state.traveledMeters,
      'speedKmh': state.speedKmh,
      'status': state.status.name,
      'stopReason': state.stopReason,
      'stopsMade': state.stopsMade,
      'alertsCreated': state.alertsCreated,
      'deviations': state.deviations,
      'savedAt': state.savedAt.toUtc().toIso8601String(),
    });

    await AppDatabase.instance
        .into(AppDatabase.instance.syncMetadata)
        .insertOnConflictUpdate(
          SyncMetadataCompanion.insert(
            key: _key(oportunidadId),
            value: payload,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  static Future<SimulationPersistedState?> load(String oportunidadId) async {
    final row =
        await (AppDatabase.instance.select(AppDatabase.instance.syncMetadata)
              ..where((t) => t.key.equals(_key(oportunidadId))))
            .getSingleOrNull();
    if (row == null) return null;

    try {
      final map = jsonDecode(row.value) as Map<String, dynamic>;
      final statusName = map['status']?.toString() ?? SimulationStatus.idle.name;
      final status = SimulationStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => SimulationStatus.idle,
      );

      return SimulationPersistedState(
        traveledMeters: (map['traveledMeters'] as num?)?.toDouble() ?? 0,
        speedKmh: (map['speedKmh'] as num?)?.toDouble() ?? 60,
        status: status,
        stopReason: map['stopReason']?.toString(),
        stopsMade: (map['stopsMade'] as num?)?.toInt() ?? 0,
        alertsCreated: (map['alertsCreated'] as num?)?.toInt() ?? 0,
        deviations: (map['deviations'] as num?)?.toInt() ?? 0,
        savedAt:
            DateTime.tryParse(map['savedAt']?.toString() ?? '') ??
            row.updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String oportunidadId) async {
    await (AppDatabase.instance.delete(AppDatabase.instance.syncMetadata)
          ..where((t) => t.key.equals(_key(oportunidadId))))
        .go();
  }
}

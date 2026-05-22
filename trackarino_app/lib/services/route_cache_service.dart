import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../offline/app_database.dart';

class CachedRouteSnapshot {
  final List<LatLng> points;
  final double? distanceKm;
  final String? durationLabel;
  final DateTime savedAt;

  const CachedRouteSnapshot({
    required this.points,
    this.distanceKm,
    this.durationLabel,
    required this.savedAt,
  });
}

/// Persists last successful route geometry via SyncMetadata (no schema migration).
abstract final class RouteCacheService {
  static String _key(String oportunidadId) => 'route_cache_$oportunidadId';

  static Future<void> save({
    required String oportunidadId,
    required List<LatLng> points,
    double? distanceKm,
    int? durationMinutes,
  }) async {
    if (points.length < 2) return;

    final durationLabel =
        durationMinutes == null
            ? null
            : durationMinutes >= 60
                ? '${(durationMinutes / 60).toStringAsFixed(1)} h'
                : '$durationMinutes min';

    final payload = jsonEncode({
      'points':
          points
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
      'distanceKm': distanceKm,
      'durationLabel': durationLabel,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });

    final db = AppDatabase.instance;
    await db
        .into(db.syncMetadata)
        .insertOnConflictUpdate(
          SyncMetadataCompanion.insert(
            key: _key(oportunidadId),
            value: payload,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  static Future<CachedRouteSnapshot?> load(String oportunidadId) async {
    final row =
        await (AppDatabase.instance.select(AppDatabase.instance.syncMetadata)
              ..where((t) => t.key.equals(_key(oportunidadId))))
            .getSingleOrNull();

    if (row == null) return null;

    try {
      final map = jsonDecode(row.value) as Map<String, dynamic>;
      final rawPoints = map['points'] as List<dynamic>? ?? [];
      final points = <LatLng>[];
      for (final item in rawPoints) {
        if (item is Map) {
          final lat = (item['lat'] as num?)?.toDouble();
          final lng = (item['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }
      if (points.length < 2) return null;

      final savedAt =
          DateTime.tryParse(map['savedAt']?.toString() ?? '') ??
          row.updatedAt;

      return CachedRouteSnapshot(
        points: points,
        distanceKm: (map['distanceKm'] as num?)?.toDouble(),
        durationLabel: map['durationLabel']?.toString(),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }
}

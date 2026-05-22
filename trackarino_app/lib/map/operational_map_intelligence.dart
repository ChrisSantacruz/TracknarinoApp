import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/alerta_model.dart';
import '../observability/operational_logger.dart';

class OperationalFleetPoint {
  final String id;
  final String status;
  final LatLng point;
  final double heading;
  final bool hasActiveTrip;
  final DateTime updatedAt;
  final Map<String, dynamic> source;

  const OperationalFleetPoint({
    required this.id,
    required this.status,
    required this.point,
    required this.heading,
    required this.hasActiveTrip,
    required this.updatedAt,
    required this.source,
  });

  int get priority {
    if (hasActiveTrip && status == 'active') return 80;
    if (status == 'active') return 70;
    if (status == 'stale') return 45;
    if (status == 'offline') return 30;
    return 20;
  }
}

class OperationalFleetCluster {
  final String id;
  final LatLng center;
  final List<OperationalFleetPoint> points;
  final bool selected;

  const OperationalFleetCluster({
    required this.id,
    required this.center,
    required this.points,
    this.selected = false,
  });

  int get count => points.length;
  int get activeCount =>
      points.where((point) => point.status == 'active').length;
  int get staleCount => points.where((point) => point.status == 'stale').length;
  int get offlineCount =>
      points.where((point) => point.status == 'offline').length;
  int get activeTripCount =>
      points.where((point) => point.hasActiveTrip).length;
  int get priority =>
      points.fold<int>(0, (max, point) => math.max(max, point.priority));
}

class OperationalDensityCell {
  final String id;
  final LatLng center;
  final int count;
  final int priority;

  const OperationalDensityCell({
    required this.id,
    required this.center,
    required this.count,
    required this.priority,
  });
}

class OperationalFleetRenderPlan {
  final List<OperationalFleetPoint> markers;
  final List<OperationalFleetCluster> clusters;
  final List<OperationalDensityCell> densityCells;
  final int totalInputCount;
  final int renderedPointCount;
  final int culledCount;

  const OperationalFleetRenderPlan({
    required this.markers,
    required this.clusters,
    required this.densityCells,
    required this.totalInputCount,
    required this.renderedPointCount,
    required this.culledCount,
  });
}

class OperationalAlertRenderItem {
  final AlertaSeguridad alert;
  final LatLng point;
  final int severityWeight;
  final int freshnessWeight;
  final int proximityWeight;

  const OperationalAlertRenderItem({
    required this.alert,
    required this.point,
    required this.severityWeight,
    required this.freshnessWeight,
    required this.proximityWeight,
  });

  int get priority => severityWeight + freshnessWeight + proximityWeight;
}

class OperationalAlertCluster {
  final String id;
  final LatLng center;
  final List<OperationalAlertRenderItem> items;

  const OperationalAlertCluster({
    required this.id,
    required this.center,
    required this.items,
  });

  int get count => items.length;
  int get priority =>
      items.fold<int>(0, (max, item) => math.max(max, item.priority));
  bool get hasCritical => items.any((item) => item.severityWeight >= 90);
}

class OperationalAlertRenderPlan {
  final List<OperationalAlertRenderItem> markers;
  final List<OperationalAlertCluster> clusters;
  final List<OperationalDensityCell> densityCells;
  final int totalInputCount;
  final int suppressedCount;

  const OperationalAlertRenderPlan({
    required this.markers,
    required this.clusters,
    required this.densityCells,
    required this.totalInputCount,
    required this.suppressedCount,
  });
}

class OperationalMapDiagnostics {
  DateTime? _lastLogAt;
  int _lastFleetMarkerCount = -1;
  int _lastFleetClusterCount = -1;
  int _lastAlertMarkerCount = -1;
  int _lastAlertClusterCount = -1;

  void recordFleetPlan(OperationalFleetRenderPlan plan) {
    if (!_shouldLog(
      markerCount: plan.markers.length,
      clusterCount: plan.clusters.length,
      lastMarkerCount: _lastFleetMarkerCount,
      lastClusterCount: _lastFleetClusterCount,
    )) {
      return;
    }
    _lastFleetMarkerCount = plan.markers.length;
    _lastFleetClusterCount = plan.clusters.length;
    _lastLogAt = DateTime.now();
    OperationalLogger.info(
      OperationalLogCategory.map,
      'fleet_render_plan',
      fields: {
        'markers': plan.markers.length,
        'clusters': plan.clusters.length,
        'densityCells': plan.densityCells.length,
        'culled': plan.culledCount,
        'input': plan.totalInputCount,
      },
    );
  }

  void recordAlertPlan(OperationalAlertRenderPlan plan) {
    if (!_shouldLog(
      markerCount: plan.markers.length,
      clusterCount: plan.clusters.length,
      lastMarkerCount: _lastAlertMarkerCount,
      lastClusterCount: _lastAlertClusterCount,
    )) {
      return;
    }
    _lastAlertMarkerCount = plan.markers.length;
    _lastAlertClusterCount = plan.clusters.length;
    _lastLogAt = DateTime.now();
    OperationalLogger.info(
      OperationalLogCategory.map,
      'alert_render_plan',
      fields: {
        'markers': plan.markers.length,
        'clusters': plan.clusters.length,
        'densityCells': plan.densityCells.length,
        'suppressed': plan.suppressedCount,
        'input': plan.totalInputCount,
      },
    );
  }

  bool _shouldLog({
    required int markerCount,
    required int clusterCount,
    required int lastMarkerCount,
    required int lastClusterCount,
  }) {
    final now = DateTime.now();
    final spaced =
        _lastLogAt == null || now.difference(_lastLogAt!).inSeconds >= 20;
    final materiallyChanged =
        (markerCount - lastMarkerCount).abs() >= 8 ||
        (clusterCount - lastClusterCount).abs() >= 2;
    return spaced && materiallyChanged;
  }
}

abstract final class OperationalMapIntelligence {
  static const int _fleetClusterThreshold = 12;
  static const int _alertClusterThreshold = 8;
  static const int _maxAlertMarkers = 34;

  static OperationalFleetRenderPlan buildFleetPlan({
    required Iterable<Map<String, dynamic>> camioneros,
    required LatLng mapCenter,
    required double zoom,
    required Set<String> visibleStates,
    String? selectedId,
  }) {
    final points =
        camioneros
            .where(
              (camionero) =>
                  visibleStates.contains(camionero['estado'] as String),
            )
            .map(_fleetPointFromMap)
            .toList();

    final viewportAware =
        points.length > 60
            ? points
                .where(
                  (point) =>
                      point.id == selectedId ||
                      _isNearViewport(point.point, mapCenter, zoom),
                )
                .toList()
            : points;

    if (viewportAware.length < _fleetClusterThreshold || zoom >= 15.4) {
      viewportAware.sort((a, b) => a.priority.compareTo(b.priority));
      return OperationalFleetRenderPlan(
        markers: viewportAware,
        clusters: const [],
        densityCells: _densityCells(viewportAware, zoom),
        totalInputCount: points.length,
        renderedPointCount: viewportAware.length,
        culledCount: points.length - viewportAware.length,
      );
    }

    final grouped = <String, List<OperationalFleetPoint>>{};
    final cellSize = _clusterCellSize(zoom);
    for (final point in viewportAware) {
      if (point.id == selectedId) continue;
      final key = _cellKey(point.point, cellSize);
      grouped.putIfAbsent(key, () => []).add(point);
    }

    final markers = <OperationalFleetPoint>[
      ...viewportAware.where((point) => point.id == selectedId),
    ];
    final clusters = <OperationalFleetCluster>[];

    grouped.forEach((key, group) {
      if (group.length < 2) {
        markers.addAll(group);
        return;
      }
      clusters.add(
        OperationalFleetCluster(
          id: key,
          center: _averagePoint(group.map((point) => point.point)),
          points: group,
          selected: group.any((point) => point.id == selectedId),
        ),
      );
    });

    markers.sort((a, b) => a.priority.compareTo(b.priority));
    clusters.sort((a, b) => a.priority.compareTo(b.priority));

    return OperationalFleetRenderPlan(
      markers: markers,
      clusters: clusters,
      densityCells: _densityCells(viewportAware, zoom),
      totalInputCount: points.length,
      renderedPointCount:
          markers.length +
          clusters.fold<int>(0, (sum, cluster) => sum + cluster.count),
      culledCount: points.length - viewportAware.length,
    );
  }

  static OperationalAlertRenderPlan buildAlertPlan({
    required Iterable<AlertaSeguridad> alerts,
    required LatLng mapCenter,
    required double zoom,
    LatLng? currentLocation,
    Set<String> visibleSeverities = const {'critical', 'warning', 'info'},
  }) {
    final prioritized =
        alerts
            .map((alert) {
              final point = LatLng(alert.coords['lat']!, alert.coords['lng']!);
              return OperationalAlertRenderItem(
                alert: alert,
                point: point,
                severityWeight: _severityWeight(alert.tipo),
                freshnessWeight: _freshnessWeight(alert.timestamp),
                proximityWeight:
                    currentLocation == null
                        ? 0
                        : _proximityWeight(currentLocation, point),
              );
            })
            .where((item) {
              return visibleSeverities.contains(
                    _severityName(item.severityWeight),
                  ) &&
                  _isNearViewport(item.point, mapCenter, zoom);
            })
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));

    if (prioritized.length < _alertClusterThreshold || zoom >= 14.8) {
      final markers =
          prioritized.take(_maxAlertMarkers).toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));
      return OperationalAlertRenderPlan(
        markers: markers,
        clusters: const [],
        densityCells: _alertDensityCells(prioritized, zoom),
        totalInputCount: prioritized.length,
        suppressedCount: math.max(0, prioritized.length - markers.length),
      );
    }

    final grouped = <String, List<OperationalAlertRenderItem>>{};
    final cellSize = _clusterCellSize(zoom) * 0.82;
    for (final item in prioritized) {
      grouped.putIfAbsent(_cellKey(item.point, cellSize), () => []).add(item);
    }

    final markers = <OperationalAlertRenderItem>[];
    final clusters = <OperationalAlertCluster>[];

    grouped.forEach((key, group) {
      group.sort((a, b) => b.priority.compareTo(a.priority));
      if (group.length == 1 || group.first.priority >= 135) {
        markers.add(group.first);
        if (group.length > 1) {
          clusters.add(
            OperationalAlertCluster(
              id: '$key-overflow',
              center: _averagePoint(group.skip(1).map((item) => item.point)),
              items: group.skip(1).toList(),
            ),
          );
        }
        return;
      }
      clusters.add(
        OperationalAlertCluster(
          id: key,
          center: _averagePoint(group.map((item) => item.point)),
          items: group,
        ),
      );
    });

    markers.sort((a, b) => a.priority.compareTo(b.priority));
    clusters.sort((a, b) => a.priority.compareTo(b.priority));

    return OperationalAlertRenderPlan(
      markers: markers.take(_maxAlertMarkers).toList(),
      clusters: clusters,
      densityCells: _alertDensityCells(prioritized, zoom),
      totalInputCount: prioritized.length,
      suppressedCount: math.max(0, markers.length - _maxAlertMarkers),
    );
  }

  static OperationalFleetPoint _fleetPointFromMap(
    Map<String, dynamic> camionero,
  ) {
    return OperationalFleetPoint(
      id: camionero['id'] as String,
      status: camionero['estado'] as String,
      point: camionero['ubicacion'] as LatLng,
      heading: camionero['rumbo'] as double,
      hasActiveTrip: camionero['hasActiveTrip'] as bool,
      updatedAt: camionero['ultimaActualizacion'] as DateTime,
      source: camionero,
    );
  }

  static List<OperationalDensityCell> _densityCells(
    List<OperationalFleetPoint> points,
    double zoom,
  ) {
    final grouped = <String, List<OperationalFleetPoint>>{};
    final cellSize = _clusterCellSize(zoom) * 1.6;
    for (final point in points) {
      grouped.putIfAbsent(_cellKey(point.point, cellSize), () => []).add(point);
    }
    return grouped.entries.where((entry) => entry.value.length >= 3).map((
      entry,
    ) {
      final group = entry.value;
      return OperationalDensityCell(
        id: entry.key,
        center: _averagePoint(group.map((point) => point.point)),
        count: group.length,
        priority: group.fold<int>(
          0,
          (max, point) => math.max(max, point.priority),
        ),
      );
    }).toList();
  }

  static List<OperationalDensityCell> _alertDensityCells(
    List<OperationalAlertRenderItem> items,
    double zoom,
  ) {
    final grouped = <String, List<OperationalAlertRenderItem>>{};
    final cellSize = _clusterCellSize(zoom) * 1.45;
    for (final item in items) {
      grouped.putIfAbsent(_cellKey(item.point, cellSize), () => []).add(item);
    }
    return grouped.entries.where((entry) => entry.value.length >= 2).map((
      entry,
    ) {
      final group = entry.value;
      return OperationalDensityCell(
        id: entry.key,
        center: _averagePoint(group.map((item) => item.point)),
        count: group.length,
        priority: group.fold<int>(
          0,
          (max, item) => math.max(max, item.priority),
        ),
      );
    }).toList();
  }

  static bool _isNearViewport(LatLng point, LatLng center, double zoom) {
    final radius = _viewportRadiusDegrees(zoom);
    return (point.latitude - center.latitude).abs() <= radius &&
        (point.longitude - center.longitude).abs() <= radius * 1.25;
  }

  static double _viewportRadiusDegrees(double zoom) {
    if (zoom <= 9) return 2.4;
    if (zoom <= 11) return 1.2;
    if (zoom <= 13) return 0.55;
    if (zoom <= 15) return 0.24;
    return 0.11;
  }

  static double _clusterCellSize(double zoom) {
    if (zoom <= 9) return 0.12;
    if (zoom <= 11) return 0.07;
    if (zoom <= 13) return 0.036;
    if (zoom <= 15) return 0.016;
    return 0.008;
  }

  static String _cellKey(LatLng point, double cellSize) {
    final latCell = (point.latitude / cellSize).floor();
    final lngCell = (point.longitude / cellSize).floor();
    return '$latCell:$lngCell';
  }

  static LatLng _averagePoint(Iterable<LatLng> points) {
    var lat = 0.0;
    var lng = 0.0;
    var count = 0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
      count += 1;
    }
    if (count == 0) return const LatLng(0, 0);
    return LatLng(lat / count, lng / count);
  }

  static int _severityWeight(String type) {
    switch (type.toLowerCase()) {
      case 'robo':
      case 'intento_robo':
      case 'sospecha':
      case 'accidente':
        return 100;
      case 'derrumbe':
      case 'deslizamiento':
      case 'landslide':
        return 85;
      case 'obstaculo':
      case 'bloqueo':
      case 'protesta':
        return 70;
      case 'trancon':
      case 'trafico':
        return 55;
      case 'clima':
      case 'clima_adverso':
        return 35;
      default:
        return 25;
    }
  }

  static String _severityName(int severityWeight) {
    if (severityWeight >= 90) return 'critical';
    if (severityWeight >= 55) return 'warning';
    return 'info';
  }

  static int _freshnessWeight(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);
    if (age.inMinutes <= 15) return 35;
    if (age.inHours <= 2) return 24;
    if (age.inHours <= 8) return 12;
    return 0;
  }

  static int _proximityWeight(LatLng currentLocation, LatLng alertPoint) {
    final meters = const Distance().as(
      LengthUnit.Meter,
      currentLocation,
      alertPoint,
    );
    if (meters <= 2000) return 30;
    if (meters <= 10000) return 18;
    if (meters <= 30000) return 8;
    return 0;
  }
}

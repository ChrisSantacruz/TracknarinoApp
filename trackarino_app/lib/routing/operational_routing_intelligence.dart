import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/alerta_model.dart';
import '../observability/operational_logger.dart';
import '../offline/connectivity_service.dart';

enum RouteDeviationSeverity {
  onRoute,
  slight,
  significant,
  invalid,
}

enum RouteHealthState {
  healthy,
  caution,
  degraded,
  rerouting,
  stale,
  invalid,
  offline,
}

enum RerouteTrigger {
  severeDeviation,
  blockedCorridor,
  staleRoute,
  majorAlertCluster,
  manual,
}

enum RerouteConfidence {
  unavailable,
  low,
  medium,
  high,
}

class OperationalRoutingConfig {
  final double corridorToleranceMeters;
  final double slightDeviationMeters;
  final double significantDeviationMeters;
  final double invalidDeviationMeters;
  final double alertCorridorBufferMeters;
  final int slightDeviationConfirmations;
  final int significantDeviationConfirmations;
  final int invalidDeviationConfirmations;
  final Duration rerouteCooldown;
  final Duration routeStaleAfter;
  final Duration diagnosticsMinSpacing;
  final int maxSegmentsPerAssessment;

  const OperationalRoutingConfig({
    this.corridorToleranceMeters = 85,
    this.slightDeviationMeters = 130,
    this.significantDeviationMeters = 260,
    this.invalidDeviationMeters = 520,
    this.alertCorridorBufferMeters = 240,
    this.slightDeviationConfirmations = 2,
    this.significantDeviationConfirmations = 3,
    this.invalidDeviationConfirmations = 3,
    this.rerouteCooldown = const Duration(minutes: 2),
    this.routeStaleAfter = const Duration(hours: 3),
    this.diagnosticsMinSpacing = const Duration(seconds: 30),
    this.maxSegmentsPerAssessment = 160,
  });
}

class OperationalRouteCorridor {
  final List<LatLng> points;
  final double toleranceMeters;
  final DateTime createdAt;
  final String routeId;

  OperationalRouteCorridor({
    required List<LatLng> points,
    required this.toleranceMeters,
    required this.createdAt,
    required this.routeId,
  }) : points = List.unmodifiable(points);

  bool get isValidGeometry => points.length >= 2;

  RouteProximity closestProximityTo(
    LatLng point, {
    int maxSegments = 160,
  }) {
    if (!isValidGeometry) {
      return const RouteProximity.invalid();
    }

    final step = math.max(1, ((points.length - 1) / maxSegments).ceil());
    var bestDistance = double.infinity;
    var bestSegmentIndex = 0;
    var bestProjectionRatio = 0.0;

    for (var i = 0; i < points.length - 1; i += step) {
      final proximity = _distanceToSegmentMeters(
        point,
        points[i],
        points[math.min(i + step, points.length - 1)],
      );
      if (proximity.distanceMeters < bestDistance) {
        bestDistance = proximity.distanceMeters;
        bestSegmentIndex = i;
        bestProjectionRatio = proximity.projectionRatio;
      }
    }

    return RouteProximity(
      distanceMeters: bestDistance,
      segmentIndex: bestSegmentIndex,
      projectionRatio: bestProjectionRatio,
    );
  }

  List<LatLng> segmentWindow(int segmentIndex, {int radius = 2}) {
    if (points.isEmpty) return const [];
    final start = math.max(0, segmentIndex - radius);
    final end = math.min(points.length, segmentIndex + radius + 2);
    return points.sublist(start, end);
  }
}

class RouteProximity {
  final double distanceMeters;
  final int segmentIndex;
  final double projectionRatio;

  const RouteProximity({
    required this.distanceMeters,
    required this.segmentIndex,
    required this.projectionRatio,
  });

  const RouteProximity.invalid()
      : distanceMeters = double.infinity,
        segmentIndex = 0,
        projectionRatio = 0;
}

class CorridorAlertImpact {
  final AlertaSeguridad alert;
  final double distanceMeters;
  final int severityWeight;
  final int freshnessWeight;
  final int riskScore;
  final int segmentIndex;

  const CorridorAlertImpact({
    required this.alert,
    required this.distanceMeters,
    required this.severityWeight,
    required this.freshnessWeight,
    required this.riskScore,
    required this.segmentIndex,
  });

  bool get isSevere => riskScore >= 115;
  bool get recommendsReroute => severityWeight >= 90 || riskScore >= 135;
}

class OperationalRouteAssessment {
  final RouteHealthState health;
  final RouteDeviationSeverity deviationSeverity;
  final double distanceFromRouteMeters;
  final int closestSegmentIndex;
  final int completedPointCount;
  final List<CorridorAlertImpact> corridorAlerts;
  final List<List<LatLng>> degradedSegments;
  final bool rerouteRecommended;
  final RerouteTrigger? rerouteTrigger;
  final RerouteConfidence rerouteConfidence;
  final String userMessage;
  final DateTime assessedAt;
  final bool routeStale;
  final bool offline;

  const OperationalRouteAssessment({
    required this.health,
    required this.deviationSeverity,
    required this.distanceFromRouteMeters,
    required this.closestSegmentIndex,
    required this.completedPointCount,
    required this.corridorAlerts,
    required this.degradedSegments,
    required this.rerouteRecommended,
    required this.rerouteTrigger,
    required this.rerouteConfidence,
    required this.userMessage,
    required this.assessedAt,
    required this.routeStale,
    required this.offline,
  });

  static OperationalRouteAssessment empty(DateTime now) {
    return OperationalRouteAssessment(
      health: RouteHealthState.invalid,
      deviationSeverity: RouteDeviationSeverity.invalid,
      distanceFromRouteMeters: double.infinity,
      closestSegmentIndex: 0,
      completedPointCount: 0,
      corridorAlerts: const [],
      degradedSegments: const [],
      rerouteRecommended: false,
      rerouteTrigger: null,
      rerouteConfidence: RerouteConfidence.unavailable,
      userMessage: 'Ruta operativa no disponible.',
      assessedAt: now,
      routeStale: false,
      offline: false,
    );
  }
}

class OperationalRoutingController {
  final OperationalRoutingConfig config;

  OperationalRouteCorridor? _corridor;
  DateTime? _lastRerouteAt;
  DateTime? _lastDiagnosticsAt;
  bool _rerouting = false;
  int _slightDeviationSamples = 0;
  int _significantDeviationSamples = 0;
  int _invalidDeviationSamples = 0;
  RouteHealthState? _lastHealth;
  RouteDeviationSeverity? _lastDeviation;

  OperationalRoutingController({
    this.config = const OperationalRoutingConfig(),
  });

  OperationalRouteCorridor? get activeCorridor => _corridor;
  DateTime? get lastRerouteAt => _lastRerouteAt;
  bool get isRerouting => _rerouting;

  void replaceRoute(List<LatLng> points, {DateTime? createdAt}) {
    final now = createdAt ?? DateTime.now();
    _corridor = OperationalRouteCorridor(
      points: points,
      toleranceMeters: config.corridorToleranceMeters,
      createdAt: now,
      routeId: 'route_${now.millisecondsSinceEpoch}_${points.length}',
    );
    _rerouting = false;
    _slightDeviationSamples = 0;
    _significantDeviationSamples = 0;
    _invalidDeviationSamples = 0;
    _lastHealth = null;
    _lastDeviation = null;

    OperationalLogger.info(
      OperationalLogCategory.routing,
      'route_replaced',
      fields: {
        'routePoints': points.length,
        'toleranceMeters': config.corridorToleranceMeters.round(),
      },
    );
  }

  void markRerouteStarted(RerouteTrigger trigger) {
    _rerouting = true;
    _lastRerouteAt = DateTime.now();
    OperationalLogger.warning(
      OperationalLogCategory.routing,
      'reroute_started',
      fields: {'trigger': trigger.name},
    );
  }

  void markRerouteFinished({required bool success}) {
    _rerouting = false;
    OperationalLogger.info(
      OperationalLogCategory.routing,
      success ? 'reroute_completed' : 'reroute_failed',
    );
  }

  bool canAttemptReroute(DateTime now, {bool manual = false}) {
    if (manual) return true;
    if (_lastRerouteAt == null) return true;
    return now.difference(_lastRerouteAt!) >= config.rerouteCooldown;
  }

  OperationalRouteAssessment assess({
    required LatLng currentPosition,
    required List<AlertaSeguridad> alerts,
    required ConnectivityHealth connectivity,
    DateTime? now,
  }) {
    final assessedAt = now ?? DateTime.now();
    final corridor = _corridor;
    if (corridor == null || !corridor.isValidGeometry) {
      return OperationalRouteAssessment.empty(assessedAt);
    }

    final proximity = corridor.closestProximityTo(
      currentPosition,
      maxSegments: config.maxSegmentsPerAssessment,
    );
    final rawDeviation = _classifyDistance(proximity.distanceMeters);
    final confirmedDeviation = _confirmDeviation(rawDeviation);
    final routeStale =
        assessedAt.difference(corridor.createdAt) >= config.routeStaleAfter;
    final offline = connectivity != ConnectivityHealth.internetReachable;
    final impacts = _corridorAlertImpacts(corridor, alerts, assessedAt);
    final severeImpacts = impacts.where((impact) => impact.isSevere).length;
    final rerouteTrigger = _rerouteTrigger(
      confirmedDeviation: confirmedDeviation,
      routeStale: routeStale,
      impacts: impacts,
    );
    final rerouteRecommended =
        rerouteTrigger != null &&
        !offline &&
        !_rerouting &&
        canAttemptReroute(assessedAt);
    final health = _healthState(
      deviation: confirmedDeviation,
      routeStale: routeStale,
      offline: offline,
      severeImpactCount: severeImpacts,
    );

    final assessment = OperationalRouteAssessment(
      health: health,
      deviationSeverity: confirmedDeviation,
      distanceFromRouteMeters: proximity.distanceMeters,
      closestSegmentIndex: proximity.segmentIndex,
      completedPointCount: math.min(
        corridor.points.length,
        proximity.segmentIndex + 1,
      ),
      corridorAlerts: impacts,
      degradedSegments: impacts
          .where((impact) => impact.riskScore >= 90)
          .map((impact) => corridor.segmentWindow(impact.segmentIndex))
          .where((segment) => segment.length >= 2)
          .toList(growable: false),
      rerouteRecommended: rerouteRecommended,
      rerouteTrigger: rerouteTrigger,
      rerouteConfidence: _rerouteConfidence(
        trigger: rerouteTrigger,
        offline: offline,
        cooldownOpen: canAttemptReroute(assessedAt),
      ),
      userMessage: _messageFor(
        health: health,
        deviation: confirmedDeviation,
        routeStale: routeStale,
        offline: offline,
        impacts: impacts,
        rerouteRecommended: rerouteRecommended,
      ),
      assessedAt: assessedAt,
      routeStale: routeStale,
      offline: offline,
    );

    _recordDiagnostics(assessment);
    return assessment;
  }

  RouteDeviationSeverity _classifyDistance(double distanceMeters) {
    if (distanceMeters <= config.corridorToleranceMeters) {
      return RouteDeviationSeverity.onRoute;
    }
    if (distanceMeters <= config.slightDeviationMeters) {
      return RouteDeviationSeverity.slight;
    }
    if (distanceMeters <= config.significantDeviationMeters) {
      return RouteDeviationSeverity.significant;
    }
    if (distanceMeters <= config.invalidDeviationMeters) {
      return RouteDeviationSeverity.significant;
    }
    return RouteDeviationSeverity.invalid;
  }

  RouteDeviationSeverity _confirmDeviation(RouteDeviationSeverity raw) {
    if (raw == RouteDeviationSeverity.onRoute) {
      _slightDeviationSamples = 0;
      _significantDeviationSamples = 0;
      _invalidDeviationSamples = 0;
      return RouteDeviationSeverity.onRoute;
    }

    if (raw.index >= RouteDeviationSeverity.slight.index) {
      _slightDeviationSamples += 1;
    }
    if (raw.index >= RouteDeviationSeverity.significant.index) {
      _significantDeviationSamples += 1;
    } else {
      _significantDeviationSamples = 0;
    }
    if (raw == RouteDeviationSeverity.invalid) {
      _invalidDeviationSamples += 1;
    } else {
      _invalidDeviationSamples = 0;
    }

    if (_invalidDeviationSamples >= config.invalidDeviationConfirmations) {
      return RouteDeviationSeverity.invalid;
    }
    if (_significantDeviationSamples >=
        config.significantDeviationConfirmations) {
      return RouteDeviationSeverity.significant;
    }
    if (_slightDeviationSamples >= config.slightDeviationConfirmations) {
      return RouteDeviationSeverity.slight;
    }
    return RouteDeviationSeverity.onRoute;
  }

  List<CorridorAlertImpact> _corridorAlertImpacts(
    OperationalRouteCorridor corridor,
    List<AlertaSeguridad> alerts,
    DateTime now,
  ) {
    final impacts = <CorridorAlertImpact>[];
    final intersectionLimit =
        corridor.toleranceMeters + config.alertCorridorBufferMeters;

    for (final alert in alerts) {
      final lat = alert.coords['lat'];
      final lng = alert.coords['lng'];
      if (lat == null || lng == null) continue;

      final proximity = corridor.closestProximityTo(
        LatLng(lat, lng),
        maxSegments: config.maxSegmentsPerAssessment,
      );
      if (proximity.distanceMeters > intersectionLimit) continue;

      final severity = _alertSeverityWeight(alert.tipo);
      final freshness = _freshnessWeight(alert.timestamp, now);
      final proximityWeight = _alertProximityWeight(proximity.distanceMeters);
      impacts.add(
        CorridorAlertImpact(
          alert: alert,
          distanceMeters: proximity.distanceMeters,
          severityWeight: severity,
          freshnessWeight: freshness,
          riskScore: severity + freshness + proximityWeight,
          segmentIndex: proximity.segmentIndex,
        ),
      );
    }

    impacts.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return impacts;
  }

  RerouteTrigger? _rerouteTrigger({
    required RouteDeviationSeverity confirmedDeviation,
    required bool routeStale,
    required List<CorridorAlertImpact> impacts,
  }) {
    if (confirmedDeviation == RouteDeviationSeverity.invalid ||
        confirmedDeviation == RouteDeviationSeverity.significant) {
      return RerouteTrigger.severeDeviation;
    }
    if (impacts.any((impact) => impact.recommendsReroute)) {
      return RerouteTrigger.blockedCorridor;
    }
    if (impacts.where((impact) => impact.riskScore >= 90).length >= 3) {
      return RerouteTrigger.majorAlertCluster;
    }
    if (routeStale) return RerouteTrigger.staleRoute;
    return null;
  }

  RouteHealthState _healthState({
    required RouteDeviationSeverity deviation,
    required bool routeStale,
    required bool offline,
    required int severeImpactCount,
  }) {
    if (_rerouting) return RouteHealthState.rerouting;
    if (offline) return RouteHealthState.offline;
    if (routeStale) return RouteHealthState.stale;
    if (deviation == RouteDeviationSeverity.invalid) {
      return RouteHealthState.invalid;
    }
    if (deviation == RouteDeviationSeverity.significant ||
        severeImpactCount >= 1) {
      return RouteHealthState.degraded;
    }
    if (deviation == RouteDeviationSeverity.slight || severeImpactCount > 0) {
      return RouteHealthState.caution;
    }
    return RouteHealthState.healthy;
  }

  RerouteConfidence _rerouteConfidence({
    required RerouteTrigger? trigger,
    required bool offline,
    required bool cooldownOpen,
  }) {
    if (trigger == null || offline || !cooldownOpen) {
      return RerouteConfidence.unavailable;
    }
    switch (trigger) {
      case RerouteTrigger.severeDeviation:
      case RerouteTrigger.blockedCorridor:
        return RerouteConfidence.high;
      case RerouteTrigger.majorAlertCluster:
        return RerouteConfidence.medium;
      case RerouteTrigger.staleRoute:
      case RerouteTrigger.manual:
        return RerouteConfidence.low;
    }
  }

  String _messageFor({
    required RouteHealthState health,
    required RouteDeviationSeverity deviation,
    required bool routeStale,
    required bool offline,
    required List<CorridorAlertImpact> impacts,
    required bool rerouteRecommended,
  }) {
    if (offline) {
      return 'Ruta conservada sin conexión. No se recalcula hasta recuperar señal.';
    }
    if (_rerouting) return 'Recalculando ruta operativa con el proveedor real.';
    if (routeStale) return 'Ruta antigua. Verifica o recalcula antes de continuar.';
    if (rerouteRecommended) {
      return 'Reruta recomendada por desviación o riesgo real en corredor.';
    }
    if (deviation == RouteDeviationSeverity.invalid) {
      return 'Ruta inválida: el vehículo está fuera del corredor operativo.';
    }
    if (deviation == RouteDeviationSeverity.significant) {
      return 'Desviación significativa confirmada. Mantén precaución.';
    }
    if (deviation == RouteDeviationSeverity.slight) {
      return 'Leve desviación del corredor. Seguimiento activo.';
    }
    if (impacts.isNotEmpty) {
      return '${impacts.length} alerta(s) cercanas al corredor. Conduce con cautela.';
    }
    if (health == RouteHealthState.healthy) {
      return 'Ruta saludable y dentro del corredor operativo.';
    }
    return 'Ruta bajo monitoreo operativo.';
  }

  void _recordDiagnostics(OperationalRouteAssessment assessment) {
    final now = assessment.assessedAt;
    final healthChanged = _lastHealth != assessment.health;
    final deviationChanged = _lastDeviation != assessment.deviationSeverity;
    final spaced =
        _lastDiagnosticsAt == null ||
        now.difference(_lastDiagnosticsAt!) >= config.diagnosticsMinSpacing;

    if (!healthChanged && !deviationChanged && !spaced) return;

    _lastHealth = assessment.health;
    _lastDeviation = assessment.deviationSeverity;
    _lastDiagnosticsAt = now;

    OperationalLogger.info(
      OperationalLogCategory.routing,
      'route_assessment',
      fields: {
        'health': assessment.health.name,
        'deviation': assessment.deviationSeverity.name,
        'distanceMeters': assessment.distanceFromRouteMeters.round(),
        'corridorAlerts': assessment.corridorAlerts.length,
        'rerouteRecommended': assessment.rerouteRecommended,
        'trigger': assessment.rerouteTrigger?.name,
      },
    );
  }

  static int _alertSeverityWeight(String type) {
    switch (type.toLowerCase()) {
      case 'robo':
      case 'intento_robo':
      case 'sospecha':
      case 'accidente':
        return 95;
      case 'derrumbe':
      case 'deslizamiento':
      case 'landslide':
      case 'bloqueo':
        return 88;
      case 'obstaculo':
      case 'protesta':
      case 'protest':
        return 72;
      case 'trancon':
      case 'trafico':
        return 48;
      case 'clima':
      case 'clima_adverso':
      case 'weather':
        return 34;
      default:
        return 24;
    }
  }

  static int _freshnessWeight(DateTime timestamp, DateTime now) {
    final age = now.difference(timestamp);
    if (age.inMinutes <= 20) return 32;
    if (age.inHours <= 2) return 24;
    if (age.inHours <= 8) return 12;
    if (age.inHours <= 24) return 5;
    return 0;
  }

  static int _alertProximityWeight(double distanceMeters) {
    if (distanceMeters <= 60) return 26;
    if (distanceMeters <= 140) return 18;
    if (distanceMeters <= 260) return 10;
    return 4;
  }
}

_SegmentDistance _distanceToSegmentMeters(LatLng point, LatLng start, LatLng end) {
  final refLat = _degToRad((start.latitude + end.latitude + point.latitude) / 3);
  final px = _lngMeters(point.longitude, start.longitude, refLat);
  final py = _latMeters(point.latitude, start.latitude);
  final ex = _lngMeters(end.longitude, start.longitude, refLat);
  final ey = _latMeters(end.latitude, start.latitude);
  final lengthSquared = ex * ex + ey * ey;

  if (lengthSquared == 0) {
    return _SegmentDistance(
      distanceMeters: const Distance().as(LengthUnit.Meter, point, start),
      projectionRatio: 0,
    );
  }

  final projectionRatio = ((px * ex + py * ey) / lengthSquared).clamp(0.0, 1.0);
  final closestX = ex * projectionRatio;
  final closestY = ey * projectionRatio;
  final dx = px - closestX;
  final dy = py - closestY;

  return _SegmentDistance(
    distanceMeters: math.sqrt(dx * dx + dy * dy),
    projectionRatio: projectionRatio,
  );
}

double _latMeters(double lat, double originLat) => (lat - originLat) * 110540;

double _lngMeters(double lng, double originLng, double refLatRad) =>
    (lng - originLng) * 111320 * math.cos(refLatRad);

double _degToRad(double degrees) => degrees * math.pi / 180;

class _SegmentDistance {
  final double distanceMeters;
  final double projectionRatio;

  const _SegmentDistance({
    required this.distanceMeters,
    required this.projectionRatio,
  });
}

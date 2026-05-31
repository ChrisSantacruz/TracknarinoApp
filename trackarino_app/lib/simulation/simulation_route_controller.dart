import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../offline/sync_engine.dart';
import '../observability/operational_logger.dart';
import '../services/location_service.dart';
import '../services/realtime_service.dart';

enum SimulationStatus {
  idle,
  running,
  stopped,
  signalLost,
  deviating,
  completed,
}

class SimulationSnapshot {
  final SimulationStatus status;
  final LatLng position;
  final double speedKmh;
  final double progress;
  final double distanceRemainingKm;
  final Duration eta;
  final String? stopReason;
  final int stopsMade;
  final int alertsCreated;
  final int deviations;
  final bool synchronizing;

  const SimulationSnapshot({
    required this.status,
    required this.position,
    required this.speedKmh,
    required this.progress,
    required this.distanceRemainingKm,
    required this.eta,
    this.stopReason,
    required this.stopsMade,
    required this.alertsCreated,
    required this.deviations,
    this.synchronizing = false,
  });
}

class SimulationRouteController {
  SimulationRouteController({
    required this.locationService,
    required this.oportunidadId,
    required List<LatLng> routePoints,
  }) : _routePoints = List.unmodifiable(routePoints);

  final LocationService locationService;
  final String oportunidadId;
  List<LatLng> _routePoints;
  final _distance = const Distance();
  final _snapshots = StreamController<SimulationSnapshot>.broadcast();

  Timer? _timer;
  SimulationStatus _status = SimulationStatus.idle;
  double _speedKmh = 60;
  double _traveledMeters = 0;
  double _totalMeters = 0;
  String? _stopReason;
  int _stopsMade = 0;
  int _alertsCreated = 0;
  int _deviations = 0;
  bool _synchronizing = false;

  Stream<SimulationSnapshot> get snapshots => _snapshots.stream;
  SimulationStatus get status => _status;
  bool get isRunning => _status == SimulationStatus.running;
  bool get isOffline => _status == SimulationStatus.signalLost;

  Future<void> start({required double speedKmh}) async {
    if (_routePoints.length < 2) {
      throw StateError('La simulación requiere una ruta con geometría real.');
    }
    _speedKmh = speedKmh;
    _totalMeters = _routeLengthMeters(_routePoints);
    _status = SimulationStatus.running;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    await _emitCurrentPosition();
  }

  void stopWithReason(String reason) {
    if (_status == SimulationStatus.completed) return;
    _status = SimulationStatus.stopped;
    _stopReason = reason;
    _stopsMade += 1;
    OperationalLogger.info(
      OperationalLogCategory.routing,
      'simulation_trip_stopped',
      fields: {'reason': reason, 'oportunidadId': oportunidadId},
    );
    _publishSnapshot();
  }

  void resume() {
    if (_status == SimulationStatus.completed) return;
    _status = SyncEngine.instance.simulationOfflineOverride
        ? SimulationStatus.signalLost
        : SimulationStatus.running;
    _stopReason = null;
    _publishSnapshot();
  }

  void registerAlertCreated() {
    _alertsCreated += 1;
    _publishSnapshot();
  }

  void simulateSignalLoss() {
    if (_status == SimulationStatus.completed) return;
    SyncEngine.instance.setSimulationOfflineOverride(true);
    RealtimeService.instance.disconnect();
    _status = SimulationStatus.signalLost;
    _publishSnapshot();
  }

  Future<void> recoverSignal() async {
    if (_status == SimulationStatus.completed) return;
    _synchronizing = true;
    _publishSnapshot();
    await RealtimeService.instance.connect();
    SyncEngine.instance.setSimulationOfflineOverride(false);
    await SyncEngine.instance.syncNow(reason: 'simulation_signal_recovered');
    _synchronizing = false;
    _status = SimulationStatus.running;
    _publishSnapshot();
  }

  Future<void> deviateToward(LatLng target) async {
    if (_status == SimulationStatus.completed) return;
    _deviations += 1;
    _status = SimulationStatus.deviating;
    await _emitPosition(target);
    _publishSnapshot(positionOverride: target);
  }

  void replaceRoute(List<LatLng> points) {
    if (points.length < 2) return;
    _routePoints = List.unmodifiable(points);
    _traveledMeters = 0;
    _totalMeters = _routeLengthMeters(points);
    _status = SimulationStatus.running;
    _publishSnapshot(positionOverride: points.first);
  }

  Future<void> _tick() async {
    if (_status == SimulationStatus.stopped ||
        _status == SimulationStatus.deviating ||
        _status == SimulationStatus.completed) {
      return;
    }

    final metersPerSecond = (_speedKmh * 1000) / 3600;
    _traveledMeters = math.min(_totalMeters, _traveledMeters + metersPerSecond);
    await _emitCurrentPosition();

    if (_traveledMeters >= _totalMeters) {
      _status = SimulationStatus.completed;
      _timer?.cancel();
      OperationalLogger.info(
        OperationalLogCategory.routing,
        'simulation_trip_completed',
        fields: {
          'oportunidadId': oportunidadId,
          'distanceKm': (_totalMeters / 1000).toStringAsFixed(2),
        },
      );
    }
    _publishSnapshot();
  }

  Future<void> _emitCurrentPosition() async {
    final position = _positionAt(_traveledMeters);
    await _emitPosition(position);
  }

  Future<void> _emitPosition(LatLng point) {
    return locationService.updateSimulatedPosition(
      Position(
        latitude: point.latitude,
        longitude: point.longitude,
        timestamp: DateTime.now().toUtc(),
        accuracy: 5,
        altitude: 0,
        heading: 0,
        speed: _speedKmh / 3.6,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      ),
      oportunidadId: oportunidadId,
    );
  }

  LatLng _positionAt(double traveledMeters) {
    var remaining = traveledMeters;
    for (var i = 0; i < _routePoints.length - 1; i++) {
      final start = _routePoints[i];
      final end = _routePoints[i + 1];
      final segmentMeters = _distance.as(LengthUnit.Meter, start, end);
      if (remaining <= segmentMeters) {
        final ratio = segmentMeters == 0 ? 0.0 : remaining / segmentMeters;
        return LatLng(
          start.latitude + ((end.latitude - start.latitude) * ratio),
          start.longitude + ((end.longitude - start.longitude) * ratio),
        );
      }
      remaining -= segmentMeters;
    }
    return _routePoints.last;
  }

  double _routeLengthMeters(List<LatLng> points) {
    var meters = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      meters += _distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return meters;
  }

  void _publishSnapshot({LatLng? positionOverride}) {
    if (_snapshots.isClosed || _routePoints.isEmpty) return;
    final remainingMeters = math.max(0.0, _totalMeters - _traveledMeters);
    final secondsRemaining =
        _speedKmh <= 0 ? 0 : (remainingMeters / ((_speedKmh * 1000) / 3600)).round();
    _snapshots.add(
      SimulationSnapshot(
        status: _status,
        position: positionOverride ?? _positionAt(_traveledMeters),
        speedKmh: _speedKmh,
        progress: _totalMeters == 0 ? 0 : _traveledMeters / _totalMeters,
        distanceRemainingKm: remainingMeters / 1000,
        eta: Duration(seconds: secondsRemaining),
        stopReason: _stopReason,
        stopsMade: _stopsMade,
        alertsCreated: _alertsCreated,
        deviations: _deviations,
        synchronizing: _synchronizing,
      ),
    );
  }

  void dispose() {
    _timer?.cancel();
    _snapshots.close();
  }
}

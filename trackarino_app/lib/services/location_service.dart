import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import '../config/api_config.dart';
import '../models/ubicacion_model.dart';
import '../api_service.dart';
import '../observability/operational_logger.dart';
import '../offline/sync_engine.dart';

/// Camionero GPS upload. Contractor fleet polling: [ContratistaTrackingService].
class LocationService extends ChangeNotifier {
  Position? _lastPosition;
  Position? _currentPosition;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  StreamSubscription<Position>? _positionStreamSubscription;
  double _heading = 0.0;
  bool _isTracking = false;
  String? _camioneroId;
  bool _simulationMode = false;

  DateTime? _lastServerSendAt;
  Position? _lastSentPosition;
  int _sendSequence = 0;

  static const Duration _minSendInterval = Duration(seconds: 10);
  static const double _maxAccuracyMeters = 500;

  Stream<Position> get positionStream => _positionController.stream;
  Position? get lastPosition => _lastPosition;
  Position? get currentPosition => _currentPosition;
  double get heading => _heading;
  bool get isTracking => _isTracking;

  Future<void> init(String camioneroId) async {
    _camioneroId = camioneroId;
    _simulationMode = camioneroId == '65f13d000000000000000013';
    if (_simulationMode) return;
    await _checkLocationPermission();
  }

  Future<bool> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    if (_simulationMode && _currentPosition != null) {
      return _currentPosition;
    }

    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      if (position.accuracy > _maxAccuracyMeters) {
        OperationalLogger.info(
          OperationalLogCategory.sync,
          'gps_position_rejected_accuracy',
          fields: {'accuracy': position.accuracy},
        );
        return null;
      }

      _currentPosition = position;
      notifyListeners();
      return position;
    } catch (e) {
      OperationalLogger.warning(
        OperationalLogCategory.sync,
        'gps_current_position_failed',
        fields: {'errorType': e.runtimeType.toString()},
      );
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (position.accuracy <= _maxAccuracyMeters) {
          _currentPosition = position;
          notifyListeners();
          return position;
        }
      } catch (e2) {
        OperationalLogger.warning(
          OperationalLogCategory.sync,
          'gps_current_position_retry_failed',
          fields: {'errorType': e2.runtimeType.toString()},
        );
      }
      return null;
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    if (_simulationMode) {
      _isTracking = true;
      notifyListeners();
      return;
    }

    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        timeLimit: Duration(seconds: 10),
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(_updatePosition);

      _isTracking = true;
      notifyListeners();
    } catch (e) {
      OperationalLogger.warning(
        OperationalLogCategory.lifecycle,
        'gps_tracking_start_failed',
        fields: {'errorType': e.runtimeType.toString()},
      );
    }
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  void _updatePosition(Position position) {
    if (position.accuracy > _maxAccuracyMeters) return;

    if (_currentPosition != null) {
      _lastPosition = _currentPosition;
    }

    _currentPosition = position;

    if (_lastPosition != null) {
      _heading = _calculateHeading(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    if (_camioneroId != null) {
      sendLocationToServer(position);
    }

    if (!_positionController.isClosed) {
      _positionController.add(position);
    }
    notifyListeners();
  }

  Future<void> updateSimulatedPosition(
    Position position, {
    String? oportunidadId,
  }) async {
    if (_currentPosition != null) {
      _lastPosition = _currentPosition;
    }

    _currentPosition = position;
    if (_lastPosition != null) {
      _heading = _calculateHeading(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    if (_camioneroId != null) {
      await sendLocationToServer(position, oportunidadId: oportunidadId);
    }

    if (!_positionController.isClosed) {
      _positionController.add(position);
    }
    notifyListeners();
  }

  double _calculateHeading(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = lat1 * math.pi / 180;
    final lon1Rad = lon1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final lon2Rad = lon2 * math.pi / 180;
    final dLon = lon2Rad - lon1Rad;
    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    final heading = math.atan2(y, x) * (180 / math.pi);
    return (heading + 360) % 360;
  }

  bool _shouldThrottleSend(Position position) {
    final now = DateTime.now();
    if (_lastServerSendAt != null &&
        now.difference(_lastServerSendAt!) < _minSendInterval) {
      return true;
    }

    if (_lastSentPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastSentPosition!.latitude,
        _lastSentPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < 3) return true;
    }

    return false;
  }

  String _buildClientEventId(Position position) {
    final ts = position.timestamp.millisecondsSinceEpoch;
    return '${_camioneroId}_${ts}_${position.latitude.toStringAsFixed(5)}_${position.longitude.toStringAsFixed(5)}';
  }

  Future<void> sendLocationToServer(
    Position position, {
    String? oportunidadId,
  }) async {
    if (_camioneroId == null) return;
    if (_shouldThrottleSend(position)) return;

    try {
      _sendSequence += 1;
      final clientEventId = _buildClientEventId(position);
      final data = {
        'lat': position.latitude,
        'lng': position.longitude,
        'latitud': position.latitude,
        'longitud': position.longitude,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'heading': _heading,
        'timestamp': position.timestamp.toIso8601String(),
        'camioneroId': _camioneroId,
        'localUserId': _camioneroId,
        'source': 'gps',
        if (oportunidadId != null) 'oportunidadId': oportunidadId,
        'clientEventId': clientEventId,
        'sequence': _sendSequence,
      };

      await SyncEngine.instance.enqueueGps(
        endpoint: '${ApiConfig.ubicacion}/actualizar',
        payload: data,
        clientEventId: clientEventId,
        clientTimestamp: position.timestamp,
        sequence: _sendSequence,
      );
      _lastServerSendAt = DateTime.now();
      _lastSentPosition = position;
    } catch (e) {
      OperationalLogger.error(
        OperationalLogCategory.queue,
        'gps_enqueue_failed',
        error: e,
      );
    }
  }

  Future<Ubicacion?> obtenerUltimaPosicionCamionero(String idCamionero) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.ubicacion}/ultima/$idCamionero',
      );
      return Ubicacion.fromJson(response);
    } catch (e) {
      OperationalLogger.warning(
        OperationalLogCategory.connectivity,
        'gps_latest_position_fetch_failed',
        fields: {'errorType': e.runtimeType.toString()},
      );
      return null;
    }
  }

  double calculateHeading(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final lon2 = end.longitude * math.pi / 180;
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    var bearing = math.atan2(y, x) * (180 / math.pi);
    bearing = (bearing + 360) % 360;
    return bearing;
  }

  @override
  void dispose() {
    stopTracking();
    _positionController.close();
    super.dispose();
  }
}

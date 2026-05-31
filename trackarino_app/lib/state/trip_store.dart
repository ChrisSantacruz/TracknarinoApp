import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/oportunidad_model.dart';
import '../services/oportunidad_service.dart';
import '../services/route_cache_service.dart';

enum ActiveTripLoadStatus { idle, loading, ready, error }

/// Active trip + cached route snapshot for map screens.
class TripStore extends ChangeNotifier {
  Oportunidad? _activeTrip;
  ActiveTripLoadStatus _status = ActiveTripLoadStatus.idle;
  String? _errorMessage;

  List<LatLng> _routePoints = [];
  double? _distanceKm;
  String? _durationLabel;
  bool _routeFromCache = false;
  bool _simulationTripActive = false;

  Oportunidad? get activeTrip => _activeTrip;
  ActiveTripLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  double? get distanceKm => _distanceKm;
  String? get durationLabel => _durationLabel;
  bool get routeFromCache => _routeFromCache;
  bool get hasActiveTrip => _activeTrip != null;
  bool get simulationTripActive => _simulationTripActive;

  Future<void> refreshActiveTrip() async {
    if (_simulationTripActive) {
      _status = ActiveTripLoadStatus.ready;
      notifyListeners();
      return;
    }

    _status = ActiveTripLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final trip = await OportunidadService.obtenerViajeActivo();
      _activeTrip = trip;
      _status = ActiveTripLoadStatus.ready;

      if (trip?.id != null) {
        final cached = await RouteCacheService.load(trip!.id!);
        if (cached != null) {
          _applyCachedRoute(cached);
        }
      } else {
        _routePoints = [];
        _distanceKm = null;
        _durationLabel = null;
        _routeFromCache = false;
        _simulationTripActive = false;
      }
    } catch (e) {
      _errorMessage = 'No se pudo cargar el viaje activo.';
      _status = ActiveTripLoadStatus.error;
    }
    notifyListeners();
  }

  void setActiveTrip(Oportunidad trip) {
    _activeTrip = trip;
    _status = ActiveTripLoadStatus.ready;
    notifyListeners();
  }

  void setSimulationActiveTrip(Oportunidad trip) {
    _simulationTripActive = true;
    setActiveTrip(trip);
  }

  void clearActiveTrip() {
    _activeTrip = null;
    _routePoints = [];
    _distanceKm = null;
    _durationLabel = null;
    _routeFromCache = false;
    _simulationTripActive = false;
    _status = ActiveTripLoadStatus.idle;
    notifyListeners();
  }

  void applyRoute({
    required List<LatLng> points,
    double? distanceKm,
    String? durationLabel,
    bool fromCache = false,
  }) {
    _routePoints = List.from(points);
    _distanceKm = distanceKm;
    _durationLabel = durationLabel;
    _routeFromCache = fromCache;
    notifyListeners();
  }

  Future<void> persistRoute({
    required String oportunidadId,
    required List<LatLng> points,
    double? distanceKm,
    int? durationMinutes,
  }) async {
    await RouteCacheService.save(
      oportunidadId: oportunidadId,
      points: points,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
    _routeFromCache = false;
  }

  void _applyCachedRoute(CachedRouteSnapshot snapshot) {
    _routePoints = List.from(snapshot.points);
    _distanceKm = snapshot.distanceKm;
    _durationLabel = snapshot.durationLabel;
    _routeFromCache = true;
  }
}

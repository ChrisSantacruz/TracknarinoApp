import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/oportunidad_model.dart';
import '../../models/alerta_model.dart';
import '../../offline/connectivity_service.dart';
import '../../routing/operational_routing_intelligence.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../services/oportunidad_service.dart';
import '../../services/alerta_service.dart';
import '../../services/ors_service.dart';
import '../../services/route_cache_service.dart';
import '../../services/simulation_state_cache.dart';
import '../../simulation/simulation_route_controller.dart';
import '../../state/trip_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/map_control_cluster.dart';
import '../../widgets/operational/operational_error_state.dart';
import '../../widgets/operational/operational_map_primitives.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../widgets/operational/operational_status_chip.dart';
import 'dart:async';

class RutaViajeScreen extends StatefulWidget {
  final Oportunidad oportunidad;

  const RutaViajeScreen({super.key, required this.oportunidad});

  @override
  State<RutaViajeScreen> createState() => _RutaViajeScreenState();
}

class _RutaViajeScreenState extends State<RutaViajeScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _destinoPosition;
  List<LatLng> _routePoints = [];
  double _currentHeading = 0;
  bool _isLoadingRoute = true;
  String? _errorMessage;

  // Información de la ruta
  double? _distanciaKm;
  String? _duracionTexto;

  // Alertas en la ruta
  List<AlertaSeguridad> _alertasEnRuta = [];
  final OperationalRoutingController _routingController =
      OperationalRoutingController();
  OperationalRouteAssessment? _routeAssessment;
  List<LatLng> _rerouteCandidatePoints = [];
  ConnectivityHealth _connectivityHealth = ConnectivityService.instance.current;

  // Estado del viaje
  bool _viajeIniciado = false;

  StreamSubscription? _locationSubscription;
  StreamSubscription<ConnectivityHealth>? _connectivitySubscription;
  StreamSubscription<SimulationSnapshot>? _simulationSubscription;
  SimulationRouteController? _simulationController;
  SimulationSnapshot? _simulationSnapshot;

  bool _initialized = false;
  bool _isFollowingVehicle = true;
  bool _navigationMode = false;
  bool _completionSynced = false;
  bool _completionDialogShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.oportunidad.estado == 'en_ruta') {
      _viajeIniciado = true;
      _navigationMode = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initializeRoute();
      if (_viajeIniciado) {
        final locationService = Provider.of<LocationService>(
          context,
          listen: false,
        );
        if (!locationService.isTracking) {
          locationService.startTracking();
        }
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _simulationSubscription?.cancel();
    unawaited(_persistSimulationState());
    _simulationController?.dispose();
    super.dispose();
  }

  Future<void> _persistSimulationState() async {
    final controller = _simulationController;
    final tripId = widget.oportunidad.id;
    if (controller == null || tripId == null) return;
    if (controller.status == SimulationStatus.idle ||
        controller.status == SimulationStatus.completed) {
      return;
    }

    await SimulationStateCache.save(
      oportunidadId: tripId,
      state: controller.exportState(),
    );
  }

  void _bindSimulationController(SimulationRouteController controller) {
    if (!identical(_simulationController, controller)) {
      _simulationController?.dispose();
      _simulationController = controller;
    }
    _simulationSubscription?.cancel();
    _simulationSubscription = controller.snapshots.listen((snapshot) async {
      if (!mounted) return;
      setState(() {
        _simulationSnapshot = snapshot;
        _currentPosition = snapshot.position;
        _viajeIniciado = true;
        _navigationMode = true;
      });
      _evaluateRoutingState(snapshot.position);
      if (_isFollowingVehicle) {
        _mapController.move(snapshot.position, 16.2);
      }
      if (snapshot.status == SimulationStatus.completed) {
        await _completarViajeEnServidor();
        if (!mounted || _completionDialogShown) return;
        _completionDialogShown = true;
        await _mostrarResumenCompletado(snapshot);
        return;
      }
      if (snapshot.status != SimulationStatus.idle) {
        await _persistSimulationState();
      }
    });
  }

  Future<void> _restoreSimulationIfNeeded(LocationService locationService) async {
    final auth = context.read<AuthService>();
    if (!auth.isSimulationSession) return;
    if (!_viajeIniciado || widget.oportunidad.id == null) return;
    if (_simulationController != null) return;
    if (_routePoints.length < 2) return;

    final saved = await SimulationStateCache.load(widget.oportunidad.id!);
    if (saved == null) return;

    final controller = SimulationRouteController(
      locationService: locationService,
      oportunidadId: widget.oportunidad.id!,
      routePoints: _routePoints,
    );
    _bindSimulationController(controller);
    await controller.restoreState(saved);
    await locationService.startTracking();

    if (!mounted) return;
    setState(() {
      _viajeIniciado = true;
      _navigationMode = true;
    });
  }

  Future<void> _resumeSimulation() async {
    if (_simulationController == null) {
      final locationService = Provider.of<LocationService>(
        context,
        listen: false,
      );
      await _restoreSimulationIfNeeded(locationService);
    }
    _simulationController?.resume();
  }

  Future<void> _initializeRoute() async {
    setState(() {
      _isLoadingRoute = true;
      _errorMessage = null;
    });

    try {
      // Esperar a que el frame actual termine de construirse
      await Future.delayed(Duration.zero);

      if (!mounted) return;

      // Solicitar permisos de ubicación
      final locationService = Provider.of<LocationService>(
        context,
        listen: false,
      );

      final auth = context.read<AuthService>();
      final origin = widget.oportunidad.origin;
      final simulatedStart =
          auth.isSimulationSession && origin != null
              ? LatLng(origin.lat, origin.lng)
              : null;

      // Obtener ubicación actual
      final position =
          simulatedStart == null
              ? await locationService.getCurrentLocation()
              : null;

      if (simulatedStart == null && position == null) {
        setState(() {
          _errorMessage =
              'No se pudo obtener tu ubicación. Verifica los permisos en la configuración.';
          _isLoadingRoute = false;
        });
        return;
      }

      final currentLatLng =
          simulatedStart ?? LatLng(position!.latitude, position.longitude);

      setState(() {
        _currentPosition = currentLatLng;
      });

      final destination = widget.oportunidad.destination;
      if (destination == null) {
        setState(() {
          _destinoPosition = null;
          _routePoints = [];
          _errorMessage =
              'Esta carga aún no tiene coordenadas verificadas de destino. Puedes reintentar cuando el contratista complete la ubicación o continuar revisando el detalle del viaje.';
          _isLoadingRoute = false;
        });
        return;
      }

      final destinoLatLng = LatLng(destination.lat, destination.lng);
      setState(() {
        _destinoPosition = destinoLatLng;
      });

      List<LatLng> points = [];
      double? distanceKm;
      int? durationMin;
      var fromCache = false;

      if (widget.oportunidad.id != null) {
        final cached = await RouteCacheService.load(widget.oportunidad.id!);
        if (cached != null) {
          points = cached.points;
          distanceKm = cached.distanceKm;
          _duracionTexto = cached.durationLabel;
          fromCache = true;
        }
      }

      if (points.length < 2) {
        final routeData = await ORSService.obtenerRuta(
          currentLatLng,
          destinoLatLng,
        );
        points = List<LatLng>.from(routeData['coordinates'] as List);
        distanceKm = routeData['distance'] as double?;
        durationMin = routeData['duration'] as int?;
        _duracionTexto =
            durationMin == null
                ? null
                : durationMin >= 60
                ? '${(durationMin / 60).toStringAsFixed(1)} h'
                : '$durationMin min';
        if (widget.oportunidad.id != null) {
          await RouteCacheService.save(
            oportunidadId: widget.oportunidad.id!,
            points: points,
            distanceKm: distanceKm,
            durationMinutes: durationMin,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _routePoints = points;
        _distanciaKm = distanceKm;
        _isLoadingRoute = false;
      });
      context.read<TripStore>().applyRoute(
        points: points,
        distanceKm: distanceKm,
        durationLabel: _duracionTexto,
        fromCache: fromCache,
      );
      _routingController.replaceRoute(_routePoints);
      _evaluateRoutingState(currentLatLng);

      // 5. Centrar mapa en la ruta
      if (_routePoints.isNotEmpty) {
        _centerMapOnRoute();
      }

      _connectivitySubscription ??= ConnectivityService.instance.healthStream
          .listen((health) {
            if (!mounted) return;
            setState(() {
              _connectivityHealth = health;
            });
            _evaluateRoutingState();
          });

      // 6. Suscribirse a actualizaciones de ubicación
      _locationSubscription = locationService.positionStream.listen((
        newPosition,
      ) {
        if (mounted) {
          final nextPosition = LatLng(
            newPosition.latitude,
            newPosition.longitude,
          );
          setState(() {
            _currentPosition = nextPosition;
            _currentHeading =
                newPosition.heading.isFinite
                    ? newPosition.heading
                    : _currentHeading;
          });
          if (_isFollowingVehicle) {
            final followZoom = _viajeIniciado ? 16.2 : _mapController.zoom;
            _mapController.move(nextPosition, followZoom);
          }
          _evaluateRoutingState(nextPosition);
        }
      });

      // 7. Si el viaje ya está iniciado, cargar alertas y restaurar simulación
      if (_viajeIniciado) {
        await _cargarAlertasEnRuta();
        if (auth.isSimulationSession) {
          await _restoreSimulationIfNeeded(locationService);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'No se pudo calcular la ruta en este momento. Revisa conexión, permisos GPS o intenta de nuevo.';
        _isLoadingRoute = false;
      });
    }
  }

  void _evaluateRoutingState([LatLng? position]) {
    final current = position ?? _currentPosition;
    if (current == null || _routePoints.length < 2) return;

    final assessment = _routingController.assess(
      currentPosition: current,
      alerts: _alertasEnRuta,
      connectivity: _connectivityHealth,
    );

    if (!mounted) return;
    setState(() {
      _routeAssessment = assessment;
    });
  }

  void _centerMapOnRoute() {
    if (_routePoints.isEmpty) return;

    // Calcular bounds de la ruta
    double minLat = _routePoints[0].latitude;
    double maxLat = _routePoints[0].latitude;
    double minLng = _routePoints[0].longitude;
    double maxLng = _routePoints[0].longitude;

    for (var point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(padding: EdgeInsets.all(76), maxZoom: 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.oportunidad.titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _mostrarInformacionViaje,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentPosition ?? LatLng(1.2136, -77.2811),
              zoom: 13.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _isFollowingVehicle = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),

              if (_routePoints.isNotEmpty)
                OperationalRouteCorridorLayer(
                  points: _routePoints,
                  toleranceMeters:
                      _routingController.activeCorridor?.toleranceMeters ?? 85,
                  health: _routeAssessment?.health ?? RouteHealthState.healthy,
                ),

              if (_routeAssessment?.degradedSegments.isNotEmpty == true)
                OperationalDegradedRouteSegmentsLayer(
                  segments: _routeAssessment!.degradedSegments,
                ),

              if (_rerouteCandidatePoints.isNotEmpty)
                OperationalRerouteCandidateLayer(
                  points: _rerouteCandidatePoints,
                ),

              if (_routePoints.isNotEmpty)
                OperationalRouteLayer(
                  points: _routePoints,
                  completedPointCount:
                      _routeAssessment?.completedPointCount ?? 0,
                  emphasized: _viajeIniciado,
                ),

              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      width: 52.0,
                      height: 52.0,
                      point: _currentPosition!,
                      builder:
                          (ctx) => OperationalVehiclePresenceMarker(
                            status: _viajeIniciado ? 'en_ruta' : 'active',
                            heading: _currentHeading,
                            selected: true,
                            semanticsLabel: 'Tu vehículo en ruta',
                          ),
                    ),

                  if (_destinoPosition != null)
                    Marker(
                      width: 46.0,
                      height: 46.0,
                      point: _destinoPosition!,
                      builder:
                          (ctx) => const OperationalDestinationMarker(
                            label: 'Destino operativo',
                          ),
                    ),

                  ..._alertasEnRuta.map((alerta) {
                    return Marker(
                      width: 52.0,
                      height: 52.0,
                      point: LatLng(
                        alerta.coords['lat']!,
                        alerta.coords['lng']!,
                      ),
                      builder:
                          (ctx) => OperationalAlertMarker(
                            type: alerta.tipo,
                            timestamp: alerta.timestamp,
                            onTap: () => _mostrarDetalleAlerta(alerta),
                          ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Panel de información
          if (_isLoadingRoute)
            Container(
              color: Colors.black45,
              child: const OperationalLoadingPanel(
                message: 'Calculando ruta operativa...',
              ),
            ),

          if (_errorMessage != null && !_isLoadingRoute)
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: OperationalErrorState(
                  message: _errorMessage!,
                  onRetry: _initializeRoute,
                ),
              ),
            ),

          if (!_isLoadingRoute && _routePoints.isNotEmpty)
            Positioned(
              right: AppSpacing.md,
              bottom: _navigationMode ? 96 : 200,
              child: MapControlCluster(
                onZoomIn:
                    () => _mapController.move(
                      _mapController.center,
                      _mapController.zoom + 1,
                    ),
                onZoomOut:
                    () => _mapController.move(
                      _mapController.center,
                      _mapController.zoom - 1,
                    ),
                onRecenter: () {
                  setState(() => _isFollowingVehicle = true);
                  if (_currentPosition != null) {
                    _mapController.move(_currentPosition!, 16);
                  } else {
                    _centerMapOnRoute();
                  }
                },
                recenterActive: _isFollowingVehicle,
              ),
            ),

          if (!_isLoadingRoute && _routeAssessment != null)
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              right: _viajeIniciado ? 142 : AppSpacing.md,
              child: Align(
                alignment: Alignment.topLeft,
                child: OperationalRouteHealthChip(
                  health: _routeAssessment!.health,
                  deviation: _routeAssessment!.deviationSeverity,
                  corridorAlertCount: _routeAssessment!.corridorAlerts.length,
                  rerouteRecommended: _routeAssessment!.rerouteRecommended,
                ),
              ),
            ),

          // Panel inferior con información
          if (!_isLoadingRoute && _distanciaKm != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child:
                  _navigationMode ? _buildNavigationHud() : _buildInfoPanel(),
            ),

          if (_simulationSnapshot != null)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: _routeAssessment == null ? AppSpacing.md : 78,
              child: _buildSimulationControlPanel(_simulationSnapshot!),
            ),

          // Botones de acción en esquinas superiores
          if (_viajeIniciado) ...[
            Positioned(
              top: _routeAssessment == null ? AppSpacing.md : 76,
              left: AppSpacing.md,
              child: OperationalMapActionChip(
                svg: operationalPhoneSvg,
                label: 'SOS 112',
                color: AppColors.alertCritical,
                onPressed: _llamarSOS,
              ),
            ),

            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OperationalMapActionChip(
                    svg: operationalCrosshairSvg,
                    label:
                        _navigationMode ? 'Vista completa' : 'Modo navegacion',
                    color: AppColors.statusSyncing,
                    onPressed: () {
                      setState(() {
                        _navigationMode = !_navigationMode;
                      });
                      if (_navigationMode) {
                        _centerMapOnRoute();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OperationalMapActionChip(
                    svg: operationalAlertSvg,
                    label: 'Reportar',
                    color: AppColors.alertWarning,
                    onPressed: _mostrarCrearAlerta,
                  ),
                  if (_simulationController != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    OperationalMapActionChip(
                      svg: operationalRefreshSvg,
                      label:
                          _simulationController!.isOffline
                              ? 'Recuperar señal'
                              : 'Sin señal',
                      color: AppColors.statusStale,
                      onPressed:
                          _simulationController!.isOffline
                              ? _recuperarSenalSimulada
                              : _simularPerdidaSenal,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OperationalMapActionChip(
                      svg: operationalCrosshairSvg,
                      label: 'Reanudar ruta',
                      color: AppColors.emerald400,
                      onPressed: () => _requestOperationalReroute(manual: true),
                    ),
                  ],
                  if (_alertasEnRuta.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.xs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_alertasEnRuta.length} alertas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    final tripStatus = _viajeIniciado ? 'en_ruta' : widget.oportunidad.estado;

    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.sheetRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OperationalStatusChip.tracking(tripStatus),
                    const Spacer(),
                    if (_routeAssessment?.corridorAlerts.isNotEmpty == true)
                      Text(
                        '${_routeAssessment!.corridorAlerts.length} alerta(s) en corredor',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                if (_routeAssessment != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildRouteHealthSummary(_routeAssessment!),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(
                      Icons.flag,
                      color: AppColors.mapMarkerDestination,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destino',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            widget.oportunidad.destino,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),

                // Información de la ruta
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.straighten,
                      '${_distanciaKm!.toStringAsFixed(1)} km',
                      'Distancia',
                    ),
                    _buildStatItem(
                      Icons.access_time,
                      _duracionTexto!,
                      'Duración ruta',
                    ),
                    _buildStatItem(
                      Icons.attach_money,
                      '\$${widget.oportunidad.precio.toStringAsFixed(0)}',
                      'Pago',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _centerMapOnRoute,
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Centrar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child:
                          _routeAssessment?.rerouteRecommended == true
                              ? FilledButton.icon(
                                onPressed: () => _requestOperationalReroute(),
                                icon: const Icon(Icons.alt_route),
                                label: const Text('Recalcular seguro'),
                              )
                              : _viajeIniciado
                              ? OutlinedButton.icon(
                                onPressed:
                                    () => _requestOperationalReroute(
                                      manual: true,
                                    ),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Verificar ruta'),
                              )
                              : FilledButton.icon(
                                onPressed: _iniciarViaje,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Iniciar viaje'),
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _activarSeguimientoRuta,
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Seguir ruta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationControlPanel(SimulationSnapshot snapshot) {
    final statusLabel = switch (snapshot.status) {
      SimulationStatus.running => 'EN RUTA',
      SimulationStatus.stopped => 'DETENIDO',
      SimulationStatus.signalLost => 'SIN CONEXIÓN',
      SimulationStatus.deviating => 'DESVIADO',
      SimulationStatus.completed => 'COMPLETADO',
      SimulationStatus.idle => 'LISTO',
    };
    final healthLabel =
        _routeAssessment?.health.name.toUpperCase() ?? 'PENDIENTE';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.graphite950.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.emerald400.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: AppColors.emerald300),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Simulación operacional',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:
                      snapshot.status == SimulationStatus.signalLost
                          ? AppColors.statusStale
                          : AppColors.emerald300,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _SimulationMetric(
                label: '${snapshot.speedKmh.toStringAsFixed(0)} km/h',
                caption: 'Velocidad',
              ),
              _SimulationMetric(
                label: '${snapshot.distanceRemainingKm.toStringAsFixed(1)} km',
                caption: 'Restante',
              ),
              _SimulationMetric(
                label: _formatEta(snapshot.eta),
                caption: 'ETA',
              ),
              _SimulationMetric(
                label:
                    '${(snapshot.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                caption: 'Progreso',
              ),
              _SimulationMetric(label: healthLabel, caption: 'Ruta'),
            ],
          ),
          if (snapshot.stopReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Vehículo detenido en ${snapshot.stopReason}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.graphite200,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (snapshot.synchronizing) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                onPressed: _mostrarSelectorDetencion,
                child: const Text('DETENER VIAJE'),
              ),
              OutlinedButton(
                onPressed: _resumeSimulation,
                child: const Text('CONTINUAR'),
              ),
              OutlinedButton(
                onPressed: _simularDesvioRuta,
                child: const Text('DESVIARSE'),
              ),
              FilledButton.tonal(
                onPressed: () => _simulationController?.finishNearDestination(),
                child: const Text('FINALIZAR RUTA'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatEta(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes.remainder(60);
      return '${duration.inHours}h ${minutes}m';
    }
    return '${duration.inMinutes} min';
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildRouteHealthSummary(OperationalRouteAssessment assessment) {
    final color = switch (assessment.health) {
      RouteHealthState.healthy => AppColors.statusActive,
      RouteHealthState.caution ||
      RouteHealthState.stale => AppColors.statusStale,
      RouteHealthState.degraded ||
      RouteHealthState.invalid => AppColors.alertCritical,
      RouteHealthState.rerouting => AppColors.alertInfo,
      RouteHealthState.offline => AppColors.graphite700,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: color, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  assessment.userMessage,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Distancia al corredor: ${assessment.distanceFromRouteMeters.isFinite ? assessment.distanceFromRouteMeters.round() : 0} m',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationHud() {
    final statusColor =
        _viajeIniciado ? AppColors.statusActive : AppColors.statusSyncing;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.graphite950.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _viajeIniciado
                        ? 'Navegando hacia ${widget.oportunidad.destino}'
                        : 'Ruta lista para iniciar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _duracionTexto ?? '--',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _centerMapOnRoute,
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Centrar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _activarSeguimientoRuta,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Seguir ruta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestOperationalReroute({bool manual = false}) async {
    final current = _currentPosition;
    final destination = _destinoPosition;
    if (current == null || destination == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    if (_connectivityHealth != ConnectivityHealth.internetReachable) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Sin conexión al backend. Se conserva la ruta actual y se difiere el recálculo.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      _evaluateRoutingState();
      return;
    }

    if (!_routingController.canAttemptReroute(now, manual: manual)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Recálculo espaciado para evitar tormentas de rutas.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final trigger =
        manual ? RerouteTrigger.manual : _routeAssessment?.rerouteTrigger;
    _routingController.markRerouteStarted(trigger ?? RerouteTrigger.manual);
    _evaluateRoutingState();

    try {
      final routeData = await ORSService.obtenerRuta(current, destination);
      final candidate = List<LatLng>.from(routeData['coordinates'] as List);
      if (candidate.length < 2) {
        throw Exception('El proveedor no retornó geometría suficiente');
      }

      if (!mounted) return;
      setState(() {
        _rerouteCandidatePoints = candidate;
      });

      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;

      setState(() {
        _routePoints = candidate;
        _distanciaKm = routeData['distance'] as double;
        final duration = routeData['duration'] as int;
        _duracionTexto =
            duration >= 60
                ? '${(duration / 60).toStringAsFixed(1)} h'
                : '$duration min';
        _rerouteCandidatePoints = [];
      });
      _routingController.replaceRoute(candidate);
      _routingController.markRerouteFinished(success: true);
      _evaluateRoutingState();
      _centerMapOnRoute();
      await _cargarAlertasEnRuta();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ruta recalculada con proveedor real.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _routingController.markRerouteFinished(success: false);
      if (!mounted) return;
      setState(() {
        _rerouteCandidatePoints = [];
      });
      _evaluateRoutingState();
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo recalcular ruta real: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarInformacionViaje() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Información del viaje'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Origen: ${widget.oportunidad.origen}'),
                Text('Destino: ${widget.oportunidad.destino}'),
                if (_distanciaKm != null)
                  Text('Distancia: ${_distanciaKm!.toStringAsFixed(1)} km'),
                if (_duracionTexto != null)
                  Text('Duración de ruta: $_duracionTexto'),
                Text(
                  'Precio: \$${widget.oportunidad.precio.toStringAsFixed(0)}',
                ),
                if (widget.oportunidad.descripcion != null)
                  Text('Descripción: ${widget.oportunidad.descripcion}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  Future<void> _iniciarViajeSimulado(LocationService locationService) async {
    if (widget.oportunidad.id == null || _routePoints.length < 2) return;

    final speed = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _SimulationSpeedSheet(distanceKm: _distanciaKm ?? 0),
    );
    if (speed == null || !mounted) return;

    try {
      Oportunidad tripInRoute;
      try {
        tripInRoute = await OportunidadService.iniciarViaje(
          widget.oportunidad.id!,
        );
      } catch (_) {
        await OportunidadService.aceptarOportunidad(widget.oportunidad.id!);
        tripInRoute = await OportunidadService.iniciarViaje(
          widget.oportunidad.id!,
        );
      }
      if (!mounted) return;
      context.read<TripStore>().setSimulationActiveTrip(tripInRoute);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar el viaje simulado: $error')),
      );
      return;
    }

    final controller = SimulationRouteController(
      locationService: locationService,
      oportunidadId: widget.oportunidad.id!,
      routePoints: _routePoints,
    );
    _bindSimulationController(controller);

    setState(() {
      _viajeIniciado = true;
      _navigationMode = true;
    });
    await locationService.startTracking();
    await _cargarAlertasEnRuta();
    await controller.start(speedKmh: speed);
    await SimulationStateCache.save(
      oportunidadId: widget.oportunidad.id!,
      state: controller.exportState(),
    );
  }

  Future<void> _simularPerdidaSenal() async {
    await _simulationController?.simulateSignalLoss();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SIN CONEXIÓN: posiciones guardadas en cola offline.'),
      ),
    );
  }

  Future<void> _recuperarSenalSimulada() async {
    await _simulationController?.recoverSignal();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Señal recuperada. Replay de SyncEngine ejecutado.'),
      ),
    );
  }

  Future<void> _simularDesvioRuta() async {
    final current = _currentPosition;
    if (current == null) return;
    final deviation = LatLng(
      current.latitude + 0.006,
      current.longitude + 0.006,
    );
    await _simulationController?.deviateToward(deviation);
    _evaluateRoutingState(deviation);
  }

  Future<void> _mostrarSelectorDetencion() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _StopReasonSheet(),
    );
    if (reason == null) return;
    _simulationController?.stopWithReason(reason);
  }

  Future<bool> _completarViajeEnServidor() async {
    if (_completionSynced || widget.oportunidad.id == null) {
      return _completionSynced;
    }

    try {
      await OportunidadService.confirmarEntrega(widget.oportunidad.id!);
      _completionSynced = true;
      final auth = context.read<AuthService>();
      if (auth.isSimulationSession) {
        await auth.bumpSimulationCompletedTrip();
      }
      await SimulationStateCache.clear(widget.oportunidad.id!);
      context.read<TripStore>().clearActiveTrip();
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo confirmar la entrega en servidor: $error'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<void> _mostrarResumenCompletado(SimulationSnapshot snapshot) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.graphite950,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: AppColors.emerald400.withValues(alpha: 0.28),
              ),
            ),
            icon: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.emerald400.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: AppColors.emerald300,
                size: 30,
              ),
            ),
            title: const Text(
              'Llegada confirmada',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'La carga fue marcada como entregada. El contratista puede calificar el servicio desde su panel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.graphite300),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Distancia: ${(_distanciaKm ?? 0).toStringAsFixed(1)} km',
                  style: const TextStyle(color: AppColors.graphite200),
                ),
                Text(
                  'Paradas: ${snapshot.stopsMade} · Alertas: ${snapshot.alertsCreated}',
                  style: const TextStyle(color: AppColors.graphite200),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _informarLlegadaWhatsApp,
                child: const Text('WhatsApp'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald500,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (Navigator.of(this.context).canPop()) {
                    Navigator.of(this.context).pop();
                  }
                },
                child: const Text('Finalizar'),
              ),
            ],
          ),
    );
  }

  Future<void> _informarLlegadaWhatsApp() async {
    final tripId = widget.oportunidad.id ?? 'SIMULACION';
    final message = Uri.encodeComponent(
      'Hola.\n\n'
      'El viaje #$tripId ha sido completado exitosamente.\n\n'
      'La carga ha llegado al destino.\n\n'
      'Gracias por utilizar TrackNariño.',
    );
    final uri = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _iniciarViaje() async {
    try {
      final locationService = Provider.of<LocationService>(
        context,
        listen: false,
      );
      final auth = context.read<AuthService>();

      if (auth.isSimulationSession) {
        await _iniciarViajeSimulado(locationService);
        return;
      }

      // Mostrar diálogo de confirmación con detalles del viaje
      final confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Confirmar inicio de viaje'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Estás listo para iniciar este viaje?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    Icons.route,
                    'Distancia',
                    '${_distanciaKm?.toStringAsFixed(1) ?? '0'} km',
                  ),
                  _buildDetailRow(
                    Icons.access_time,
                    'Duración',
                    _duracionTexto ?? '0 min',
                  ),
                  _buildDetailRow(
                    Icons.location_on,
                    'Destino',
                    widget.oportunidad.destino,
                  ),
                  _buildDetailRow(
                    Icons.attach_money,
                    'Pago',
                    '\$${widget.oportunidad.precio.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recuerda reportar cualquier incidente durante el viaje',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('¡Iniciar viaje!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
      );

      if (confirmar == true && mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        try {
          await OportunidadService.iniciarViaje(widget.oportunidad.id!);

          setState(() {
            _viajeIniciado = true;
          });

          // Iniciar tracking de ubicación
          await locationService.startTracking();

          // Cargar alertas en la ruta
          await _cargarAlertasEnRuta();

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '¡Viaje iniciado!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Duración de ruta: $_duracionTexto • ${_routeAssessment?.corridorAlerts.length ?? 0} alertas en corredor',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Seguir',
                textColor: Colors.white,
                onPressed: _activarSeguimientoRuta,
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } on TripActionQueuedException catch (e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
          );
        } catch (e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error al iniciar viaje: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al mostrar diálogo: $e');
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarAlertasEnRuta() async {
    try {
      // Buscar alertas cercanas a toda la ruta
      if (_routePoints.isNotEmpty) {
        // Obtener alertas cercanas al punto medio de la ruta
        final puntoMedio = _routePoints[_routePoints.length ~/ 2];
        final geoPosition = Position(
          latitude: puntoMedio.latitude,
          longitude: puntoMedio.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        final alertas = await AlertaService.obtenerAlertasCercanas(geoPosition);

        if (mounted) {
          setState(() {
            _alertasEnRuta = alertas;
          });
          _evaluateRoutingState();
        }
      }
    } catch (e) {
      debugPrint('Error al cargar alertas: $e');
    }
  }

  IconData _getAlertaIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'trancon':
        return Icons.traffic;
      case 'sospecha':
        return Icons.remove_red_eye;
      case 'intento_robo':
        return Icons.warning;
      case 'robo':
        return Icons.dangerous;
      case 'obstaculo':
        return Icons.block;
      case 'accidente':
        return Icons.car_crash;
      case 'trafico':
        return Icons.traffic;
      case 'obra':
        return Icons.construction;
      case 'policia':
        return Icons.local_police;
      case 'peligro':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  void _mostrarDetalleAlerta(AlertaSeguridad alerta) {
    final meta = OperationalAlertMeta.fromType(alerta.tipo);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (dialogContext) => Material(
            elevation: 14,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.sheetRadius),
            ),
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      meta.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      alerta.descripcion ?? 'Sin descripción operativa',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Reportado por ${alerta.usuario}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _mostrarCrearAlerta() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esperando ubicación GPS...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final descripcionController = TextEditingController();
    String tipoSeleccionado = 'accidente';

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_alert, color: Colors.orange),
                SizedBox(width: 8),
                Text('Crear Alerta de Seguridad'),
              ],
            ),
            content: StatefulBuilder(
              builder:
                  (context, setDialogState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tipo de alerta:'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: tipoSeleccionado,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items:
                            [
                                  {'value': 'accidente', 'label': 'Accidente'},
                                  {'value': 'bloqueo', 'label': 'Bloqueo'},
                                  {'value': 'derrumbe', 'label': 'Derrumbe'},
                                  {'value': 'robo', 'label': 'Robo'},
                                  {'value': 'protesta', 'label': 'Protesta'},
                                  {
                                    'value': 'mal_estado_via',
                                    'label': 'Mal estado de vía',
                                  },
                                  {'value': 'clima', 'label': 'Clima'},
                                  {'value': 'otro', 'label': 'Otro'},
                                ]
                                .map(
                                  (tipo) => DropdownMenuItem(
                                    value: tipo['value'],
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getAlertaIcon(tipo['value']!),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(tipo['label']!),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              tipoSeleccionado = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Descripción:'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descripcionController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Describe el incidente...',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (descripcionController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor ingresa una descripción'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  try {
                    await AlertaService.crearAlerta(
                      tipo: tipoSeleccionado,
                      coords: {
                        'lat': _currentPosition!.latitude,
                        'lng': _currentPosition!.longitude,
                      },
                      descripcion: descripcionController.text.trim(),
                    );
                    _simulationController?.registerAlertCreated();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                _getAlertaIcon(tipoSeleccionado),
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Alerta guardada. Pendiente de sincronización.',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 3),
                        ),
                      );

                      // Recargar alertas
                      await _cargarAlertasEnRuta();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al crear alerta: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Crear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _llamarSOS() async {
    // Mostrar diálogo de confirmación antes de llamar
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.sos, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Text('Llamada de Emergencia'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Estás seguro de llamar al 112?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Número de emergencias: 112',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Úsalo solo en caso de emergencia real',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.phone),
                label: const Text('Llamar al 112'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      try {
        final Uri phoneUri = Uri(scheme: 'tel', path: '112');

        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.phone, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('Iniciando llamada al 112...')),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          throw 'No se puede realizar la llamada';
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al llamar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _activarSeguimientoRuta() {
    if (!mounted) return;
    setState(() {
      _isFollowingVehicle = true;
      _navigationMode = true;
    });

    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 16.2);
    } else {
      _centerMapOnRoute();
    }
  }
}

class _SimulationSpeedSheet extends StatelessWidget {
  final double distanceKm;

  const _SimulationSpeedSheet({required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    const speeds = [30.0, 60.0, 90.0, 120.0, 150.0, 200.0];
    return Material(
      color: AppColors.graphite950,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.sheetRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seleccionar velocidad de simulación',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'El ETA se calcula contra la distancia real de la ruta.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children:
                    speeds.map((speed) {
                      final etaMinutes =
                          distanceKm <= 0
                              ? 0
                              : ((distanceKm / speed) * 60).round();
                      return FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(speed),
                        child: Text(
                          '${speed.toStringAsFixed(0)} km/h · $etaMinutes min',
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopReasonSheet extends StatelessWidget {
  final List<String> reasons = const [
    'Gasolinera',
    'Hotel',
    'Restaurante',
    'Taller',
    'Peaje',
    'Descanso',
    'Emergencia',
    'Otro',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.graphite950,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.sheetRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Motivo de detención',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children:
                    reasons
                        .map(
                          (reason) => OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(reason),
                            child: Text(reason),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimulationMetric extends StatelessWidget {
  final String label;
  final String caption;

  const _SimulationMetric({required this.label, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            caption,
            style: const TextStyle(
              color: AppColors.graphite300,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

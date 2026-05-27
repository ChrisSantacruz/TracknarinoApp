import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:url_launcher/url_launcher.dart';

import '../../models/fleet_tracking_item.dart';
import '../../models/trucker_place.dart';
import '../../map/operational_map_intelligence.dart';
import '../../services/contratista_tracking_service.dart';
import '../../services/narino_trucker_places_service.dart';
import '../../services/polling_controller.dart';
import '../../services/realtime_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/fleet_map_marker.dart';
import '../../widgets/operational/map_control_cluster.dart';
import '../../widgets/operational/operational_empty_state.dart';
import '../../widgets/operational/operational_map_primitives.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../widgets/operational/operational_status_chip.dart';
import '../../widgets/operational/realtime_connection_chip.dart';

class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen({super.key});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  static const Duration _fallbackPollInterval = Duration(seconds: 10);
  static const Duration _socketHealthyPollInterval = Duration(seconds: 60);
  static const double _minimumMarkerMoveMeters = 8;
  static const latlong.LatLng _defaultCenter = latlong.LatLng(1.2136, -77.2811);

  final MapController _mapController = MapController();
  final PollingController _polling = PollingController();
  final RealtimeService _realtime = RealtimeService.instance;
  final OperationalMapDiagnostics _mapDiagnostics = OperationalMapDiagnostics();
  final Map<String, Map<String, dynamic>> _camioneros = {};
  final Set<String> _seenRealtimeEvents = {};
  StreamSubscription<RealtimeConnectionStatus>? _connectionSubscription;
  StreamSubscription<RealtimeTrackingUpdate>? _trackingSubscription;
  StreamSubscription<RealtimeTripUpdate>? _tripSubscription;

  bool _initialLoading = true;
  bool _backgroundRefreshing = false;
  String _errorMessage = '';
  String _emptyMessage = '';
  String? _camioneroSeleccionadoId;
  int _fleetTotal = 0;
  int _activeCount = 0;
  int _staleCount = 0;
  int _offlineCount = 0;
  int _noLocationCount = 0;
  int _activeTripCount = 0;
  final Set<String> _visibleStates = {'active', 'stale', 'offline'};
  bool _activeTripsOnly = false;
  bool _showFleetDensity = false;
  bool _showTruckerPlaces = true;
  bool _followSelectedVehicle = true;
  List<TruckerPlace> _truckerPlaces = [];
  latlong.LatLng _mapCenter = _defaultCenter;
  double _mapZoom = 12;
  DateTime? _lastViewportUpdateAt;
  RealtimeConnectionStatus _realtimeStatus =
      RealtimeConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _wireRealtime();
    _loadFleet(initial: true);
    _loadTruckerPlaces();
    _startPolling(socketHealthy: false);
    _realtime.connect();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _trackingSubscription?.cancel();
    _tripSubscription?.cancel();
    _polling.stop();
    super.dispose();
  }

  void _wireRealtime() {
    _connectionSubscription = _realtime.connectionStream.listen((status) {
      if (!mounted) return;
      final socketHealthy = status == RealtimeConnectionStatus.connected;
      setState(() => _realtimeStatus = status);
      _startPolling(socketHealthy: socketHealthy);
      if (socketHealthy) _realtime.subscribeFleet();
    });

    _trackingSubscription = _realtime.trackingUpdates.listen(
      _applyRealtimeTrackingUpdate,
    );
    _tripSubscription = _realtime.tripUpdates.listen(
      (_) => _loadFleet(initial: false),
    );
  }

  void _startPolling({required bool socketHealthy}) {
    _polling.start(
      interval:
          socketHealthy ? _socketHealthyPollInterval : _fallbackPollInterval,
      immediate: false,
      onTick: () => _loadFleet(initial: false),
    );
  }

  Future<void> _loadFleet({required bool initial}) async {
    if (!mounted) return;

    if (initial) {
      setState(() {
        _initialLoading = true;
        _errorMessage = '';
        _emptyMessage = '';
      });
    } else {
      setState(() => _backgroundRefreshing = true);
    }

    try {
      final fleet = await ContratistaTrackingService.fetchFleet();
      if (!mounted) return;

      final Map<String, Map<String, dynamic>> camioneros = {};
      var activeCount = 0;
      var staleCount = 0;
      var offlineCount = 0;
      var noLocationCount = 0;
      var activeTripCount = 0;

      for (final item in fleet) {
        final estado = _mapTrackingStatus(item);
        if (estado == 'active') activeCount += 1;
        if (estado == 'stale') staleCount += 1;
        if (estado == 'offline') offlineCount += 1;
        if (!item.hasLocation || !item.coordinatesValid) noLocationCount += 1;
        if (item.hasActiveTrip) activeTripCount += 1;

        if (!item.hasLocation ||
            item.ubicacion == null ||
            !item.coordinatesValid) {
          continue;
        }

        final coord = item.ubicacion!;
        final point = latlong.LatLng(coord.lat, coord.lng);
        final pollTimestamp =
            item.lastSeenAt ?? item.serverReceivedAt ?? DateTime.now();

        final existing = _camioneros[item.camioneroId];
        if (existing != null) {
          final existingTs = existing['ultimaActualizacion'] as DateTime?;
          if (existingTs != null && existingTs.isAfter(pollTimestamp)) {
            camioneros[item.camioneroId] = Map<String, dynamic>.from(existing);
            continue;
          }
        }

        camioneros[item.camioneroId] = {
          'id': item.camioneroId,
          'nombre': item.nombre,
          'telefono': item.telefono,
          'placaVehiculo': item.placaVehiculo,
          'ubicacion': point,
          'rumbo': item.heading,
          'estado': estado,
          'isStale': item.isStale,
          'isOffline': item.isOffline,
          'ultimaActualizacion': pollTimestamp,
          'origen': item.origenViaje,
          'destino': item.destinoViaje,
          'carga': item.carga,
          'hasActiveTrip': item.hasActiveTrip,
          'originPoint': item.originPoint,
          'destinationPoint': item.destinationPoint,
        };
      }

      setState(() {
        _camioneros
          ..clear()
          ..addAll(camioneros);
        _initialLoading = false;
        _backgroundRefreshing = false;
        _errorMessage = '';
        _emptyMessage =
            camioneros.isEmpty
                ? 'Sin vehículos activos con ubicación verificable en este momento.'
                : '';
        _fleetTotal = fleet.length;
        _activeCount = activeCount;
        _staleCount = staleCount;
        _offlineCount = offlineCount;
        _noLocationCount = noLocationCount;
        _activeTripCount = activeTripCount;
      });

      if (_followSelectedVehicle &&
          _camioneroSeleccionadoId != null &&
          camioneros.containsKey(_camioneroSeleccionadoId)) {
        _centerOnCamionero(_camioneroSeleccionadoId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (initial) {
          _errorMessage = 'Error al cargar ubicaciones: $e';
        }
        _initialLoading = false;
        _backgroundRefreshing = false;
        if (initial) _emptyMessage = '';
      });
    }
  }

  Future<void> _loadTruckerPlaces() async {
    try {
      final places = await NarinoTruckerPlacesService.fetchPlaces(
        categories: TruckerPlaceCategory.values.toSet(),
      );
      if (!mounted) return;
      setState(() => _truckerPlaces = places);
    } catch (_) {
      if (!mounted) return;
      setState(() => _truckerPlaces = []);
    }
  }

  String _mapTrackingStatus(FleetTrackingItem item) {
    if (item.isOffline) return 'offline';
    if (item.isStale) return 'stale';
    if (item.hasLocation && item.coordinatesValid) return 'active';
    return item.trackingStatus;
  }

  void _applyRealtimeTrackingUpdate(RealtimeTrackingUpdate update) {
    if (!mounted) return;
    if (update.eventId.isNotEmpty) {
      if (_seenRealtimeEvents.contains(update.eventId)) return;
      _seenRealtimeEvents.add(update.eventId);
      if (_seenRealtimeEvents.length > 300) {
        _seenRealtimeEvents.remove(_seenRealtimeEvents.first);
      }
    }

    final camionero = _camioneros[update.camioneroId];
    if (camionero == null) {
      _loadFleet(initial: false);
      return;
    }

    final updatedPoint = latlong.LatLng(update.lat, update.lng);
    final previousPoint = camionero['ubicacion'] as latlong.LatLng;
    final nextStatus =
        update.isOffline
            ? 'offline'
            : update.isStale
            ? 'stale'
            : update.trackingStatus;
    final movedMeters = const latlong.Distance().as(
      latlong.LengthUnit.Meter,
      previousPoint,
      updatedPoint,
    );
    final headingChanged =
        update.heading != null &&
        ((update.heading! - (camionero['rumbo'] as double)).abs() >= 8);
    final statusChanged = camionero['estado'] != nextStatus;
    final selected = _camioneroSeleccionadoId == update.camioneroId;

    if (!selected &&
        !statusChanged &&
        !headingChanged &&
        movedMeters < _minimumMarkerMoveMeters) {
      camionero['ultimaActualizacion'] = update.timestamp;
      return;
    }

    setState(() {
      camionero['ubicacion'] = updatedPoint;
      camionero['rumbo'] = update.heading ?? camionero['rumbo'];
      camionero['estado'] = nextStatus;
      camionero['isStale'] = update.isStale;
      camionero['isOffline'] = update.isOffline;
      camionero['ultimaActualizacion'] = update.timestamp;
      _emptyMessage = '';
      _recalculateVisibleFleetCounts();
    });

    if (_followSelectedVehicle &&
        _camioneroSeleccionadoId == update.camioneroId &&
        !update.isOffline) {
      _moveCameraIfMeaningful(updatedPoint, _mapController.zoom);
    }
  }

  void _recalculateVisibleFleetCounts() {
    var activeCount = 0;
    var staleCount = 0;
    var offlineCount = 0;

    for (final camionero in _camioneros.values) {
      final estado = camionero['estado'] as String;
      if (estado == 'active') activeCount += 1;
      if (estado == 'stale') staleCount += 1;
      if (estado == 'offline') offlineCount += 1;
    }

    _activeCount = activeCount;
    _staleCount = staleCount;
    _offlineCount = offlineCount;
  }

  void _centerOnCamionero(String id) {
    final camionero = _camioneros[id];
    if (camionero == null) return;
    final point = camionero['ubicacion'] as latlong.LatLng;
    _mapController.move(point, 16);
  }

  void _moveCameraIfMeaningful(latlong.LatLng point, double zoom) {
    final distance = const latlong.Distance().as(
      latlong.LengthUnit.Meter,
      _mapController.center,
      point,
    );
    if (distance < 25 && (zoom - _mapController.zoom).abs() < 0.2) return;
    _mapController.move(point, zoom);
  }

  Iterable<Map<String, dynamic>> get _visibleCamioneros {
    return _camioneros.values.where((camionero) {
      final estado = camionero['estado'] as String;
      final activeTrip = camionero['hasActiveTrip'] as bool;
      return _visibleStates.contains(estado) &&
          (!_activeTripsOnly || activeTrip);
    });
  }

  Map<String, dynamic>? get _selectedCamionero {
    final id = _camioneroSeleccionadoId;
    if (id == null) return null;
    return _camioneros[id];
  }

  List<latlong.LatLng> _selectedRoutePoints(Map<String, dynamic>? camionero) {
    if (camionero == null || camionero['hasActiveTrip'] != true) {
      return const [];
    }
    final current = camionero['ubicacion'] as latlong.LatLng?;
    final destination = camionero['destinationPoint'] as dynamic;
    if (current == null || destination == null) return const [];
    return [
      current,
      latlong.LatLng(destination.lat as double, destination.lng as double),
    ];
  }

  String? _normalizedPhone(Map<String, dynamic> camionero) {
    final raw = (camionero['telefono'] ?? '').toString();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return digits.startsWith('57') ? digits : '57$digits';
  }

  Future<void> _launchPhone(Map<String, dynamic> camionero) async {
    final phone = _normalizedPhone(camionero);
    if (phone == null) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _launchWhatsApp(Map<String, dynamic> camionero) async {
    final phone = _normalizedPhone(camionero);
    if (phone == null) return;
    final uri = Uri.https('wa.me', '/$phone', {
      'text': 'Hola, te contacto desde TrackNariño por tu viaje activo.',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _seleccionarCamionero(String id) {
    setState(() {
      _camioneroSeleccionadoId = id;
      _followSelectedVehicle = true;
    });
    _centerOnCamionero(id);
  }

  void _mostrarDetallesCamionero(Map<String, dynamic> camionero) {
    _seleccionarCamionero(camionero['id'] as String);
    final estado = camionero['estado'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.28,
          maxChildSize: 0.72,
          builder: (_, controller) {
            return Material(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.sheetRadius),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Center(
                    child: Container(
                      height: 5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.trackingStatusColor(estado),
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              camionero['nombre'] as String,
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            OperationalStatusChip.tracking(estado),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _routeBlock(camionero),
                  const Divider(height: AppSpacing.xl),
                  _buildInfoRow('Placa', camionero['placaVehiculo'] as String),
                  _buildInfoRow('Teléfono', camionero['telefono'] as String),
                  _buildInfoRow('Carga', camionero['carga'] as String),
                  _buildInfoRow(
                    'Última actualización',
                    _formatTimeDifference(
                      camionero['ultimaActualizacion'] as DateTime,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _centerOnCamionero(camionero['id'] as String);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('Ver en mapa'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _launchWhatsApp(camionero),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _launchPhone(camionero),
                      icon: const Icon(Icons.phone_outlined),
                      label: Text('Llamar ${camionero['telefono']}'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _routeBlock(Map<String, dynamic> camionero) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.string(
                operationalCrosshairSvg,
                width: 16,
                height: 16,
                color: AppColors.statusActive,
                semanticsLabel: 'Origen',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(camionero['origen'] as String)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.string(
                operationalAlertSvg,
                width: 16,
                height: 16,
                color: AppColors.mapMarkerDestination,
                semanticsLabel: 'Destino',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(camionero['destino'] as String)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatTimeDifference(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    return 'Hace ${difference.inDays} días';
  }

  latlong.LatLng? _fleetCenter() {
    final visible = _visibleCamioneros.toList();
    if (visible.isEmpty) return null;
    var sumLat = 0.0;
    var sumLng = 0.0;
    var count = 0;
    for (final c in visible) {
      final p = c['ubicacion'] as latlong.LatLng;
      sumLat += p.latitude;
      sumLng += p.longitude;
      count += 1;
    }
    if (count == 0) return null;
    return latlong.LatLng(sumLat / count, sumLng / count);
  }

  void _fitVisibleFleet() {
    final points =
        _visibleCamioneros
            .map((camionero) => camionero['ubicacion'] as latlong.LatLng)
            .toList();
    if (points.isEmpty) {
      _mapController.move(_defaultCenter, 12);
      return;
    }
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(padding: EdgeInsets.all(72), maxZoom: 15),
    );
  }

  void _expandFleetCluster(OperationalFleetCluster cluster) {
    final points = cluster.points.map((point) => point.point).toList();
    if (points.length < 2) {
      _mapController.move(
        cluster.center,
        (_mapController.zoom + 1.2).clamp(10, 17).toDouble(),
      );
      return;
    }
    _mapController.fitBounds(
      LatLngBounds.fromPoints(points),
      options: const FitBoundsOptions(padding: EdgeInsets.all(88), maxZoom: 16),
    );
  }

  List<Marker> _buildMarkers(OperationalFleetRenderPlan plan) {
    final clusterMarkers = plan.clusters.map((cluster) {
      return Marker(
        point: cluster.center,
        width: 54,
        height: 54,
        builder:
            (ctx) => OperationalFleetClusterMarker(
              cluster: cluster,
              onTap: () => _expandFleetCluster(cluster),
            ),
      );
    });

    final truckMarkers = plan.markers.map((fleetPoint) {
      final camionero = fleetPoint.source;
      final point = fleetPoint.point;
      final estado = camionero['estado'] as String;
      final nombre = camionero['nombre'] as String;
      final selected = _camioneroSeleccionadoId == camionero['id'];
      final heading = camionero['rumbo'] as double;

      return Marker(
        point: point,
        width: selected ? 46 : 42,
        height: selected ? 46 : 42,
        builder:
            (ctx) => GestureDetector(
              onTap: () => _mostrarDetallesCamionero(camionero),
              child: Semantics(
                button: true,
                label:
                    '$nombre, ${AppColors.trackingStatusLabel(estado)}, ${_formatTimeDifference(camionero['ultimaActualizacion'] as DateTime)}',
                child: FleetMapMarker(
                  status: estado,
                  initial: nombre,
                  heading: heading,
                  selected: selected,
                ),
              ),
            ),
      );
    });

    return [...clusterMarkers, ...truckMarkers];
  }

  List<Marker> _buildTruckerPlaceMarkers() {
    if (!_showTruckerPlaces) return const [];
    return _truckerPlaces.map((place) {
      return Marker(
        point: latlong.LatLng(
          place.position.latitude,
          place.position.longitude,
        ),
        width: 34,
        height: 34,
        builder:
            (_) => Tooltip(
              message: '${place.category.label}: ${place.name}',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.graphite950.withValues(alpha: 0.94),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: place.category.color.withValues(alpha: 0.78),
                  ),
                ),
                child: Icon(
                  place.category.icon,
                  color: place.category.color,
                  size: 18,
                ),
              ),
            ),
      );
    }).toList();
  }

  void _toggleStateFilter(String status) {
    setState(() {
      if (_visibleStates.contains(status)) {
        if (_visibleStates.length == 1) return;
        _visibleStates.remove(status);
      } else {
        _visibleStates.add(status);
      }
      if (_selectedCamionero != null &&
          !_visibleStates.contains(_selectedCamionero!['estado'] as String)) {
        _camioneroSeleccionadoId = null;
      }
    });
  }

  void _handleMapPositionChanged(MapPosition position, bool hasGesture) {
    final nextCenter = position.center;
    final nextZoom = position.zoom;
    if (nextCenter == null && nextZoom == null) return;

    final now = DateTime.now();
    final center = nextCenter ?? _mapCenter;
    final zoom = nextZoom ?? _mapZoom;
    final movedMeters = const latlong.Distance().as(
      latlong.LengthUnit.Meter,
      _mapCenter,
      center,
    );
    final shouldRefreshPlan =
        _lastViewportUpdateAt == null ||
        now.difference(_lastViewportUpdateAt!).inMilliseconds >= 160 ||
        movedMeters >= 90 ||
        (zoom - _mapZoom).abs() >= 0.25;

    if (!shouldRefreshPlan && !(hasGesture && _followSelectedVehicle)) return;

    setState(() {
      _mapCenter = center;
      _mapZoom = zoom;
      _lastViewportUpdateAt = now;
      if (hasGesture && _followSelectedVehicle) {
        _followSelectedVehicle = false;
      }
    });
  }

  Widget _buildFleetSummaryCard() {
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(22),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      child: Container(
        width: 248,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Flota operativa',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_backgroundRefreshing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _fleetTotal == 0
                  ? 'Esperando sincronización'
                  : '$_fleetTotal vehículos vinculados',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _summaryMetric('Activos', _activeCount, AppColors.statusActive),
                _summaryMetric('Antigua', _staleCount, AppColors.statusStale),
                _summaryMetric(
                  'Sin señal',
                  _offlineCount,
                  AppColors.statusOffline,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Viajes activos: $_activeTripCount · Sin ubicación: $_noLocationCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(String label, int value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalFilters() {
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filterChip('active', 'Activos', AppColors.statusActive),
            _filterChip('stale', 'Antigua', AppColors.statusStale),
            _filterChip('offline', 'Sin señal', AppColors.statusOffline),
            _booleanFilterChip(
              selected: _activeTripsOnly,
              label: 'En viaje',
              color: AppColors.deepGreen,
              onTap: () {
                setState(() {
                  _activeTripsOnly = !_activeTripsOnly;
                  if (_selectedCamionero != null &&
                      _activeTripsOnly &&
                      _selectedCamionero!['hasActiveTrip'] != true) {
                    _camioneroSeleccionadoId = null;
                  }
                });
              },
            ),
            _booleanFilterChip(
              selected: _showFleetDensity,
              label: 'Densidad',
              color: AppColors.statusSyncing,
              onTap:
                  () => setState(() => _showFleetDensity = !_showFleetDensity),
            ),
            _booleanFilterChip(
              selected: _showTruckerPlaces,
              label: 'Servicios',
              color: AppColors.emerald400,
              onTap:
                  () =>
                      setState(() => _showTruckerPlaces = !_showTruckerPlaces),
            ),
          ],
        ),
      ),
    );
  }

  Widget _booleanFilterChip({
    required bool selected,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color:
                  selected
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String status, String label, Color color) {
    final selected = _visibleStates.contains(status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => _toggleStateFilter(status),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: 0.34),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color:
                      selected
                          ? color
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeOverlay() {
    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RealtimeConnectionChip(status: _realtimeStatus),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _loadFleet(initial: false),
              icon:
                  _backgroundRefreshing
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : SvgPicture.string(
                        operationalRefreshSvg,
                        width: 20,
                        height: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                        semanticsLabel: 'Actualizar flota',
                      ),
              tooltip: 'Actualizar flota',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTruckSheet(Map<String, dynamic> camionero) {
    final estado = camionero['estado'] as String;
    final updatedAt = camionero['ultimaActualizacion'] as DateTime;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: Offset.zero,
      child: Material(
        elevation: 14,
        shadowColor: Colors.black.withValues(alpha: 0.24),
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
                Row(
                  children: [
                    FleetMapMarker(
                      status: estado,
                      initial: camionero['nombre'] as String,
                      heading: camionero['rumbo'] as double,
                      selected: true,
                      size: 46,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            camionero['nombre'] as String,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Última actualización ${_formatTimeDifference(updatedAt).toLowerCase()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed:
                          () => setState(() => _camioneroSeleccionadoId = null),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar detalle',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OperationalStatusChip.tracking(estado, compact: true),
                    RealtimeConnectionChip(status: _realtimeStatus),
                    OperationalStatusChip(
                      label:
                          (camionero['hasActiveTrip'] as bool)
                              ? 'Viaje activo'
                              : 'Sin viaje activo',
                      color:
                          (camionero['hasActiveTrip'] as bool)
                              ? AppColors.deepGreen
                              : AppColors.graphite700,
                      icon: Icons.route,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _routeBlock(camionero),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _compactInfo(
                        'Placa',
                        camionero['placaVehiculo'] as String,
                      ),
                    ),
                    Expanded(
                      child: _compactInfo(
                        'Carga',
                        camionero['carga'] as String,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _mostrarDetallesCamionero(camionero),
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('Ver detalle operativo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCamionero = _selectedCamionero;
    final selectedRoute = _selectedRoutePoints(selectedCamionero);
    final fleetPlan = OperationalMapIntelligence.buildFleetPlan(
      camioneros:
          _activeTripsOnly
              ? _camioneros.values.where(
                (camionero) => camionero['hasActiveTrip'] == true,
              )
              : _camioneros.values,
      mapCenter: _mapCenter,
      zoom: _mapZoom,
      visibleStates: _visibleStates,
      selectedId: _camioneroSeleccionadoId,
    );
    _mapDiagnostics.recordFleetPlan(fleetPlan);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _defaultCenter,
            zoom: 12,
            onPositionChanged: _handleMapPositionChanged,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            OperationalDensityCircleLayer(
              cells: fleetPlan.densityCells,
              color: AppColors.deepGreen,
              visible: _showFleetDensity,
            ),
            if (selectedRoute.length >= 2)
              OperationalRouteLayer(points: selectedRoute),
            MarkerLayer(
              markers: [
                ..._buildTruckerPlaceMarkers(),
                ..._buildMarkers(fleetPlan),
              ],
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: _buildFleetSummaryCard(),
        ),
        Positioned(
          right: AppSpacing.md,
          top: AppSpacing.md,
          child: _buildRealtimeOverlay(),
        ),
        Positioned(
          left: AppSpacing.md,
          top: 168,
          child: _buildOperationalFilters(),
        ),
        if (_initialLoading)
          const OperationalLoadingPanel(message: 'Cargando flota...'),
        if (!_initialLoading && _errorMessage.isNotEmpty)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 104,
            child: _FleetSyncErrorCard(
              onRetry: () => _loadFleet(initial: true),
            ),
          ),
        if (!_initialLoading &&
            _errorMessage.isEmpty &&
            _emptyMessage.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: OperationalEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'Sin vehículos activos en este momento',
                  message: _emptyMessage,
                  actionLabel: 'Reintentar sincronización',
                  onAction: () => _loadFleet(initial: true),
                ),
              ),
            ),
          ),
        Positioned(
          right: AppSpacing.md,
          bottom: selectedCamionero == null ? AppSpacing.xxl : 292,
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
              final selected = _selectedCamionero;
              if (selected != null) {
                setState(() => _followSelectedVehicle = true);
                _centerOnCamionero(selected['id'] as String);
                return;
              }

              final center = _fleetCenter();
              _mapController.move(
                center ?? _defaultCenter,
                center == null ? 12 : 11,
              );
            },
            onFitFleet: _fitVisibleFleet,
            onFilter: () {
              setState(() {
                if (_visibleStates.length == 3) {
                  _visibleStates
                    ..clear()
                    ..add('active');
                } else {
                  _visibleStates
                    ..clear()
                    ..addAll({'active', 'stale', 'offline'});
                }
              });
            },
            filterActive: _visibleStates.length != 3,
          ),
        ),
        if (selectedCamionero != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSelectedTruckSheet(selectedCamionero),
          ),
      ],
    );
  }
}

class _FleetSyncErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _FleetSyncErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.graphite950.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.alertCritical.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.alertCritical.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.sync_problem_rounded,
                  color: AppColors.alertCritical,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'No se pudo sincronizar la flota. El mapa queda disponible y se reintentará con polling/realtime.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.graphite300,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

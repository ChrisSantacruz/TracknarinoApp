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
import '../../services/calificacion_service.dart';
import '../../services/narino_trucker_places_service.dart';
import '../../services/oportunidad_service.dart';
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
  final VoidCallback? onTripCompleted;

  const SeguimientoScreen({super.key, this.onTripCompleted});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  static const Duration _fallbackPollInterval = Duration(seconds: 10);
  static const Duration _socketHealthyPollInterval = Duration(seconds: 12);
  static const latlong.LatLng _defaultCenter = latlong.LatLng(1.2136, -77.2811);

  final MapController _mapController = MapController();
  final PollingController _polling = PollingController();
  final RealtimeService _realtime = RealtimeService.instance;
  final OperationalMapDiagnostics _mapDiagnostics = OperationalMapDiagnostics();
  final Map<String, Map<String, dynamic>> _camioneros = {};
  final Set<String> _seenRealtimeEvents = {};
  final Set<String> _handledDeliveryPrompts = {};
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
  final Set<String> _visibleStates = {'active', 'stale', 'stopped', 'offline'};
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
    _tripSubscription = _realtime.tripUpdates.listen(_handleTripUpdate);
  }

  Future<void> _handleTripUpdate(RealtimeTripUpdate update) async {
    await _loadFleet(initial: false);
    if (!mounted) return;
    if (update.estado != 'entregada') return;

    final promptKey =
        update.eventId.isNotEmpty
            ? update.eventId
            : 'entregada:${update.oportunidadId}';
    if (_handledDeliveryPrompts.contains(promptKey)) return;
    _handledDeliveryPrompts.add(promptKey);

    final camioneroId = update.camioneroId;
    if (camioneroId == null || camioneroId.isEmpty) return;

    final camionero = _camioneros[camioneroId];
    await _promptEntregaYCalificacion(
      camioneroId: camioneroId,
      tripId: update.oportunidadId,
      nombreCamionero: (camionero?['nombre'] ?? 'Camionero').toString(),
      origen: (camionero?['origen'] ?? 'Origen').toString(),
      destino: (camionero?['destino'] ?? 'Destino').toString(),
      carga: (camionero?['carga'] ?? 'Carga').toString(),
    );
  }

  Future<void> _promptEntregaYCalificacion({
    required String camioneroId,
    required String tripId,
    required String nombreCamionero,
    required String origen,
    required String destino,
    required String carga,
  }) async {
    if (!mounted) return;

    final calificar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppColors.graphite950,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: AppColors.emerald400.withValues(alpha: 0.26),
              ),
            ),
            title: const Text(
              'Carga entregada',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$nombreCamionero confirmó la llegada.',
                  style: const TextStyle(color: AppColors.graphite300),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  carga,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$origen → $destino',
                  style: const TextStyle(color: AppColors.graphite300),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Después'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald500,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Calificar ahora'),
              ),
            ],
          ),
    );

    if (!mounted) return;
    widget.onTripCompleted?.call();

    if (calificar != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viaje marcado como entregado.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final ratingPayload = await _solicitarCalificacion(nombreCamionero);
    if (ratingPayload == null) return;

    try {
      await CalificacionService.crearCalificacion(
        usuarioId: camioneroId,
        tipoServicio: 'camionero',
        calificacion: ratingPayload.$1,
        comentario: ratingPayload.$2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calificación registrada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la calificación: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
          'activeTripId': item.activeTripId,
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
    if (item.trackingStatus == 'stopped') return 'stopped';
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
    final nextStatus =
        update.trackingStatus == 'stopped'
            ? 'stopped'
            : update.isOffline
            ? 'offline'
            : update.isStale
            ? 'stale'
            : update.trackingStatus;

    setState(() {
      camionero['ubicacion'] = updatedPoint;
      camionero['rumbo'] = update.heading ?? camionero['rumbo'];
      camionero['estado'] = nextStatus;
      camionero['isStale'] = update.isStale;
      camionero['isOffline'] = update.isOffline;
      camionero['ultimaActualizacion'] = update.timestamp;
      camionero['operationalEventType'] = update.operationalEventType;
      camionero['operationalEventReason'] = update.operationalEventReason;
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

  List<_OperationalNotification> get _operationalNotifications {
    final notifications = <_OperationalNotification>[];
    final now = DateTime.now();

    for (final camionero in _camioneros.values) {
      final status = camionero['estado'] as String;
      final updatedAt = camionero['ultimaActualizacion'] as DateTime;
      final hasActiveTrip = camionero['hasActiveTrip'] as bool;
      final route = '${camionero['origen']} → ${camionero['destino']}';
      final name = camionero['nombre'] as String;

      if (status == 'offline') {
        notifications.add(
          _OperationalNotification(
            title: '$name quedó sin señal',
            message:
                hasActiveTrip
                    ? 'Ruta $route. Último punto ${_formatTimeDifference(updatedAt).toLowerCase()}.'
                    : 'Sin viaje activo. Último punto ${_formatTimeDifference(updatedAt).toLowerCase()}.',
            color: AppColors.statusOffline,
            icon: Icons.signal_wifi_off_rounded,
            camioneroId: camionero['id'] as String,
            timestamp: updatedAt,
          ),
        );
        continue;
      }

      if (status == 'stopped') {
        final reason = camionero['operationalEventReason'] as String?;
        notifications.add(
          _OperationalNotification(
            title: '$name se detuvo',
            message:
                hasActiveTrip
                    ? 'Ruta $route${reason == null || reason.isEmpty ? '' : ' · $reason'}.'
                    : reason ?? 'Detención reportada por el camionero.',
            color: AppColors.alertWarning,
            icon: Icons.pause_circle_outline_rounded,
            camioneroId: camionero['id'] as String,
            timestamp: updatedAt,
          ),
        );
        continue;
      }

      if (status == 'stale') {
        notifications.add(
          _OperationalNotification(
            title: 'Señal antigua de $name',
            message:
                hasActiveTrip
                    ? 'Ruta $route. El mapa conserva el último punto confirmado.'
                    : 'El conductor no ha enviado ubicación reciente.',
            color: AppColors.statusStale,
            icon: Icons.schedule_rounded,
            camioneroId: camionero['id'] as String,
            timestamp: updatedAt,
          ),
        );
        continue;
      }

      if (hasActiveTrip && now.difference(updatedAt).inMinutes >= 3) {
        notifications.add(
          _OperationalNotification(
            title: 'Posible detención de $name',
            message:
                'Ruta $route. No hay movimiento confirmado en los últimos minutos.',
            color: AppColors.statusSyncing,
            icon: Icons.pause_circle_outline_rounded,
            camioneroId: camionero['id'] as String,
            timestamp: updatedAt,
          ),
        );
      }
    }

    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
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

  Future<void> _finalizarYCalificar(Map<String, dynamic> camionero) async {
    final tripId = (camionero['activeTripId'] ?? '').toString();
    final camioneroId = (camionero['id'] ?? '').toString();
    if (tripId.isEmpty || camioneroId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay viaje activo válido para finalizar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppColors.graphite950,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: AppColors.emerald400.withValues(alpha: 0.26),
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
                Icons.task_alt_rounded,
                color: AppColors.emerald300,
                size: 30,
              ),
            ),
            title: const Text(
              'Confirmar entrega',
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
                Text(
                  'Se cerrará el viaje activo de ${camionero['nombre']} y la carga pasará a entregada.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.graphite300),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camionero['carga'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${camionero['origen']} → ${camionero['destino']}',
                        style: const TextStyle(color: AppColors.graphite300),
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
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald500,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Finalizar viaje'),
              ),
            ],
          ),
    );

    if (confirmar != true) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final finalizada = await OportunidadService.finalizarCarga(tripId);
    if (!finalizada) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo finalizar el viaje.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ratingPayload = await _solicitarCalificacion(camionero['nombre']);
    if (ratingPayload == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Viaje finalizado. Calificación omitida.'),
          backgroundColor: Colors.orange,
        ),
      );
      await _loadFleet(initial: false);
      widget.onTripCompleted?.call();
      return;
    }

    try {
      await CalificacionService.crearCalificacion(
        usuarioId: camioneroId,
        tipoServicio: 'camionero',
        calificacion: ratingPayload.$1,
        comentario: ratingPayload.$2,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Viaje finalizado y calificación guardada.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Viaje finalizado, pero falló la calificación: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    await _loadFleet(initial: false);
    widget.onTripCompleted?.call();
  }

  Future<(int, String?)?> _solicitarCalificacion(
    dynamic nombreCamionero,
  ) async {
    int estrellas = 5;
    final comentarioController = TextEditingController();

    final result = await showDialog<(int, String?)>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Calificar viaje'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Califica el servicio de ${nombreCamionero ?? 'camionero'}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          onPressed:
                              () => setDialogState(() => estrellas = value),
                          icon: Icon(
                            value <= estrellas ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: comentarioController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Comentario (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Omitir'),
                  ),
                  FilledButton(
                    onPressed:
                        () => Navigator.of(dialogContext).pop((
                          estrellas,
                          comentarioController.text.trim().isEmpty
                              ? null
                              : comentarioController.text.trim(),
                        )),
                    child: const Text('Guardar calificación'),
                  ),
                ],
              );
            },
          ),
    );

    comentarioController.dispose();
    return result;
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
        key: ValueKey(
          'fleet-${camionero['id']}-${point.latitude.toStringAsFixed(5)}-${point.longitude.toStringAsFixed(5)}',
        ),
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
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(24),
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppColors.graphite950.withValues(alpha: 0.88),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _summaryMetric('Activos', _activeCount, AppColors.statusActive),
                const SizedBox(width: AppSpacing.xs),
                _summaryMetric('Antigua', _staleCount, AppColors.statusStale),
                const SizedBox(width: AppSpacing.xs),
                _summaryMetric(
                  'Sin señal',
                  _offlineCount,
                  AppColors.statusOffline,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.emerald400.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Viajes activos: $_activeTripCount · Sin ubicación: $_noLocationCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.graphite200,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.graphite200,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalFilters() {
    return Material(
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(24),
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: AppColors.graphite950.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filterChip('active', 'Activos', AppColors.statusActive),
              _filterChip('stale', 'Antigua', AppColors.statusStale),
              _filterChip('stopped', 'Detenido', AppColors.alertWarning),
              _filterChip('offline', 'Sin señal', AppColors.statusOffline),
              const SizedBox(width: AppSpacing.xxs),
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
                    () => setState(
                      () => _showFleetDensity = !_showFleetDensity,
                    ),
              ),
              _booleanFilterChip(
                selected: _showTruckerPlaces,
                label: 'Servicios',
                color: AppColors.emerald400,
                onTap:
                    () => setState(
                      () => _showTruckerPlaces = !_showTruckerPlaces,
                    ),
              ),
            ],
          ),
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
    final notificationCount = _operationalNotifications.length;
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _showOperationalNotifications,
                  icon: const Icon(Icons.notifications_active_outlined),
                  tooltip: 'Notificaciones operativas',
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.alertCritical,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        notificationCount > 9 ? '9+' : '$notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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

  void _showOperationalNotifications() {
    final notifications = _operationalNotifications;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.42,
          minChildSize: 0.28,
          maxChildSize: 0.78,
          builder: (_, controller) {
            return Material(
              color: AppColors.graphite950,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.sheetRadius),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Notificaciones operativas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Eventos detectados desde tracking, señal y rutas activas.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.graphite300,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (notifications.isEmpty)
                    OperationalEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Sin novedades críticas',
                      message:
                          'No hay camiones detenidos, sin señal o con señal antigua en este momento.',
                      actionLabel: 'Actualizar mapa',
                      onAction: () {
                        Navigator.of(context).pop();
                        _loadFleet(initial: false);
                      },
                    )
                  else
                    ...notifications.map(
                      (notification) => _OperationalNotificationTile(
                        notification: notification,
                        onTap: () {
                          Navigator.of(context).pop();
                          _seleccionarCamionero(notification.camioneroId);
                        },
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
                if (camionero['hasActiveTrip'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.deepGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _finalizarYCalificar(camionero),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Finalizar y calificar'),
                      ),
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
          right: 96,
          bottom: selectedCamionero == null ? AppSpacing.md : 292,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _buildOperationalFilters(),
          ),
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
                if (_visibleStates.length == 4) {
                  _visibleStates
                    ..clear()
                    ..add('active');
                } else {
                  _visibleStates
                    ..clear()
                    ..addAll({'active', 'stale', 'stopped', 'offline'});
                }
              });
            },
            filterActive: _visibleStates.length != 4,
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

class _OperationalNotification {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final String camioneroId;
  final DateTime timestamp;

  const _OperationalNotification({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.camioneroId,
    required this.timestamp,
  });
}

class _OperationalNotificationTile extends StatelessWidget {
  final _OperationalNotification notification;
  final VoidCallback onTap;

  const _OperationalNotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: notification.color.withValues(alpha: 0.24)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: notification.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(notification.icon, color: notification.color),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          notification.message,
          style: const TextStyle(color: AppColors.graphite300),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
      ),
    );
  }
}

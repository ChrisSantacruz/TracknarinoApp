import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/ors_service.dart';
import '../../state/alert_store.dart';
import '../../state/session_bootstrap.dart';
import '../../state/trip_store.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../../models/oportunidad_model.dart';
import '../../models/alerta_model.dart';
import '../../screens/camionero/alertas_screen.dart';
import '../../screens/camionero/perfil_camionero_screen.dart';
import '../../screens/camionero/oportunidades_screen.dart';
import '../../screens/camionero/ruta_viaje_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/map_control_cluster.dart';
import '../../widgets/operational/operational_map_primitives.dart';
import '../../widgets/operational/operational_empty_state.dart';
import '../../widgets/operational/operational_status_chip.dart';
import '../../widgets/operational/operational_svg_icon.dart';
import '../../widgets/viaje_activo_banner.dart';

class CamioneroHomeScreen extends StatefulWidget {
  final User usuario;

  const CamioneroHomeScreen({super.key, required this.usuario});

  @override
  State<CamioneroHomeScreen> createState() => _CamioneroHomeScreenState();
}

class _CamioneroHomeScreenState extends State<CamioneroHomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<Position>? _positionSubscription;
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _destinoPosition;
  double _currentHeading = 0;

  bool _isFollowingUser = true;
  bool _isDisponible = false;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    _cargarEstadoDisponible();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<TripStore>().refreshActiveTrip();
      await _initializeLocation();
      await _refreshAlerts();
      final trip = context.read<TripStore>().activeTrip;
      if (trip != null) {
        await _ensureRouteForTrip(trip);
      }
    });
  }

  LocationService get _locationService =>
      Provider.of<LocationService>(context, listen: false);

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _ensureRouteForTrip(Oportunidad oportunidad) async {
    final tripStore = context.read<TripStore>();
    if (tripStore.routePoints.isNotEmpty) {
      final dest = oportunidad.destination;
      if (dest != null) {
        setState(() => _destinoPosition = LatLng(dest.lat, dest.lng));
      }
      return;
    }

    try {
      final position = await _locationService.getCurrentLocation();
      if (position == null) return;
      final destination = oportunidad.destination;
      if (destination == null) return;

      final currentPosition = LatLng(position.latitude, position.longitude);
      final destinationPosition = LatLng(destination.lat, destination.lng);
      final routeData = await ORSService.obtenerRuta(
        currentPosition,
        destinationPosition,
      );
      final points = List<LatLng>.from(routeData['coordinates'] as List);
      if (oportunidad.id != null) {
        await tripStore.persistRoute(
          oportunidadId: oportunidad.id!,
          points: points,
          distanceKm: routeData['distance'] as double?,
          durationMinutes: routeData['duration'] as int?,
        );
      }
      tripStore.applyRoute(
        points: points,
        distanceKm: routeData['distance'] as double?,
        durationLabel: _formatDuration(routeData['duration'] as int?),
      );
      if (mounted) {
        setState(() => _destinoPosition = destinationPosition);
      }
    } catch (e) {
      debugPrint('Error al cargar ruta activa: $e');
    }
  }

  String? _formatDuration(int? minutes) {
    if (minutes == null) return null;
    return minutes >= 60
        ? '${(minutes / 60).toStringAsFixed(1)} h'
        : '$minutes min';
  }

  // Cargar estado disponible guardado
  Future<void> _cargarEstadoDisponible() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final disponible = await authService.obtenerEstadoDisponible();
    setState(() {
      _isDisponible = disponible;
    });
  }

  Future<void> _refreshAlerts() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) {
      await context.read<AlertStore>().refreshNearby(position);
    }
  }

  // Iniciar el seguimiento de ubicación
  Future<void> _initLocationTracking() async {
    final locationService = Provider.of<LocationService>(
      context,
      listen: false,
    );
    if (widget.usuario.id != null) {
      await locationService.init(widget.usuario.id!);
    }
    await locationService.startTracking();
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await SessionBootstrap.teardownSession(location: _locationService);
    await auth.logout();
  }

  Future<void> _initializeLocation() async {
    try {
      // Iniciar el servicio de localización
      if (widget.usuario.id != null) {
        await _locationService.init(widget.usuario.id!);
      }

      // Obtener posición actual
      final position = await _locationService.getCurrentLocation();

      if (position != null && mounted) {
        final newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = newLocation;
          _currentHeading = position.heading.isFinite ? position.heading : 0;
        });

        // Hacer zoom inicial a ubicación actual (estilo Uber)
        _mapController.move(newLocation, 16.0);
      }

      await _positionSubscription?.cancel();
      _positionSubscription = _locationService.positionStream.listen((
        position,
      ) {
        if (!mounted) return;
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _currentHeading =
              position.heading.isFinite ? position.heading : _currentHeading;
        });

        if (_isFollowingUser && _currentPosition != null) {
          _moveCameraIfMeaningful(_currentPosition!, _mapController.zoom);
        }
      });
    } catch (e) {
      debugPrint('Error al inicializar ubicación: $e');
    }
  }

  void _toggleFollowUser() {
    setState(() {
      _isFollowingUser = !_isFollowingUser;

      if (_isFollowingUser && _currentPosition != null) {
        _mapController.move(_currentPosition!, _mapController.zoom);
      }
    });
  }

  void _moveCameraIfMeaningful(LatLng point, double zoom) {
    final distance = const Distance().as(
      LengthUnit.Meter,
      _mapController.center,
      point,
    );
    if (distance < 18 && (zoom - _mapController.zoom).abs() < 0.2) return;
    _mapController.move(point, zoom);
  }

  String _appBarTitle() {
    switch (_selectedIndex) {
      case 1:
        return 'Oportunidades';
      case 2:
        return 'Alertas';
      case 3:
        return 'Perfil';
      default:
        return 'Operación en ruta';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripStore = context.watch<TripStore>();
    final viajeActivo = tripStore.activeTrip;
    final rutaActiva = tripStore.routePoints;
    final alertas = context.watch<AlertStore>().alerts;

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        actions: [
          if (alertas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Center(
                child: Text(
                  '${alertas.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          IconButton(
            onPressed: () => setState(() => _selectedIndex = 2),
            icon: OperationalSvgIcon(
              OperationalSvgIcons.bell,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Alertas',
          ),
          IconButton(
            onPressed: _logout,
            icon: OperationalSvgIcon(
              OperationalSvgIcons.logOut,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Stack(
            children: [
              _buildMap(viajeActivo, rutaActiva, alertas),
              _buildStatusPanel(viajeActivo),
            ],
          ),
          OportunidadesScreen(
            onTripAccepted: () => context.read<TripStore>().refreshActiveTrip(),
          ),
          const AlertasScreen(embedded: true),
          PerfilCamioneroScreen(usuario: widget.usuario, embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected:
            (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Viajes',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildMap(
    Oportunidad? viajeActivo,
    List<LatLng> rutaActiva,
    List<AlertaSeguridad> alertasCercanas,
  ) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _currentPosition ?? LatLng(1.2053, -77.2886),
            zoom: 16.0,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                setState(() {
                  _isFollowingUser = false;
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: const ['a', 'b', 'c'],
            ),
            if (rutaActiva.isNotEmpty)
              OperationalRouteLayer(points: rutaActiva),
            MarkerLayer(
              markers: [
                if (_currentPosition != null)
                  Marker(
                    width: 52.0,
                    height: 52.0,
                    point: _currentPosition!,
                    builder:
                        (ctx) => OperationalVehiclePresenceMarker(
                          status:
                              viajeActivo?.estado == 'en_ruta'
                                  ? 'en_ruta'
                                  : _isDisponible
                                  ? 'active'
                                  : 'offline',
                          heading: _currentHeading,
                          selected: _isFollowingUser,
                          semanticsLabel: 'Tu vehículo en el mapa',
                        ),
                  ),
                if (_destinoPosition != null)
                  Marker(
                    width: 46.0,
                    height: 46.0,
                    point: _destinoPosition!,
                    builder:
                        (ctx) => const OperationalDestinationMarker(
                          label: 'Destino del viaje',
                        ),
                  ),
                ...alertasCercanas.map(
                  (alerta) => Marker(
                    width: 52.0,
                    height: 52.0,
                    point: LatLng(alerta.coords['lat']!, alerta.coords['lng']!),
                    builder:
                        (ctx) => OperationalAlertMarker(
                          type: alerta.tipo,
                          timestamp: alerta.timestamp,
                          onTap: () => _mostrarDetalleAlerta(alerta),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Controles del mapa
        Positioned(
          right: AppSpacing.md,
          bottom: 160,
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
            onRecenter: _toggleFollowUser,
            recenterActive: _isFollowingUser,
          ),
        ),

        // Banner de viaje activo (si existe) - solo en pantalla de inicio
        if (viajeActivo != null)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: ViajeActivoBanner(
              viajeActivo: viajeActivo,
              onIniciarViaje: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RutaViajeScreen(oportunidad: viajeActivo),
                  ),
                );
                if (mounted) {
                  await context.read<TripStore>().refreshActiveTrip();
                }
              },
              onVerRuta: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RutaViajeScreen(oportunidad: viajeActivo),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _mostrarDetalleAlerta(AlertaSeguridad alerta) {
    final meta = OperationalAlertMeta.fromType(alerta.tipo);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Material(
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
                      'Reportada hace ${_calcularTiempoTranscurrido(alerta.timestamp)}',
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

  // Calcular tiempo transcurrido
  String _calcularTiempoTranscurrido(DateTime timestamp) {
    final diferencia = DateTime.now().difference(timestamp);
    if (diferencia.inMinutes < 60) {
      return '${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return '${diferencia.inHours} h';
    } else {
      return '${diferencia.inDays} d';
    }
  }

  Widget _buildStatusPanel(Oportunidad? viajeActivo) {
    final bool tieneOportunidadActiva = viajeActivo != null;
    final bool enRuta = viajeActivo?.estado == 'en_ruta';

    final status =
        enRuta
            ? 'en_ruta'
            : tieneOportunidadActiva
            ? 'asignada'
            : _isDisponible
            ? 'active'
            : 'offline';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        elevation: 8,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sheetRadius),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.sheetRadius),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OperationalStatusChip.tracking(status),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          tieneOportunidadActiva
                              ? '${viajeActivo!.origen} → ${viajeActivo.destino}'
                              : 'Sin viaje asignado',
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!tieneOportunidadActiva) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Text(
                                'Disponible',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Switch(
                                value: _isDisponible,
                                onChanged: (value) async {
                                  setState(() => _isDisponible = value);
                                  final authService = Provider.of<AuthService>(
                                    context,
                                    listen: false,
                                  );
                                  await authService.guardarEstadoDisponible(
                                    value,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          value
                                              ? 'Disponible para oportunidades'
                                              : 'No disponible',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => setState(() => _selectedIndex = 2),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.alertCritical,
                      minimumSize: const Size(120, AppSpacing.minTouchTarget),
                    ),
                    icon: const Icon(Icons.add_alert),
                    label: const Text('Alertar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    // Cálculo simple de distancia en kilómetros usando la fórmula de Haversine
    const R = 6371.0; // Radio de la Tierra en km

    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final dLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    final dLon = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

}

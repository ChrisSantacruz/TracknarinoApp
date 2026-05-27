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
import '../../models/trucker_place.dart';
import '../../screens/camionero/alertas_screen.dart';
import '../../screens/camionero/perfil_camionero_screen.dart';
import '../../screens/camionero/oportunidades_screen.dart';
import '../../screens/camionero/ruta_viaje_screen.dart';
import '../../services/narino_trucker_places_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/map_control_cluster.dart';
import '../../widgets/operational/operational_map_primitives.dart';
import '../../widgets/operational/operational_status_chip.dart';
import '../../widgets/operational/operational_svg_icon.dart';
import '../../widgets/operational/premium_operational_widgets.dart';
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
  bool _showTruckerPlaces = true;
  bool _placesLoading = false;
  String? _placesError;
  List<TruckerPlace> _truckerPlaces = [];
  final Set<TruckerPlaceCategory> _selectedPlaceCategories = {
    TruckerPlaceCategory.fuel,
    TruckerPlaceCategory.tire,
    TruckerPlaceCategory.mechanic,
    TruckerPlaceCategory.parking,
    TruckerPlaceCategory.food,
    TruckerPlaceCategory.emergency,
  };

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
      _loadTruckerPlaces();
      if (!mounted) return;
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

  Future<void> _loadTruckerPlaces() async {
    if (_selectedPlaceCategories.isEmpty) {
      setState(() {
        _truckerPlaces = [];
        _placesError = null;
      });
      return;
    }

    setState(() {
      _placesLoading = true;
      _placesError = null;
    });

    try {
      final places = await NarinoTruckerPlacesService.fetchPlaces(
        categories: _selectedPlaceCategories,
      );
      if (!mounted) return;
      final sorted = _sortPlacesForDriver(places);
      setState(() {
        _truckerPlaces = sorted;
        _placesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _placesLoading = false;
        _placesError =
            'No se pudieron cargar servicios de Nariño. Revisa conexión e intenta de nuevo.';
      });
    }
  }

  List<TruckerPlace> _sortPlacesForDriver(List<TruckerPlace> places) {
    final current = _currentPosition;
    if (current == null) return places;
    final distance = const Distance();
    final sorted = [...places];
    sorted.sort(
      (a, b) => distance(
        current,
        a.position,
      ).compareTo(distance(current, b.position)),
    );
    return sorted;
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
    final alertStore = context.watch<AlertStore>();
    final viajeActivo = tripStore.activeTrip;
    final rutaActiva = tripStore.routePoints;
    final alertas = alertStore.alerts;
    final alertBadgeCount = alertStore.unreadBump;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.inkBlack.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        title: Text(
          _appBarTitle(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
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
      extendBody: false,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: AppColors.graphite950.withValues(alpha: 0.98),
              indicatorColor: AppColors.emerald400.withValues(alpha: 0.18),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  color:
                      states.contains(WidgetState.selected)
                          ? AppColors.emerald300
                          : AppColors.graphite300,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color:
                      states.contains(WidgetState.selected)
                          ? AppColors.emerald300
                          : AppColors.graphite300,
                ),
              ),
            ),
            child: NavigationBar(
              height: 64,
              elevation: 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
                if (index == 2) {
                  context.read<AlertStore>().clearUnreadBump();
                }
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Mapa',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  selectedIcon: Icon(Icons.local_shipping),
                  label: 'Viajes',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: alertBadgeCount > 0 && _selectedIndex != 2,
                    label: Text(
                      alertBadgeCount > 9 ? '9+' : '$alertBadgeCount',
                    ),
                    backgroundColor: AppColors.alertCritical,
                    child: const Icon(Icons.warning_amber_outlined),
                  ),
                  selectedIcon: const Icon(Icons.warning_amber),
                  label: 'Alertas',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
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
            minZoom: 6.0,
            maxZoom: 19.0,
            interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                    width: 44.0,
                    height: 44.0,
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
                    width: 40.0,
                    height: 40.0,
                    point: _destinoPosition!,
                    builder:
                        (ctx) => const OperationalDestinationMarker(
                          label: 'Destino del viaje',
                        ),
                  ),
                ...alertasCercanas.map(
                  (alerta) => Marker(
                    width: 44.0,
                    height: 44.0,
                    point: LatLng(alerta.coords['lat']!, alerta.coords['lng']!),
                    builder:
                        (ctx) => OperationalAlertMarker(
                          type: alerta.tipo,
                          timestamp: alerta.timestamp,
                          onTap: () => _mostrarDetalleAlerta(alerta),
                        ),
                  ),
                ),
                if (_showTruckerPlaces)
                  ..._truckerPlaces.map(
                    (place) => Marker(
                      width: 36,
                      height: 36,
                      point: place.position,
                      builder:
                          (ctx) => _TruckerPlaceMarker(
                            place: place,
                            onTap: () => _mostrarDetalleServicio(place),
                          ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.md,
          top: viajeActivo == null ? AppSpacing.md : 96,
          child:
              _showTruckerPlaces
                  ? _PlacesMapStatusBadge(
                    loading: _placesLoading,
                    error: _placesError,
                    count: _truckerPlaces.length,
                    onRetry: _loadTruckerPlaces,
                  )
                  : const SizedBox.shrink(),
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
            onFilter: _showPlacesFilters,
            filterActive: _showTruckerPlaces,
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
                    builder:
                        (context) => RutaViajeScreen(oportunidad: viajeActivo),
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
                    builder:
                        (context) => RutaViajeScreen(oportunidad: viajeActivo),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _showPlacesFilters() async {
    final selected = Set<TruckerPlaceCategory>.from(_selectedPlaceCategories);
    var showPlaces = _showTruckerPlaces;

    final shouldApply = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Material(
                  color: AppColors.graphite950,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.sheetRadius),
                  ),
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
                          const PremiumSheetHandle(),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Servicios visibles en el mapa',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Filtra restaurantes, gasolineras, talleres y otros puntos útiles para carretera.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.graphite300),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: showPlaces,
                            activeThumbColor: AppColors.emerald400,
                            title: const Text('Mostrar servicios en mapa'),
                            subtitle: const Text(
                              'Usa datos abiertos de OpenStreetMap para Nariño.',
                            ),
                            onChanged:
                                (value) =>
                                    setSheetState(() => showPlaces = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children:
                                TruckerPlaceCategory.values.map((category) {
                                  final isSelected = selected.contains(
                                    category,
                                  );
                                  return FilterChip(
                                    selected: isSelected,
                                    avatar: Icon(category.icon, size: 18),
                                    label: Text(category.label),
                                    selectedColor: category.color.withValues(
                                      alpha: 0.22,
                                    ),
                                    checkmarkColor: category.color,
                                    onSelected:
                                        showPlaces
                                            ? (value) {
                                              setSheetState(() {
                                                if (value) {
                                                  selected.add(category);
                                                } else {
                                                  selected.remove(category);
                                                }
                                              });
                                            }
                                            : null,
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(true),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Aplicar filtros'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );

    if (shouldApply != true) return;

    setState(() {
      _showTruckerPlaces = showPlaces;
      _selectedPlaceCategories
        ..clear()
        ..addAll(selected);
      if (!_showTruckerPlaces) {
        _truckerPlaces = [];
        _placesError = null;
      }
    });

    if (_showTruckerPlaces) {
      _loadTruckerPlaces();
    }
  }

  void _mostrarDetalleServicio(TruckerPlace place) {
    final current = _currentPosition;
    final distance =
        current == null
            ? null
            : const Distance().as(
              LengthUnit.Kilometer,
              current,
              place.position,
            );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Material(
            color: AppColors.graphite950,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.sheetRadius),
            ),
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
                    const PremiumSheetHandle(),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _TruckerPlaceIcon(category: place.category),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                place.category.label,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: place.category.color),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PremiumInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Ubicación',
                      value:
                          place.address ??
                          '${place.position.latitude.toStringAsFixed(5)}, ${place.position.longitude.toStringAsFixed(5)}',
                      color: place.category.color,
                    ),
                    if (distance != null)
                      PremiumInfoRow(
                        icon: Icons.near_me_outlined,
                        label: 'Distancia aproximada',
                        value: '${distance.toStringAsFixed(1)} km desde tu GPS',
                        color: AppColors.emerald400,
                      ),
                    if (place.phone != null)
                      PremiumInfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono OSM',
                        value: place.phone!,
                        color: AppColors.statusSyncing,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Datos abiertos de OpenStreetMap filtrados para Nariño. Verifica disponibilidad antes de desviarte.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.graphite300,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                              ? '${viajeActivo.origen} → ${viajeActivo.destino}'
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

class _PlacesMapStatusBadge extends StatelessWidget {
  final bool loading;
  final String? error;
  final int count;
  final VoidCallback onRetry;

  const _PlacesMapStatusBadge({
    required this.loading,
    required this.error,
    required this.count,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasError && !loading ? onRetry : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.graphite950.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  hasError
                      ? AppColors.alertCritical.withValues(alpha: 0.35)
                      : AppColors.emerald400.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  hasError
                      ? Icons.sync_problem_rounded
                      : Icons.local_gas_station_outlined,
                  size: 16,
                  color:
                      hasError ? AppColors.alertCritical : AppColors.emerald300,
                ),
              const SizedBox(width: 8),
              Text(
                hasError ? 'Reintentar servicios' : 'Servicios Nariño · $count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TruckerPlaceMarker extends StatelessWidget {
  final TruckerPlace place;
  final VoidCallback onTap;

  const _TruckerPlaceMarker({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${place.category.label}: ${place.name}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: _TruckerPlaceIcon(category: place.category),
      ),
    );
  }
}

class _TruckerPlaceIcon extends StatelessWidget {
  final TruckerPlaceCategory category;

  const _TruckerPlaceIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.graphite950.withValues(alpha: 0.96),
        shape: BoxShape.circle,
        border: Border.all(color: category.color.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: category.color.withValues(alpha: 0.28),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Icon(category.icon, color: category.color, size: 18),
      ),
    );
  }
}

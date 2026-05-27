import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../map/operational_map_intelligence.dart';
import '../../models/alerta_model.dart';
import '../../services/alerta_service.dart';
import '../../services/location_service.dart';
import '../../state/alert_store.dart';
import '../../widgets/operational/operational_error_state.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/map_control_cluster.dart';
import '../../widgets/operational/operational_map_primitives.dart';
import '../../widgets/operational/premium_operational_widgets.dart';
import 'package:provider/provider.dart';

class AlertasScreen extends StatefulWidget {
  final bool embedded;

  const AlertasScreen({super.key, this.embedded = false});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen>
    with SingleTickerProviderStateMixin {
  List<AlertaSeguridad> _alertas = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;
  String _selectedTipoAlerta = 'trancon';
  final TextEditingController _descripcionController = TextEditingController();
  bool _isSendingAlert = false;
  LatLng? _selectedLocation;
  bool _compartirConOtros = true;
  bool _verMapa = false;
  final MapController _alertMapController = MapController();
  final OperationalMapDiagnostics _mapDiagnostics = OperationalMapDiagnostics();
  LatLng _alertMapCenter = LatLng(1.2136, -77.2811);
  double _alertMapZoom = 12;
  DateTime? _lastAlertViewportUpdateAt;
  bool _showAlertDensity = false;
  final Set<String> _visibleAlertSeverities = {'critical', 'warning', 'info'};

  final Map<String, Map<String, dynamic>> _tiposAlertas = {
    'trancon': {
      'titulo': 'Tráfico',
      'descripcion': 'Reportar tráfico intenso o embotellamiento',
      'icono': Icons.traffic,
      'color': Colors.orange,
    },
    'sospecha': {
      'titulo': 'Actividad sospechosa',
      'descripcion': 'Reportar actividad sospechosa en la ruta',
      'icono': Icons.visibility,
      'color': Colors.amber,
    },
    'intento_robo': {
      'titulo': 'Intento de robo',
      'descripcion': 'Reportar un intento de robo',
      'icono': Icons.warning,
      'color': Colors.deepOrange,
    },
    'robo': {
      'titulo': 'Robo',
      'descripcion': 'Reportar un robo (emergencia)',
      'icono': Icons.emergency,
      'color': Colors.red,
    },
    'obstaculo': {
      'titulo': 'Obstáculo',
      'descripcion': 'Reportar un obstáculo en la carretera',
      'icono': Icons.warning_amber,
      'color': Colors.amber,
    },
    'clima': {
      'titulo': 'Clima adverso',
      'descripcion': 'Reportar condiciones climáticas adversas',
      'icono': Icons.cloud,
      'color': Colors.blue,
    },
    'accidente': {
      'titulo': 'Accidente',
      'descripcion': 'Reportar un accidente de tránsito',
      'icono': Icons.car_crash,
      'color': Colors.red,
    },
    'policia': {
      'titulo': 'Control policial',
      'descripcion': 'Reportar un control policial',
      'icono': Icons.local_police,
      'color': Colors.blue,
    },
    'otro': {
      'titulo': 'Otro',
      'descripcion': 'Reportar otro tipo de alerta',
      'icono': Icons.info,
      'color': Colors.grey,
    },
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarAlertas();
    _cargarUbicacionActual();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _cargarAlertas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final locationService = context.read<LocationService>();
    final store = context.read<AlertStore>();
    final position = await locationService.getCurrentLocation();

    if (position == null) {
      setState(() {
        _errorMessage = 'No se pudo obtener tu ubicación actual';
        _isLoading = false;
        _alertas = [];
      });
      return;
    }

    await store.refreshNearby(position);
    if (!mounted) return;
    setState(() {
      _alertas = store.alerts;
      _isLoading = false;
      _errorMessage = store.errorMessage ?? '';
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _alertMapCenter = _selectedLocation!;
    });
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _toggleMapView() {
    setState(() {
      _verMapa = !_verMapa;
    });
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
  }

  void _handleAlertMapPositionChanged(MapPosition position, bool hasGesture) {
    final nextCenter = position.center;
    final nextZoom = position.zoom;
    if (nextCenter == null && nextZoom == null) return;

    final now = DateTime.now();
    final center = nextCenter ?? _alertMapCenter;
    final zoom = nextZoom ?? _alertMapZoom;
    final movedMeters = const Distance().as(
      LengthUnit.Meter,
      _alertMapCenter,
      center,
    );
    final shouldRefreshPlan =
        _lastAlertViewportUpdateAt == null ||
        now.difference(_lastAlertViewportUpdateAt!).inMilliseconds >= 180 ||
        movedMeters >= 120 ||
        (zoom - _alertMapZoom).abs() >= 0.3;

    if (!shouldRefreshPlan) return;

    setState(() {
      _alertMapCenter = center;
      _alertMapZoom = zoom;
      _lastAlertViewportUpdateAt = now;
    });
  }

  Future<void> _crearAlerta() async {
    if (_selectedLocation == null) {
      _mostrarError('Selecciona una ubicación en el mapa');
      return;
    }

    setState(() {
      _isSendingAlert = true;
    });

    try {
      final store = context.read<AlertStore>();
      final created = await AlertaService.crearAlerta(
        tipo: _selectedTipoAlerta,
        coords: {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        },
        descripcion:
            _descripcionController.text.isNotEmpty
                ? _descripcionController.text
                : null,
        compartir: _compartirConOtros,
      );

      if (created != null) {
        store.upsertLocal(created);
      }

      _descripcionController.clear();
      setState(() {
        _isSendingAlert = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerta guardada. Se sincronizará con el servidor.'),
            backgroundColor: Colors.orange,
          ),
        );
        _cargarAlertas(); // Recargar alertas
      }
    } catch (e) {
      setState(() {
        _isSendingAlert = false;
      });
      _mostrarError('Error al crear la alerta: $e');
    }
  }

  Future<void> _cargarUbicacionActual() async {
    try {
      final position =
          await Provider.of<LocationService>(
            context,
            listen: false,
          ).getCurrentLocation();

      if (position != null && mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          debugPrint(
            'Ubicación actual cargada: ${position.latitude}, ${position.longitude}',
          );
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ubicación inicial: $e');
      // Usar ubicación predeterminada (Pasto)
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(1.2136, -77.2811);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: PremiumGlassCard(
              padding: const EdgeInsets.all(AppSpacing.xs),
              radius: 22,
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.emerald400.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                labelColor: AppColors.emerald300,
                unselectedLabelColor: AppColors.graphite300,
                tabs: const [Tab(text: 'Alertas'), Tab(text: 'Reportar')],
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildAlertasTab(), _buildCrearAlertaTab()],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return PremiumGradientScaffold(safeArea: false, child: content);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de seguridad'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Ver alertas'), Tab(text: 'Reportar')],
        ),
        actions: [
          IconButton(
            icon: Icon(_verMapa ? Icons.list : Icons.map),
            onPressed: _toggleMapView,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarAlertas,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildAlertasTab() {
    if (_isLoading) {
      return const OperationalSkeleton(height: 200, width: double.infinity);
    }

    if (_errorMessage.isNotEmpty) {
      return OperationalErrorState(
        message: _errorMessage,
        onRetry: _cargarAlertas,
      );
    }

    if (_alertas.isEmpty) {
      return const Center(
        child: Text('No hay alertas cercanas en este momento'),
      );
    }

    if (_verMapa) {
      return _buildMapaAlertas();
    } else {
      return _buildListaAlertas();
    }
  }

  Widget _buildMapaAlertas() {
    final alertPlan = OperationalMapIntelligence.buildAlertPlan(
      alerts: _alertas,
      mapCenter: _alertMapCenter,
      zoom: _alertMapZoom,
      currentLocation: _selectedLocation,
      visibleSeverities: _visibleAlertSeverities,
    );
    _mapDiagnostics.recordAlertPlan(alertPlan);

    return Stack(
      children: [
        FlutterMap(
          mapController: _alertMapController,
          options: MapOptions(
            center: _selectedLocation ?? LatLng(1.2136, -77.2811),
            zoom: 12.0,
            onTap: (_, point) => _onMapTap(point),
            onPositionChanged: _handleAlertMapPositionChanged,
          ),
          children: [
            TileLayer(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: const ['a', 'b', 'c'],
            ),
            OperationalDensityCircleLayer(
              cells: alertPlan.densityCells,
              color: AppColors.alertWarning,
              visible: _showAlertDensity,
            ),
            MarkerLayer(
              markers: [
                ..._buildAlertClusterMarkers(alertPlan),
                ..._buildAlertMarkers(alertPlan),
                if (_selectedLocation != null) _currentLocationMarker(),
              ],
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: Material(
            elevation: 7,
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.96),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                _alertas.length == 1
                    ? '1 alerta cercana'
                    : '${alertPlan.totalInputCount} alertas priorizadas',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.md,
          top: 72,
          child: _buildAlertPriorityFilters(),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: MapControlCluster(
            onZoomIn:
                () => _alertMapController.move(
                  _alertMapController.center,
                  _alertMapController.zoom + 1,
                ),
            onZoomOut:
                () => _alertMapController.move(
                  _alertMapController.center,
                  _alertMapController.zoom - 1,
                ),
            onRecenter: () {
              if (_selectedLocation != null) {
                _alertMapController.move(_selectedLocation!, 14);
              }
            },
          ),
        ),
      ],
    );
  }

  List<Marker> _buildAlertMarkers(OperationalAlertRenderPlan plan) {
    return plan.markers.map((item) {
      return Marker(
        width: 52,
        height: 52,
        point: item.point,
        builder:
            (ctx) => OperationalAlertMarker(
              type: item.alert.tipo,
              timestamp: item.alert.timestamp,
              selected: item.priority >= 135,
              onTap: () => _mostrarDetalleAlerta(item.alert),
            ),
      );
    }).toList();
  }

  List<Marker> _buildAlertClusterMarkers(OperationalAlertRenderPlan plan) {
    return plan.clusters.map((cluster) {
      return Marker(
        width: 62,
        height: 62,
        point: cluster.center,
        builder:
            (ctx) => OperationalAlertClusterMarker(
              cluster: cluster,
              onTap: () => _expandAlertCluster(cluster),
            ),
      );
    }).toList();
  }

  Marker _currentLocationMarker() {
    return Marker(
      width: 52,
      height: 52,
      point: _selectedLocation!,
      builder:
          (ctx) => const OperationalVehiclePresenceMarker(
            status: 'active',
            heading: 0,
            semanticsLabel: 'Ubicacion actual',
          ),
    );
  }

  void _expandAlertCluster(OperationalAlertCluster cluster) {
    final points = cluster.items.map((item) => item.point).toList();
    if (points.length < 2) {
      _alertMapController.move(
        cluster.center,
        (_alertMapController.zoom + 1).clamp(10, 16).toDouble(),
      );
      return;
    }
    _alertMapController.fitBounds(
      LatLngBounds.fromPoints(points),
      options: const FitBoundsOptions(padding: EdgeInsets.all(82), maxZoom: 15),
    );
  }

  Widget _buildAlertPriorityFilters() {
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
            _severityChip('critical', 'Criticas', AppColors.alertCritical),
            _severityChip('warning', 'Riesgos', AppColors.alertWarning),
            _severityChip('info', 'Info', AppColors.alertInfo),
            _densityChip(),
          ],
        ),
      ),
    );
  }

  Widget _severityChip(String severity, String label, Color color) {
    final selected = _visibleAlertSeverities.contains(severity);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              if (_visibleAlertSeverities.length == 1) return;
              _visibleAlertSeverities.remove(severity);
            } else {
              _visibleAlertSeverities.add(severity);
            }
          });
        },
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

  Widget _densityChip() {
    final selected = _showAlertDensity;
    const color = AppColors.statusSyncing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => setState(() => _showAlertDensity = !_showAlertDensity),
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
            'Densidad',
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

  Widget _buildListaAlertas() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      itemCount: _alertas.length,
      itemBuilder: (context, index) {
        final alerta = _alertas[index];
        final tipoAlerta = _tiposAlertas[alerta.tipo];
        final color = tipoAlerta?['color'] as Color? ?? AppColors.statusStale;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PremiumGlassCard(
            radius: 22,
            borderColor: color.withValues(alpha: 0.26),
            onTap: () {
              setState(() {
                _selectedLocation = LatLng(
                  alerta.coords['lat']!,
                  alerta.coords['lng']!,
                );
                _verMapa = true;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    tipoAlerta?['icono'] as IconData? ?? Icons.warning,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tipoAlerta?['titulo'] as String? ?? 'Alerta',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _formatTimeDifference(alerta.timestamp),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.graphite300),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        alerta.descripcion ??
                            tipoAlerta?['descripcion'] as String? ??
                            '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.graphite300,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          PremiumStatusPill(
                            label: _severityLabel(alerta.tipo),
                            color: color,
                          ),
                          if (alerta.imagenUrl != null &&
                              alerta.imagenUrl!.isNotEmpty)
                            const PremiumStatusPill(
                              label: 'Con imagen',
                              color: AppColors.statusSyncing,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCrearAlertaTab() {
    final ubicacion = _selectedLocation ?? LatLng(1.2136, -77.2811);
    final MapController mapController = MapController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumScreenHeader(
            eyebrow: 'Alertas',
            title: 'Reportar evento',
            subtitle:
                'Selecciona ubicación, severidad y descripción. Si no hay conexión, se guarda en la cola offline.',
          ),
          const SizedBox(height: AppSpacing.lg),

          Stack(
            children: [
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      center: ubicacion,
                      zoom: 15.0,
                      onTap: (_, point) => _onMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 52.0,
                            height: 52.0,
                            point: ubicacion,
                            builder:
                                (ctx) => OperationalAlertMarker(
                                  type: _selectedTipoAlerta,
                                  selected: true,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Controles del mapa
              Positioned(
                right: 8,
                bottom: 8,
                child: Column(
                  children: [
                    // Botón ubicación actual
                    OperationalMapActionChip(
                      svg: operationalCrosshairSvg,
                      label: 'Ubicación',
                      onPressed: () async {
                        await _cargarUbicacionActual();
                        if (_selectedLocation != null) {
                          mapController.move(_selectedLocation!, 15.0);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    MapControlCluster(
                      onZoomIn: () {
                        mapController.move(
                          mapController.center,
                          mapController.zoom + 1.0,
                        );
                      },
                      onZoomOut: () {
                        mapController.move(
                          mapController.center,
                          mapController.zoom - 1.0,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: () async {
              await _cargarUbicacionActual();
              if (!mounted) return;
              if (_selectedLocation != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ubicación actual marcada')),
                );
              }
            },
            icon: const Icon(Icons.my_location),
            label: const Text('Usar ubicación actual'),
          ),

          const SizedBox(height: 8),

          Text(
            'Ubicación seleccionada: ${_selectedLocation != null ? '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}' : 'Ninguna'}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
          ),

          const SizedBox(height: 16),

          Text(
            'Tipo de alerta:',
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _tiposAlertas.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.value['titulo'] as String),
                    selected: _selectedTipoAlerta == entry.key,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTipoAlerta = entry.key;
                        });
                      }
                    },
                    avatar: Icon(entry.value['icono'] as IconData),
                    selectedColor: (entry.value['color'] as Color).withAlpha(
                      50,
                    ),
                  );
                }).toList(),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _descripcionController,
            decoration: const InputDecoration(
              labelText: 'Descripción operativa',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            title: const Text('Compartir con otros camioneros'),
            value: _compartirConOtros,
            activeThumbColor: AppColors.emerald400,
            onChanged: (value) => setState(() => _compartirConOtros = value),
            subtitle: const Text('Permite que otros vean esta alerta'),
          ),

          const SizedBox(height: 24),

          PremiumPrimaryButton(
            label: _isSendingAlert ? 'Enviando alerta' : 'Enviar alerta',
            icon: Icons.send_rounded,
            loading: _isSendingAlert,
            onPressed: _isSendingAlert ? null : _crearAlerta,
          ),
        ],
      ),
    );
  }

  String _formatTimeDifference(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else {
      return 'Hace ${difference.inDays} días';
    }
  }

  String _severityLabel(String type) {
    switch (type) {
      case 'robo':
      case 'intento_robo':
      case 'accidente':
        return 'Crítica';
      case 'trancon':
      case 'obstaculo':
      case 'clima':
        return 'Advertencia';
      default:
        return 'Informativa';
    }
  }

  void _mostrarDetalleAlerta(AlertaSeguridad alerta) {
    final meta = OperationalAlertMeta.fromType(alerta.tipo);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => PremiumGlassCard(
            radius: AppSpacing.sheetRadius,
            padding: EdgeInsets.zero,
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
                      meta.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      alerta.descripcion ?? 'Sin descripción operativa',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.graphite300,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _formatTimeDifference(alerta.timestamp),
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
}

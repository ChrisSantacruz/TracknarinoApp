import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/fleet_tracking_item.dart';
import '../../models/oportunidad_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/oportunidad_service.dart';
import '../../services/location_service.dart';
import '../../state/session_bootstrap.dart';
import '../../services/contratista_tracking_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/operational_empty_state.dart';
import '../../widgets/operational/operational_error_state.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../widgets/operational/operational_status_chip.dart';
import '../../widgets/operational/operational_svg_icon.dart';
import '../../widgets/operational/premium_operational_widgets.dart';
import 'crear_oportunidad_screen.dart';
import 'seguimiento_screen.dart';

class ContratistaHomeScreen extends StatefulWidget {
  final User usuario;

  const ContratistaHomeScreen({super.key, required this.usuario});

  @override
  State<ContratistaHomeScreen> createState() => _ContratistaHomeScreenState();
}

class _ContratistaHomeScreenState extends State<ContratistaHomeScreen> {
  int _selectedIndex = 0;
  String _tripFilter = 'todas';
  bool _fleetLoading = true;
  bool _tripsLoading = true;
  String? _fleetError;
  String? _tripsError;
  List<FleetTrackingItem> _fleet = [];
  List<Oportunidad> _createdTrips = [];
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _contractorAvatarBytes;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([_loadFleetSummary(), _loadCreatedTrips()]);
  }

  Future<void> _loadFleetSummary() async {
    setState(() {
      _fleetLoading = true;
      _fleetError = null;
    });
    try {
      final fleet = await ContratistaTrackingService.fetchFleet();
      if (!mounted) return;
      setState(() {
        _fleet = fleet;
        _fleetLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fleetError = 'No se pudo cargar el estado de flota: $e';
        _fleetLoading = false;
      });
    }
  }

  Future<void> _loadCreatedTrips() async {
    setState(() {
      _tripsLoading = true;
      _tripsError = null;
    });
    try {
      final trips = await OportunidadService.obtenerOportunidadesContratista();
      if (!mounted) return;
      setState(() {
        _createdTrips = trips;
        _tripsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tripsError = 'No se pudieron cargar tus viajes: $e';
        _tripsLoading = false;
      });
    }
  }

  Future<void> _acceptOffer(Oportunidad trip) async {
    if (trip.id == null) return;
    try {
      final updated = await OportunidadService.aceptarOfertaCamionero(trip.id!);
      if (!mounted) return;
      _replaceTrip(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Oferta aceptada. El viaje quedó con ese transportista.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadFleetSummary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aceptar la oferta: $e')),
      );
    }
  }

  Future<void> _sendCounterOffer(Oportunidad trip) async {
    if (trip.id == null) return;

    final controller = TextEditingController(
      text: ((trip.negociacion.precioOfertado ?? trip.precio) * 1.02)
          .toStringAsFixed(0),
    );

    final result = await showDialog<double>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Enviar contraoferta'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nuevo valor COP',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final value = double.tryParse(
                    controller.text.trim().replaceAll(',', ''),
                  );
                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('Enviar'),
              ),
            ],
          ),
    );

    controller.dispose();
    if (result == null || result <= 0) return;

    try {
      final updated = await OportunidadService.enviarContraofertaPrecio(
        oportunidadId: trip.id!,
        precioContraoferta: result,
      );
      if (!mounted) return;
      _replaceTrip(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraoferta enviada al transportista.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la contraoferta: $e')),
      );
    }
  }

  Future<void> _cancelNegotiation(Oportunidad trip) async {
    if (trip.id == null) return;
    try {
      final updated = await OportunidadService.cancelarOfertaPrecio(trip.id!);
      if (!mounted) return;
      _replaceTrip(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Negociación cancelada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar la negociación: $e')),
      );
    }
  }

  void _replaceTrip(Oportunidad updated) {
    setState(() {
      final index = _createdTrips.indexWhere((item) => item.id == updated.id);
      if (index == -1) return;
      _createdTrips[index] = updated;
    });
  }

  bool _isNegotiationTrip(Oportunidad trip) {
    return trip.negociacion.estado == 'oferta_camionero' ||
        trip.negociacion.estado == 'contraoferta_contratista';
  }

  List<Oportunidad> get _filteredTrips {
    final filtered =
        _createdTrips.where((trip) {
          switch (_tripFilter) {
            case 'disponible':
              return trip.estado == 'disponible';
            case 'negociacion':
              return _isNegotiationTrip(trip);
            case 'asignada':
              return trip.estado == 'asignada' || trip.estado == 'aceptada';
            case 'en_ruta':
              return trip.estado == 'en_ruta';
            case 'entregada':
              return trip.estado == 'entregada';
            default:
              return true;
          }
        }).toList();

    filtered.sort((a, b) {
      final priorityComparison = _priorityForTrip(
        a,
      ).compareTo(_priorityForTrip(b));
      if (priorityComparison != 0) return priorityComparison;

      final aDate =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  int _priorityForTrip(Oportunidad trip) {
    if (_isNegotiationTrip(trip)) return 0;
    if (trip.estado == 'en_ruta') return 1;
    if (trip.estado == 'asignada' || trip.estado == 'aceptada') return 2;
    if (trip.estado == 'disponible') return 3;
    if (trip.estado == 'entregada') return 4;
    return 5;
  }

  int _countForFilter(String filter) {
    if (filter == 'todas') return _createdTrips.length;
    return _createdTrips.where((trip) {
      switch (filter) {
        case 'disponible':
          return trip.estado == 'disponible';
        case 'negociacion':
          return _isNegotiationTrip(trip);
        case 'asignada':
          return trip.estado == 'asignada' || trip.estado == 'aceptada';
        case 'en_ruta':
          return trip.estado == 'en_ruta';
        case 'entregada':
          return trip.estado == 'entregada';
        default:
          return false;
      }
    }).length;
  }

  int get _activeCount =>
      _fleet.where((f) => f.hasLocation && !f.isOffline && !f.isStale).length;
  int get _staleCount => _fleet.where((f) => f.isStale).length;
  int get _offlineCount => _fleet.where((f) => f.isOffline).length;
  int get _noLocationCount =>
      _fleet.where((f) => !f.hasLocation || !f.coordinatesValid).length;

  Future<void> _logout() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final location = Provider.of<LocationService>(context, listen: false);
    await SessionBootstrap.teardownSession(location: location);
    await auth.logout();
  }

  Future<void> _pickContractorAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _contractorAvatarBytes = bytes);
      await context.read<AuthService>().actualizarPerfil({
        'fotoPerfil': 'data:image/jpeg;base64,${base64Encode(bytes)}',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto de perfil guardada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la foto: $e')),
      );
    }
  }

  Future<void> _editOperationalProfile(User usuario) async {
    final descripcionController = TextEditingController(
      text: usuario.descripcionOperacion ?? '',
    );
    final anioController = TextEditingController(
      text: usuario.anioFundacion?.toString() ?? '',
    );
    final ubicacionController = TextEditingController(
      text: usuario.ubicacionEmpresa ?? '',
    );
    final sitioController = TextEditingController(text: usuario.sitioWeb ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Datos operacionales'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: anioController,
                    decoration: const InputDecoration(
                      labelText: 'Año de fundación',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: ubicacionController,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación de la empresa',
                    ),
                  ),
                  TextField(
                    controller: sitioController,
                    decoration: const InputDecoration(labelText: 'Sitio web'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop({
                    'descripcionOperacion': descripcionController.text.trim(),
                    'anioFundacion': int.tryParse(anioController.text.trim()),
                    'ubicacionEmpresa': ubicacionController.text.trim(),
                    'sitioWeb': sitioController.text.trim(),
                  });
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );

    descripcionController.dispose();
    anioController.dispose();
    ubicacionController.dispose();
    sitioController.dispose();

    if (result == null || !mounted) return;
    await context.read<AuthService>().actualizarPerfil(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos operacionales guardados')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          _titleForIndex(_selectedIndex),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              onPressed: _refreshDashboard,
              icon: OperationalSvgIcon(
                OperationalSvgIcons.refreshCw,
                color: AppColors.emerald300,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
              tooltip: 'Actualizar operaciones',
            ),
          IconButton(
            onPressed: _logout,
            icon: OperationalSvgIcon(
              OperationalSvgIcons.logOut,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      backgroundColor: AppColors.inkBlack,
      body: PremiumGradientScaffold(
        safeArea: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomePage(),
            CrearOportunidadScreen(
              embedded: true,
              onPublished: () {
                setState(() => _selectedIndex = 0);
                _refreshDashboard();
              },
            ),
            SeguimientoScreen(onTripCompleted: _refreshDashboard),
            _buildPerfilContratista(),
          ],
        ),
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
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Operaciones',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Crear viaje',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Flota',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton.extended(
                onPressed: () => setState(() => _selectedIndex = 2),
                icon: const OperationalSvgIcon(
                  OperationalSvgIcons.route,
                  color: Colors.white,
                ),
                label: const Text('Ver flota en mapa'),
              )
              : null,
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Nueva oportunidad';
      case 2:
        return 'Seguimiento de flota';
      case 3:
        return 'Perfil';
      default:
        return 'Panel operativo';
    }
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumScreenHeader(
              eyebrow: 'Contratista',
              title: 'Centro operativo',
              subtitle:
                  '${widget.usuario.empresa ?? 'Contratista'} · cargas, flota y seguimiento en vivo.',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_fleetLoading)
              const PremiumGlassCard(
                child: Column(
                  children: [
                    OperationalSkeleton(height: 14, width: double.infinity),
                    SizedBox(height: AppSpacing.sm),
                    OperationalSkeleton(height: 14, width: 200),
                  ],
                ),
              )
            else if (_fleetError != null)
              PremiumGlassCard(
                child: OperationalErrorState(
                  message: _fleetError!,
                  onRetry: _loadFleetSummary,
                ),
              )
            else
              _buildFleetSummaryCard(),
            const SizedBox(height: AppSpacing.lg),
            PremiumGlassCard(
              onTap: () => setState(() => _selectedIndex = 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.add_road, color: AppColors.emerald400),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Publicar carga',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Crea una oportunidad con origen, destino y precio reales.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.graphite300,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => setState(() => _selectedIndex = 1),
                      child: const Text('Crear oportunidad'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildCreatedTripsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedTripsSection() {
    if (_tripsLoading) {
      return const PremiumGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tus viajes creados'),
            SizedBox(height: AppSpacing.md),
            OperationalSkeleton(height: 14, width: double.infinity),
            SizedBox(height: AppSpacing.sm),
            OperationalSkeleton(height: 14, width: 240),
          ],
        ),
      );
    }

    if (_tripsError != null) {
      return PremiumGlassCard(
        child: OperationalErrorState(
          message: _tripsError!,
          onRetry: _loadCreatedTrips,
        ),
      );
    }

    if (_createdTrips.isEmpty) {
      return PremiumGlassCard(
        child: OperationalEmptyState(
          icon: Icons.work_outline,
          title: 'Aún no has creado viajes',
          message: 'Publica tu primera carga y aquí verás todo el historial.',
          actionLabel: 'Crear viaje',
          onAction: () => setState(() => _selectedIndex = 1),
        ),
      );
    }

    final filtered = _filteredTrips;

    return PremiumGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProfileSectionHeader(
            title: 'Tus viajes creados',
            subtitle:
                'Gestiona ofertas, contraofertas y estados en tiempo real.',
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TripFilterChip(
                  label: 'Todas',
                  count: _countForFilter('todas'),
                  value: 'todas',
                  selectedValue: _tripFilter,
                  onSelected: (value) => setState(() => _tripFilter = value),
                ),
                _TripFilterChip(
                  label: 'Disponibles',
                  count: _countForFilter('disponible'),
                  value: 'disponible',
                  selectedValue: _tripFilter,
                  onSelected: (value) => setState(() => _tripFilter = value),
                ),
                _TripFilterChip(
                  label: 'En negociación',
                  count: _countForFilter('negociacion'),
                  value: 'negociacion',
                  selectedValue: _tripFilter,
                  onSelected: (value) => setState(() => _tripFilter = value),
                ),
                _TripFilterChip(
                  label: 'Asignadas',
                  count: _countForFilter('asignada'),
                  value: 'asignada',
                  selectedValue: _tripFilter,
                  onSelected: (value) => setState(() => _tripFilter = value),
                ),
                _TripFilterChip(
                  label: 'En ruta',
                  count: _countForFilter('en_ruta'),
                  value: 'en_ruta',
                  selectedValue: _tripFilter,
                  onSelected: (value) => setState(() => _tripFilter = value),
                ),
                _TripFilterChip(
                  label: 'Entregadas',
                  count: _countForFilter('entregada'),
                  value: 'entregada',
                  selectedValue: _tripFilter,
                  onSelected: (value) => setState(() => _tripFilter = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtered.isEmpty)
            const OperationalEmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Sin viajes en este filtro',
              message: 'Cambia el filtro para ver otros estados.',
            )
          else
            ...filtered.map(
              (trip) => _ContractorTripTile(
                trip: trip,
                onAcceptOffer: () => _acceptOffer(trip),
                onCounterOffer: () => _sendCounterOffer(trip),
                onCancelNegotiation: () => _cancelNegotiation(trip),
                onOpenFleet: () => setState(() => _selectedIndex = 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFleetSummaryCard() {
    if (_fleet.isEmpty) {
      return PremiumGlassCard(
        child: OperationalEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'Sin camioneros con ubicación',
          message:
              'Cuando un camionero afiliado envíe GPS válido, aparecerá en el mapa de seguimiento.',
          actionLabel: 'Abrir mapa de flota',
          onAction: () => setState(() => _selectedIndex = 2),
        ),
      );
    }

    return PremiumGlassCard(
      onTap: () => setState(() => _selectedIndex = 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_fleet.length} camionero(s) en flota',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _summaryChip('Activos', _activeCount, AppColors.statusActive),
              _summaryChip('Señal antigua', _staleCount, AppColors.statusStale),
              _summaryChip('Sin señal', _offlineCount, AppColors.statusOffline),
              if (_noLocationCount > 0)
                _summaryChip(
                  'Sin ubicación',
                  _noLocationCount,
                  AppColors.graphite700,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return OperationalStatusChip(
      label: '$label: $count',
      color: color,
      compact: true,
    );
  }

  Widget _buildPerfilContratista() {
    final usuario = context.watch<AuthService>().currentUser ?? widget.usuario;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumGlassCard(
            borderColor: AppColors.emerald400.withValues(alpha: 0.22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _pickContractorAvatar,
                      borderRadius: BorderRadius.circular(24),
                      child: _ContractorAvatar(
                        imageBytes: _contractorAvatarBytes,
                        name: usuario.nombre,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PremiumStatusPill(
                            label: 'Contratista',
                            color: AppColors.emerald400,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            usuario.nombre,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            usuario.empresa ?? 'Empresa sin registrar',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.graphite300),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  onPressed: _pickContractorAvatar,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cambiar foto'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProfileSectionHeader(
                  title: 'Datos de operación',
                  subtitle: 'Información pública para clientes y camioneros.',
                ),
                const SizedBox(height: AppSpacing.md),
                _profileRow('Correo', usuario.correo),
                _profileRow('Teléfono', usuario.telefono ?? 'Sin dato'),
                _profileRow('Empresa', usuario.empresa ?? 'Sin dato'),
                _profileRow(
                  'Descripción',
                  usuario.descripcionOperacion?.isNotEmpty == true
                      ? usuario.descripcionOperacion!
                      : 'Sin descripción',
                ),
                _profileRow(
                  'Año de fundación',
                  usuario.anioFundacion?.toString() ?? 'Sin dato',
                ),
                _profileRow(
                  'Ubicación',
                  usuario.ubicacionEmpresa?.isNotEmpty == true
                      ? usuario.ubicacionEmpresa!
                      : 'Sin dato',
                ),
                _profileRow(
                  'Sitio web',
                  usuario.sitioWeb?.isNotEmpty == true
                      ? usuario.sitioWeb!
                      : 'Sin dato',
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _editOperationalProfile(usuario),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar datos'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProfileSectionHeader(
                  title: 'Estado de flota',
                  subtitle: 'Resumen vivo, sin métricas simuladas.',
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _summaryChip(
                      'Activos',
                      _activeCount,
                      AppColors.statusActive,
                    ),
                    _summaryChip(
                      'Señal antigua',
                      _staleCount,
                      AppColors.statusStale,
                    ),
                    _summaryChip(
                      'Sin señal',
                      _offlineCount,
                      AppColors.statusOffline,
                    ),
                    _summaryChip(
                      'Sin ubicación',
                      _noLocationCount,
                      AppColors.graphite700,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.graphite300,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractorTripTile extends StatelessWidget {
  final Oportunidad trip;
  final VoidCallback onAcceptOffer;
  final VoidCallback onCounterOffer;
  final VoidCallback onCancelNegotiation;
  final VoidCallback onOpenFleet;

  const _ContractorTripTile({
    required this.trip,
    required this.onAcceptOffer,
    required this.onCounterOffer,
    required this.onCancelNegotiation,
    required this.onOpenFleet,
  });

  @override
  Widget build(BuildContext context) {
    final negotiation = trip.negociacion;
    final hasTruckerOffer = negotiation.estado == 'oferta_camionero';
    final hasCounterOffer = negotiation.estado == 'contraoferta_contratista';
    final hasAssignedTrucker = (trip.camioneroAsignado ?? '').isNotEmpty;
    final priority = _priorityMeta();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.titulo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PremiumStatusPill(label: priority.label, color: priority.color),
              const SizedBox(width: AppSpacing.xs),
              OperationalStatusChip.tracking(trip.estado, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${trip.origen} → ${trip.destino}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Precio actual: \$${trip.precio.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (trip.incentivoPrioridad > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Bono por prioridad: \$${trip.incentivoPrioridad.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.statusStale,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (trip.vehiculoPreferido != null ||
              trip.metodoPagoCarga != null ||
              trip.capacidadRequerida != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                if (trip.vehiculoPreferido != null)
                  _vehicleLabel(trip.vehiculoPreferido!),
                if (trip.capacidadRequerida != null)
                  '${trip.capacidadRequerida!.toStringAsFixed(trip.capacidadRequerida! % 1 == 0 ? 0 : 1)} ${trip.unidadCapacidad}',
                if (trip.metodoPagoCarga != null)
                  'Pago: ${_paymentLabel(trip.metodoPagoCarga!)}',
              ].join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
            ),
          ],
          if (negotiation.camionero != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Transportista: ${negotiation.camionero!.nombre}${negotiation.camionero!.telefono == null ? '' : ' · ${negotiation.camionero!.telefono}'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (hasTruckerOffer) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Oferta transportista: \$${(negotiation.precioOfertado ?? trip.precio).toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.emerald300,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (hasCounterOffer) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Contraoferta enviada: \$${(negotiation.precioContraoferta ?? trip.precio).toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.statusSyncing,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (hasTruckerOffer) ...[
                FilledButton.tonal(
                  onPressed: onAcceptOffer,
                  child: const Text('Aceptar oferta'),
                ),
                OutlinedButton(
                  onPressed: onCounterOffer,
                  child: const Text('Contraofertar'),
                ),
              ] else if (hasCounterOffer) ...[
                OutlinedButton(
                  onPressed: onCounterOffer,
                  child: const Text('Enviar otra contraoferta'),
                ),
              ],
              if (hasTruckerOffer || hasCounterOffer)
                OutlinedButton(
                  onPressed: onCancelNegotiation,
                  child: const Text('Cancelar negociación'),
                ),
              if (hasAssignedTrucker)
                FilledButton(
                  onPressed: onOpenFleet,
                  child: const Text('Ver en flota'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  ({String label, Color color}) _priorityMeta() {
    if (trip.prioridad == 'alta') {
      return (label: 'Prioridad alta', color: AppColors.alertCritical);
    }
    if (trip.prioridad == 'media') {
      return (label: 'Prioridad media', color: AppColors.statusStale);
    }
    if (trip.negociacion.estado == 'oferta_camionero') {
      return (label: 'Prioridad alta', color: AppColors.alertCritical);
    }
    if (trip.estado == 'en_ruta') {
      return (label: 'Prioridad alta', color: AppColors.statusSyncing);
    }
    if (trip.negociacion.estado == 'contraoferta_contratista' ||
        trip.estado == 'asignada' ||
        trip.estado == 'aceptada') {
      return (label: 'Prioridad media', color: AppColors.statusStale);
    }
    if (trip.estado == 'disponible') {
      return (label: 'Prioridad baja', color: AppColors.statusActive);
    }
    return (label: 'Prioridad baja', color: AppColors.graphite700);
  }

  String _vehicleLabel(String value) {
    const labels = {
      'camion_liviano_npr_nqr': 'Camión pequeño (NPR, NQR)',
      'camion_mediano_frr': 'Camión mediano (FRR)',
      'camion_grande_ftr_fvr_gh': 'Camión grande (FTR, FVR, GH)',
      'tractocamion': 'Tractocamión / mula',
      'camion_refrigerado': 'Camión refrigerado',
      'camion_plataforma': 'Camión plataforma',
      'volqueta': 'Volqueta',
      'camioneta_carga': 'Camioneta de carga',
      'otro': 'Otro',
    };
    return labels[value] ?? value;
  }

  String _paymentLabel(String value) {
    const labels = {
      'transferencia': 'Transferencia',
      'efectivo': 'Efectivo',
      'nequi': 'Nequi',
      'daviplata': 'Daviplata',
      'mixto': 'Mixto',
    };
    return labels[value] ?? value;
  }
}

class _TripFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _TripFilterChip({
    required this.label,
    required this.count,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ChoiceChip(
        label: Text('$label: $count'),
        selected: selected,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _ContractorAvatar extends StatelessWidget {
  final Uint8List? imageBytes;
  final String name;

  const _ContractorAvatar({required this.imageBytes, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials =
        name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return Container(
      width: 82,
      height: 82,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.emerald400.withValues(alpha: 0.34)),
        color: AppColors.emerald500.withValues(alpha: 0.12),
      ),
      child:
          imageBytes == null
              ? Center(
                child: Text(
                  initials.isEmpty ? 'CN' : initials,
                  style: const TextStyle(
                    color: AppColors.emerald300,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
              : Image.memory(imageBytes!, fit: BoxFit.cover),
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ProfileSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
        ),
      ],
    );
  }
}

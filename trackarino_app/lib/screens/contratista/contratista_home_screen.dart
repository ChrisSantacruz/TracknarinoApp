import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fleet_tracking_item.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../state/session_bootstrap.dart';
import '../../services/contratista_tracking_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/operational_card.dart';
import '../../widgets/operational/operational_empty_state.dart';
import '../../widgets/operational/operational_error_state.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../widgets/operational/operational_status_chip.dart';
import '../../widgets/operational/operational_svg_icon.dart';
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
  bool _fleetLoading = true;
  String? _fleetError;
  List<FleetTrackingItem> _fleet = [];

  @override
  void initState() {
    super.initState();
    _loadFleetSummary();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleForIndex(_selectedIndex),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              onPressed: _loadFleetSummary,
              icon: OperationalSvgIcon(
                OperationalSvgIcons.refreshCw,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              tooltip: 'Actualizar operaciones',
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
          _buildHomePage(),
          const CrearOportunidadScreen(embedded: true),
          const SeguimientoScreen(),
          _buildPerfilContratista(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
      onRefresh: _loadFleetSummary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, ${widget.usuario.nombre}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.usuario.empresa ?? 'Contratista',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Estado de flota',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_fleetLoading)
              const OperationalCard(
                child: Column(
                  children: [
                    OperationalSkeleton(height: 14, width: double.infinity),
                    SizedBox(height: AppSpacing.sm),
                    OperationalSkeleton(height: 14, width: 200),
                  ],
                ),
              )
            else if (_fleetError != null)
              OperationalCard(
                child: OperationalErrorState(
                  message: _fleetError!,
                  onRetry: _loadFleetSummary,
                ),
              )
            else
              _buildFleetSummaryCard(),
            const SizedBox(height: AppSpacing.lg),
            OperationalCard(
              onTap: () => setState(() => _selectedIndex = 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.add_road,
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
                    style: Theme.of(context).textTheme.bodySmall,
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
          ],
        ),
      ),
    );
  }

  Widget _buildFleetSummaryCard() {
    if (_fleet.isEmpty) {
      return OperationalCard(
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

    return OperationalCard(
      onTap: () => setState(() => _selectedIndex = 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_fleet.length} camionero(s) en flota',
                style: Theme.of(context).textTheme.titleMedium,
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
          const SizedBox(height: AppSpacing.md),
          Text(
            'Datos desde API de flota en tiempo real. Sin métricas estimadas.',
            style: Theme.of(context).textTheme.bodySmall,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: OperationalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perfil', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            _profileRow('Nombre', widget.usuario.nombre),
            _profileRow('Empresa', widget.usuario.empresa ?? '—'),
            _profileRow('Correo', widget.usuario.correo),
          ],
        ),
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
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

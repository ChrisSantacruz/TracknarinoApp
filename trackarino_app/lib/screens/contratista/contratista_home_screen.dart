import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/fleet_tracking_item.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
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
  bool _fleetLoading = true;
  String? _fleetError;
  List<FleetTrackingItem> _fleet = [];
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _contractorAvatarBytes;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto actualizada en esta sesión. Falta endpoint para persistirla.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la foto: $e')),
      );
    }
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
                _loadFleetSummary();
              },
            ),
            const SeguimientoScreen(),
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
      onRefresh: _loadFleetSummary,
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
          ],
        ),
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
          const SizedBox(height: AppSpacing.md),
          Text(
            'Datos desde API de flota en tiempo real. Sin métricas estimadas.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
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
                        name: widget.usuario.nombre,
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
                            widget.usuario.nombre,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.usuario.empresa ?? 'Empresa sin registrar',
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
                  subtitle: 'Información real de la sesión autenticada.',
                ),
                const SizedBox(height: AppSpacing.md),
                _profileRow('Correo', widget.usuario.correo),
                _profileRow('Teléfono', widget.usuario.telefono ?? 'Sin dato'),
                _profileRow('Empresa', widget.usuario.empresa ?? 'Sin dato'),
                _profileRow('Rol', widget.usuario.tipoUsuario),
                _profileRow('ID de cuenta', widget.usuario.id ?? 'Sin dato'),
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

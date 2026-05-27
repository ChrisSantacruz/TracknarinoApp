import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/premium_operational_widgets.dart';

class PerfilCamioneroScreen extends StatefulWidget {
  final User? usuario;
  final bool embedded;

  const PerfilCamioneroScreen({super.key, this.usuario, this.embedded = false});

  @override
  State<PerfilCamioneroScreen> createState() => _PerfilCamioneroScreenState();
}

class _PerfilCamioneroScreenState extends State<PerfilCamioneroScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<String> _metodosPago = ['Visa', 'Nequi', 'Efectivo'];
  String? _selectedMetodoPago;
  Uint8List? _avatarBytes;
  bool _isDisponible = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMetodoPago = widget.usuario?.metodoPago;
    _cargarEstadoInicial();
    _cargarPerfilCamionero();
  }

  Future<void> _cargarEstadoInicial() async {
    final authService = context.read<AuthService>();
    final disponible = await authService.obtenerEstadoDisponible();
    if (mounted) setState(() => _isDisponible = disponible);
  }

  Future<void> _cargarPerfilCamionero() async {
    setState(() => _isLoading = true);

    try {
      final usuario =
          await context.read<AuthService>().obtenerPerfilCamionero();
      if (usuario != null && mounted) {
        setState(() {
          _selectedMetodoPago = usuario.metodoPago;
          _isDisponible = usuario.isDisponible;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar perfil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      setState(() => _avatarBytes = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Imagen actualizada en esta sesión. Subida al servidor pendiente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar imagen: $e')),
      );
    }
  }

  Future<void> _actualizarMetodoPago(String metodoPago) async {
    final previous = _selectedMetodoPago;
    setState(() {
      _isLoading = true;
      _selectedMetodoPago = metodoPago;
    });

    try {
      await context.read<AuthService>().actualizarMetodoPago(metodoPago);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Método de pago actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectedMetodoPago = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDisponibilidad() async {
    setState(() => _isLoading = true);

    try {
      final nuevoEstado = !_isDisponible;
      final authService = context.read<AuthService>();
      final locationService = context.read<LocationService>();

      await authService.guardarEstadoDisponible(nuevoEstado);
      if (nuevoEstado) {
        await locationService.startTracking();
      } else {
        locationService.stopTracking();
      }

      if (!mounted) return;
      setState(() => _isDisponible = nuevoEstado);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Estado actualizado: ${_isDisponible ? 'disponible' : 'offline'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar disponibilidad: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      context.read<LocationService>().stopTracking();
      await context.read<AuthService>().logout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cerrar sesión: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final usuario = widget.usuario ?? authService.currentUser;

    if (usuario == null) {
      return const PremiumGradientScaffold(
        child: Center(child: Text('No hay información del usuario')),
      );
    }

    final body = PremiumGradientScaffold(
      safeArea: !widget.embedded,
      child: RefreshIndicator(
        onRefresh: _cargarPerfilCamionero,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (!widget.embedded)
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                title: const Text('Perfil'),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileHero(
                      usuario: usuario,
                      avatarBytes: _avatarBytes,
                      disponible: _isDisponible,
                      loading: _isLoading,
                      onAvatarTap: _pickImage,
                      onToggle: _toggleDisponibilidad,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetricsRow(usuario: usuario),
                    const SizedBox(height: AppSpacing.md),
                    _VehicleCard(usuario: usuario),
                    const SizedBox(height: AppSpacing.md),
                    _PaymentCard(
                      methods: _metodosPago,
                      selected: _selectedMetodoPago,
                      loading: _isLoading,
                      onSelected: _actualizarMetodoPago,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SettingsCard(onLogout: _cerrarSesion),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return body;
  }
}

class _ProfileHero extends StatelessWidget {
  final User usuario;
  final Uint8List? avatarBytes;
  final bool disponible;
  final bool loading;
  final VoidCallback onAvatarTap;
  final VoidCallback onToggle;

  const _ProfileHero({
    required this.usuario,
    required this.avatarBytes,
    required this.disponible,
    required this.loading,
    required this.onAvatarTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        disponible ? AppColors.emerald400 : AppColors.statusOffline;

    return PremiumGlassCard(
      borderColor: statusColor.withValues(alpha: 0.32),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.emerald400.withValues(alpha: 0.9),
                        AppColors.graphite800,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      avatarBytes == null
                          ? Stack(
                            children: [
                              Center(
                                child: Text(
                                  usuario.nombre.isEmpty
                                      ? 'TN'
                                      : usuario.nombre
                                          .trim()
                                          .substring(0, 1)
                                          .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 6,
                                bottom: 6,
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                          : Image.memory(avatarBytes!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombre,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      usuario.correo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.graphite300,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PremiumStatusPill(
                      label: disponible ? 'Disponible' : 'Offline',
                      color: statusColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estado operativo del conductor',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              loading
                  ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.emerald400,
                    ),
                  )
                  : Switch.adaptive(
                    value: disponible,
                    activeThumbColor: AppColors.emerald400,
                    onChanged: (_) => onToggle(),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final User usuario;

  const _MetricsRow({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final viajes = usuario.viajesCompletados?.toString() ?? 'Sin dato';
    final rating =
        usuario.calificacion == null
            ? 'Sin dato'
            : usuario.calificacion!.toStringAsFixed(1);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.45,
      children: [
        PremiumMetricTile(
          label: 'Viajes completados',
          value: viajes,
          icon: Icons.route_outlined,
        ),
        PremiumMetricTile(
          label: 'Calificación',
          value: rating,
          icon: Icons.star_border_rounded,
          color: AppColors.statusStale,
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final User usuario;

  const _VehicleCard({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final camion = usuario.camion ?? const {};
    final unidadCapacidad = camion['unidadCapacidad'] ?? 'kg';

    return PremiumGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumScreenHeader(
            eyebrow: 'Documentos',
            title: 'Vehículo y operación',
            subtitle: 'Datos reales del perfil del conductor.',
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumInfoRow(
            icon: Icons.local_shipping_outlined,
            label: 'Tipo',
            value: '${camion['tipoVehiculo'] ?? 'No especificado'}',
          ),
          PremiumInfoRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Placa',
            value: '${camion['placa'] ?? 'No especificada'}',
            color: AppColors.statusSyncing,
          ),
          PremiumInfoRow(
            icon: Icons.precision_manufacturing_outlined,
            label: 'Marca / modelo',
            value:
                '${camion['marca'] ?? 'No especificada'} ${camion['modelo'] ?? ''}'
                    .trim(),
            color: AppColors.statusStale,
          ),
          PremiumInfoRow(
            icon:
                unidadCapacidad == 'pasajeros'
                    ? Icons.groups_outlined
                    : Icons.scale_outlined,
            label: 'Capacidad',
            value:
                '${camion['capacidadCarga'] ?? 'No especificada'} $unidadCapacidad',
            color: AppColors.emerald300,
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final List<String> methods;
  final String? selected;
  final bool loading;
  final ValueChanged<String> onSelected;

  const _PaymentCard({
    required this.methods,
    required this.selected,
    required this.loading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Método de pago',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Selecciona solo métodos admitidos por el backend actual.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children:
                methods.map((method) {
                  final isSelected = method == selected;
                  return ChoiceChip(
                    label: Text(method),
                    selected: isSelected,
                    onSelected: loading ? null : (_) => onSelected(method),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final VoidCallback onLogout;

  const _SettingsCard({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Column(
        children: [
          PremiumInfoRow(
            icon: Icons.notifications_active_outlined,
            label: 'Notificaciones',
            value: 'Gestionadas por el servicio actual',
            color: AppColors.statusSyncing,
          ),
          PremiumInfoRow(
            icon: Icons.sync_outlined,
            label: 'Sincronización',
            value: 'Offline queue y realtime activos',
            color: AppColors.emerald400,
          ),
          PremiumInfoRow(
            icon: Icons.logout_rounded,
            label: 'Sesión',
            value: 'Cerrar sesión',
            color: AppColors.alertCritical,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

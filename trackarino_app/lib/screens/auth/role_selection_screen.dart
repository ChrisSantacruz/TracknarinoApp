import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../state/session_bootstrap.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/premium_operational_widgets.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _selectRole(String role) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final notification = context.read<NotificationService>();
      final location = context.read<LocationService>();
      await auth.configureRole(role);
      if (!mounted) return;
      await SessionBootstrap.applyAuthenticatedSession(
        auth: auth,
        notification: notification,
        location: location,
      );
    } on AuthFailure catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'No se pudo configurar el rol.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumGradientScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: PremiumGlassCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '¿Cómo quieres usar TrackNariño?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Este rol define tus permisos operativos en cargas, ofertas, seguimiento y alertas.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.graphite300,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: const TextStyle(color: AppColors.alertCritical)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _RoleTile(
                    title: 'Camionero',
                    subtitle: 'Ofertar, aceptar viajes y reportar ubicación.',
                    icon: Icons.local_shipping_outlined,
                    disabled: _loading,
                    onTap: () => _selectRole('camionero'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _RoleTile(
                    title: 'Contratista',
                    subtitle: 'Publicar cargas, gestionar ofertas y operaciones.',
                    icon: Icons.business_center_outlined,
                    disabled: _loading,
                    onTap: () => _selectRole('contratista'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _RoleTile(
                    title: 'Cliente',
                    subtitle: 'Crear cargas, comparar ofertas y seguir viajes.',
                    icon: Icons.inventory_2_outlined,
                    disabled: _loading,
                    onTap: () => _selectRole('cliente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool disabled;
  final VoidCallback onTap;

  const _RoleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.emerald400),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.graphite300,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

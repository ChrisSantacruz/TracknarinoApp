import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../state/session_bootstrap.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/operational_svg_icon.dart';
import '../../widgets/operational/premium_operational_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = context.read<AuthService>();
      final notificationService = context.read<NotificationService>();
      final locationService = context.read<LocationService>();
      await authService.signInWithGoogle();
      if (authService.phase == AuthBootstrapPhase.authenticated) {
        await SessionBootstrap.applyAuthenticatedSession(
          auth: authService,
          notification: notificationService,
          location: locationService,
        );
      }
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'No se pudo iniciar sesión con Google.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _enterSimulationMode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = context.read<AuthService>();
      final notificationService = context.read<NotificationService>();
      final locationService = context.read<LocationService>();
      await authService.startSimulationSession();
      if (authService.phase == AuthBootstrapPhase.authenticated) {
        await SessionBootstrap.applyAuthenticatedSession(
          auth: authService,
          notification: notificationService,
          location: locationService,
        );
      }
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'No se pudo iniciar el modo simulación.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumGradientScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/logo.png',
                              height: 54,
                              errorBuilder:
                                  (_, __, ___) => OperationalSvgIcon(
                                    OperationalSvgIcons.truck,
                                    color: AppColors.emerald400,
                                    size: 44,
                                  ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TrackNariño',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.7,
                                        ),
                                  ),
                                  Text(
                                    'Logística táctica en tiempo real',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.graphite300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        PremiumGlassCard(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const PremiumStatusPill(
                                label: 'Sistema operacional',
                                color: AppColors.emerald400,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Bienvenido a tu operación',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Accede para ver viajes, alertas, rutas y seguimiento en vivo.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.graphite300,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child:
                                    _errorMessage.isEmpty
                                        ? const SizedBox.shrink()
                                        : _AuthNotice(
                                          key: const ValueKey('error'),
                                          message: _errorMessage,
                                          color: AppColors.alertCritical,
                                        ),
                              ),
                              if (_errorMessage.isNotEmpty)
                                const SizedBox(height: AppSpacing.md),
                              _GoogleAuthButton(
                                enabled: !_isLoading,
                                loading: _isLoading,
                                onPressed:
                                    _isLoading ? null : _loginWithGoogle,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _SimulationModeCard(
                                enabled: !_isLoading,
                                onPressed:
                                    _isLoading ? null : _enterSimulationMode,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SimulationModeCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const _SimulationModeCard({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.emerald400.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.045),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.emerald400.withValues(alpha: 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald400.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.graphite950.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.emerald300.withValues(alpha: 0.36),
                  ),
                ),
                child: const Center(
                  child: OperationalSvgIcon(
                    OperationalSvgIcons.route,
                    color: AppColors.emerald300,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENTRAR EN MODO SIMULACIÓN',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sesión temporal de camionero para demo operacional.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.graphite300,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.emerald300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  final String message;
  final Color color;

  const _AuthNotice({super.key, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback? onPressed;

  const _GoogleAuthButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.graphite900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon:
              loading
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.g_mobiledata_rounded, size: 30),
          label: const Text(
            'Continuar con Google',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

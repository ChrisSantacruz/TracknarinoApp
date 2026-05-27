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
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = context.read<AuthService>();
      final notificationService = context.read<NotificationService>();
      final locationService = context.read<LocationService>();
      await authService.login(
        _correoController.text.trim(),
        _passwordController.text,
      );
      await SessionBootstrap.applyAuthenticatedSession(
        auth: authService,
        notification: notificationService,
        location: locationService,
      );
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage = 'No se pudo iniciar sesión. Intenta de nuevo.',
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
                              PremiumTextField(
                                controller: _correoController,
                                label: 'Correo operativo',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) return 'Ingresa tu correo';
                                  if (!email.contains('@')) {
                                    return 'Ingresa un correo válido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              PremiumTextField(
                                controller: _passwordController,
                                label: 'Contraseña',
                                icon: Icons.lock_outline_rounded,
                                obscureText: !_passwordVisible,
                                autofillHints: const [AutofillHints.password],
                                suffixIcon: IconButton(
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _passwordVisible =
                                                !_passwordVisible,
                                      ),
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.graphite300,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingresa tu contraseña';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald400.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.emerald400.withValues(
                                          alpha: 0.28,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.verified_user_outlined,
                                      color: AppColors.emerald400,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Restauración de sesión activa',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.graphite300,
                                          ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        _isLoading
                                            ? null
                                            : () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                          const ForgotPasswordScreen(),
                                                ),
                                              );
                                            },
                                    child: const Text('Recuperar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              PremiumPrimaryButton(
                                label: 'Iniciar sesión',
                                icon: Icons.arrow_forward_rounded,
                                loading: _isLoading,
                                onPressed: _isLoading ? null : _login,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _GoogleAuthPlaceholder(enabled: !_isLoading),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        pageBuilder:
                                            (_, animation, __) =>
                                                const RegisterScreen(),
                                        transitionsBuilder: (
                                          _,
                                          animation,
                                          __,
                                          child,
                                        ) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.04),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                          child: const Text('Crear cuenta operativa'),
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

class _GoogleAuthPlaceholder extends StatelessWidget {
  final bool enabled;

  const _GoogleAuthPlaceholder({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Center(
          child: Text(
            'Google requiere endpoint de autenticación habilitado',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.graphite300,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

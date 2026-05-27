import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/premium_operational_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGradientScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PremiumGlassCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PremiumStatusPill(
                          label: 'Recuperación',
                          color: AppColors.emerald400,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Restablecer contraseña',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'El backend actual no expone todavía un endpoint de recuperación. Dejamos el flujo visual preparado sin simular envío.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.graphite300),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PremiumTextField(
                          controller: _emailController,
                          label: 'Correo electrónico',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Ingresa tu correo';
                            if (!email.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PremiumPrimaryButton(
                          label: 'Endpoint pendiente',
                          onPressed: null,
                          icon: Icons.lock_reset_rounded,
                        ),
                      ],
                    ),
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

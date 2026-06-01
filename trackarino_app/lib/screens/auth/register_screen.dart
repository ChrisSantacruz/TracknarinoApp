import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../state/session_bootstrap.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/premium_operational_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _empresaController = TextEditingController();
  final _empresaAfiliadaController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _capacidadController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _placaController = TextEditingController();

  int _step = 0;
  String _selectedUserType = 'camionero';
  String _selectedVehicleType = _vehicleTypeOptions.first.value;
  String _capacityUnit = 'kg';
  DateTime? _licenseExpirationDate;
  bool _sinEmpresaAfiliada = false;
  bool _papelesAlDia = true;
  bool _isLoading = false;
  bool _passwordVisible = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    _empresaController.dispose();
    _empresaAfiliadaController.dispose();
    _cedulaController.dispose();
    _licenciaController.dispose();
    _capacidadController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final Map<String, dynamic> userData;

      if (_selectedUserType == 'camionero') {
        userData = {
          'nombre': _nombreController.text.trim(),
          'correo': _correoController.text.trim(),
          'contraseña': _passwordController.text,
          'tipoUsuario': 'camionero',
          'telefono': _telefonoController.text.trim(),
          'empresaAfiliada':
              _sinEmpresaAfiliada
                  ? null
                  : _empresaAfiliadaController.text.trim(),
          'licenciaVencimiento': _formatDate(_licenseExpirationDate!),
          'licenciaExpedicion': _formatDate(_licenseExpirationDate!),
          'numeroCedula': _cedulaController.text.trim(),
          'camion': {
            'tipoVehiculo': _selectedVehicleType,
            'capacidadCarga': int.parse(_capacidadController.text.trim()),
            'unidadCapacidad': _capacityUnit,
            'marca': _marcaController.text.trim(),
            'modelo': _modeloController.text.trim(),
            'placa': _placaController.text.trim().toUpperCase(),
            'papelesAlDia': _papelesAlDia,
          },
        };
      } else {
        userData = {
          'nombre': _nombreController.text.trim(),
          'correo': _correoController.text.trim(),
          'contraseña': _passwordController.text,
          'tipoUsuario': _selectedUserType,
          'telefono': _telefonoController.text.trim(),
          'empresa': _empresaController.text.trim(),
          if (_selectedUserType == 'contratista')
            'disponibleParaSolicitarCamioneros': true,
        };
      }

      final authService = context.read<AuthService>();
      final notificationService = context.read<NotificationService>();
      final locationService = context.read<LocationService>();
      await authService.register(userData);
      await SessionBootstrap.applyAuthenticatedSession(
        auth: authService,
        notification: notificationService,
        location: locationService,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() {
        _errorMessage =
            'No se pudo completar el registro. Verifica los datos e intenta de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (_step < 2) {
      setState(() {
        _step += 1;
        _errorMessage = '';
      });
      return;
    }
    _register();
  }

  void _previousStep() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _selectLicenseExpiration() async {
    final now = DateTime.now();
    final initialDate =
        _licenseExpirationDate ?? DateTime(now.year + 1, now.month, now.day);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 20),
      helpText: 'Vencimiento de licencia',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selectedDate == null) return;
    setState(() {
      _licenseExpirationDate = selectedDate;
      _licenciaController.text = _formatDate(selectedDate);
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumGradientScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isLoading ? null : _previousStep,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crear cuenta',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Perfil operacional TrackNariño',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.graphite300,
                        ),
                      ),
                    ],
                  ),
                ),
                PremiumStatusPill(
                  label: '${_step + 1}/3',
                  color: AppColors.emerald400,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.03, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: PremiumGlassCard(
                        key: ValueKey(_step),
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StepHeader(step: _step, role: _selectedUserType),
                            const SizedBox(height: AppSpacing.lg),
                            if (_errorMessage.isNotEmpty) ...[
                              _RegisterNotice(message: _errorMessage),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            ..._fieldsForStep(),
                            const SizedBox(height: AppSpacing.xl),
                            PremiumPrimaryButton(
                              label: _step == 2 ? 'Crear cuenta' : 'Continuar',
                              icon:
                                  _step == 2
                                      ? Icons.verified_user_outlined
                                      : Icons.arrow_forward_rounded,
                              loading: _isLoading,
                              onPressed: _isLoading ? null : _nextStep,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextButton(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () => Navigator.of(context).maybePop(),
                              child: const Text('Ya tengo una cuenta'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fieldsForStep() {
    switch (_step) {
      case 0:
        return [
          PremiumTextField(
            controller: _nombreController,
            label: 'Nombre completo',
            icon: Icons.person_outline_rounded,
            validator: _required('Ingresa tu nombre'),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumTextField(
            controller: _correoController,
            label: 'Correo electrónico',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Ingresa tu correo';
              if (!email.contains('@')) return 'Ingresa un correo válido';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumTextField(
            controller: _passwordController,
            label: 'Contraseña',
            icon: Icons.lock_outline_rounded,
            obscureText: !_passwordVisible,
            suffixIcon: IconButton(
              onPressed:
                  () => setState(() => _passwordVisible = !_passwordVisible),
              icon: Icon(
                _passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.graphite300,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa una contraseña';
              }
              if (value.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumTextField(
            controller: _telefonoController,
            label: 'Teléfono',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: _required('Ingresa tu teléfono'),
          ),
        ];
      case 1:
        return [
          Row(
            children: [
              PremiumChoicePill<String>(
                value: 'camionero',
                groupValue: _selectedUserType,
                onSelected:
                    (value) => setState(() => _selectedUserType = value),
                title: 'Camionero',
                subtitle: 'Acepta, negocia y ejecuta viajes',
                icon: Icons.local_shipping_outlined,
              ),
              const SizedBox(width: AppSpacing.sm),
              PremiumChoicePill<String>(
                value: 'contratista',
                groupValue: _selectedUserType,
                onSelected:
                    (value) => setState(() => _selectedUserType = value),
                title: 'Contratista',
                subtitle: 'Publica cargas y sigue flota',
                icon: Icons.business_center_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              PremiumChoicePill<String>(
                value: 'cliente',
                groupValue: _selectedUserType,
                onSelected:
                    (value) => setState(() => _selectedUserType = value),
                title: 'Cliente',
                subtitle: 'Crea una carga y monitorea su viaje',
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            switch (_selectedUserType) {
              'camionero' =>
                'El perfil de camionero requiere datos de vehículo para habilitar operación.',
              'cliente' =>
                'El perfil de cliente puede crear una carga activa y monitorear su viaje.',
              _ =>
                'El perfil de contratista requiere empresa para crear oportunidades reales.',
            },
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.graphite300),
          ),
        ];
      default:
        return _selectedUserType == 'camionero'
            ? _driverFields()
            : _organizationFields(_selectedUserType);
    }
  }

  List<Widget> _driverFields() {
    return [
      PremiumTextField(
        controller: _empresaAfiliadaController,
        label: 'Empresa afiliada',
        hint:
            _sinEmpresaAfiliada
                ? 'Camionero independiente'
                : 'Nombre de la empresa afiliada',
        icon: Icons.business_outlined,
        readOnly: _sinEmpresaAfiliada,
        validator:
            _sinEmpresaAfiliada
                ? null
                : _required(
                  'Ingresa empresa afiliada o marca la opción independiente',
                ),
      ),
      const SizedBox(height: AppSpacing.sm),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _sinEmpresaAfiliada,
        activeColor: AppColors.emerald400,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (value) {
          setState(() {
            _sinEmpresaAfiliada = value ?? false;
            if (_sinEmpresaAfiliada) {
              _empresaAfiliadaController.clear();
            }
          });
        },
        title: const Text('No tengo empresa afiliada'),
        subtitle: const Text(
          'Podrás operar como camionero independiente y aceptar cargas disponibles.',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      PremiumTextField(
        controller: _cedulaController,
        label: 'Número de cédula',
        icon: Icons.badge_outlined,
        keyboardType: TextInputType.number,
        validator: _required('Ingresa tu cédula'),
      ),
      const SizedBox(height: AppSpacing.md),
      PremiumTextField(
        controller: _licenciaController,
        label: 'Vencimiento de licencia',
        hint: 'Selecciona una fecha',
        icon: Icons.calendar_today_outlined,
        readOnly: true,
        onTap: _selectLicenseExpiration,
        suffixIcon: IconButton(
          onPressed: _selectLicenseExpiration,
          icon: const Icon(
            Icons.event_available_outlined,
            color: AppColors.graphite300,
          ),
        ),
        validator: (value) {
          if (_licenseExpirationDate == null) {
            return 'Selecciona el vencimiento de licencia';
          }
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: _VehicleTypeDropdown(
              value: _selectedVehicleType,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedVehicleType = value;
                  _capacityUnit = _defaultCapacityUnitForVehicle(value);
                });
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PremiumTextField(
              controller: _capacidadController,
              label:
                  _capacityUnit == 'toneladas'
                      ? 'Capacidad toneladas'
                      : 'Capacidad kg',
              icon: Icons.scale_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed <= 0) return 'Capacidad válida';
                return null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      _CapacityUnitSelector(
        value: _capacityUnit,
        onChanged: (value) => setState(() => _capacityUnit = value),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: PremiumTextField(
              controller: _marcaController,
              label: 'Marca',
              icon: Icons.precision_manufacturing_outlined,
              validator: _required('Ingresa la marca'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PremiumTextField(
              controller: _modeloController,
              label: 'Modelo',
              icon: Icons.event_outlined,
              keyboardType: TextInputType.number,
              validator: _required('Ingresa el modelo'),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      PremiumTextField(
        controller: _placaController,
        label: 'Placa',
        icon: Icons.confirmation_number_outlined,
        validator: _required('Ingresa la placa'),
      ),
      const SizedBox(height: AppSpacing.sm),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _papelesAlDia,
        activeThumbColor: AppColors.emerald400,
        onChanged: (value) => setState(() => _papelesAlDia = value),
        title: const Text('Documentos operativos vigentes'),
        subtitle: const Text('Licencia, SOAT, técnico-mecánica y propiedad'),
      ),
    ];
  }

  List<Widget> _organizationFields(String role) {
    final isClient = role == 'cliente';

    return [
      PremiumTextField(
        controller: _empresaController,
        label: isClient ? 'Empresa o nombre comercial' : 'Empresa',
        hint:
            isClient
                ? 'Opcional si publicarás como persona natural'
                : 'Nombre de la empresa contratante',
        icon:
            isClient
                ? Icons.storefront_outlined
                : Icons.business_center_outlined,
        validator: isClient ? null : _required('Ingresa la empresa'),
      ),
    ];
  }

  String? Function(String?) _required(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }
}

String _defaultCapacityUnitForVehicle(String vehicleType) {
  return 'kg';
}

class _VehicleTypeOption {
  final String value;
  final String label;

  const _VehicleTypeOption({required this.value, required this.label});
}

const _vehicleTypeOptions = [
  _VehicleTypeOption(
    value: 'camion_liviano_npr_nqr',
    label: 'Camión carga pequeño (NPR, NQR)',
  ),
  _VehicleTypeOption(
    value: 'camion_mediano_frr',
    label: 'Camión carga mediano (FRR)',
  ),
  _VehicleTypeOption(
    value: 'camion_grande_ftr_fvr_gh',
    label: 'Camión carga grande (FTR, FVR, GH)',
  ),
  _VehicleTypeOption(value: 'tractocamion', label: 'Tractocamión / mula'),
  _VehicleTypeOption(value: 'camion_refrigerado', label: 'Camión refrigerado'),
  _VehicleTypeOption(value: 'camion_plataforma', label: 'Camión plataforma'),
  _VehicleTypeOption(value: 'volqueta', label: 'Volqueta'),
  _VehicleTypeOption(value: 'camioneta_carga', label: 'Camioneta de carga'),
];

class _VehicleTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _VehicleTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppColors.graphite900,
      iconEnabledColor: AppColors.graphite300,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: const InputDecoration(
        labelText: 'Tipo de vehículo',
        prefixIcon: Icon(
          Icons.local_shipping_outlined,
          color: AppColors.graphite300,
        ),
      ),
      items:
          _vehicleTypeOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
              .toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Selecciona tipo de vehículo';
        }
        return null;
      },
    );
  }
}

class _CapacityUnitSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CapacityUnitSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        ChoiceChip(
          selected: value == 'kg',
          label: const Text('Capacidad en kg'),
          avatar: const Icon(Icons.scale_outlined, size: 18),
          onSelected: (_) => onChanged('kg'),
        ),
        ChoiceChip(
          selected: value == 'toneladas',
          label: const Text('Capacidad en toneladas'),
          avatar: const Icon(Icons.local_shipping_outlined, size: 18),
          onSelected: (_) => onChanged('toneladas'),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final String role;

  const _StepHeader({required this.step, required this.role});

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Identidad operacional',
      'Rol dentro de la red',
      switch (role) {
        'camionero' => 'Vehículo y documentos',
        'cliente' => 'Perfil de cliente',
        _ => 'Empresa contratante',
      },
    ];
    final subtitles = [
      'Datos base para autenticar y restaurar sesión.',
      'Define qué experiencia y permisos se habilitan.',
      switch (role) {
        'camionero' =>
          'Información requerida por el backend actual para operar viajes.',
        'cliente' => 'Datos para publicar y monitorear tu carga activa.',
        _ =>
          'Información requerida por el backend actual para publicar cargas.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (index) {
            final active = index <= step;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 4,
                margin: EdgeInsets.only(right: index == 2 ? 0 : AppSpacing.xs),
                decoration: BoxDecoration(
                  color:
                      active
                          ? AppColors.emerald400
                          : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          titles[step],
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitles[step],
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.graphite300),
        ),
      ],
    );
  }
}

class _RegisterNotice extends StatelessWidget {
  final String message;

  const _RegisterNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.alertCritical.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.alertCritical.withValues(alpha: 0.32),
        ),
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

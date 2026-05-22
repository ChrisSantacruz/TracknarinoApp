import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../state/session_bootstrap.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/loading_widget.dart';

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
  
  // Campos para contratista
  final _empresaController = TextEditingController();
  
  // Campos para camionero
  final _empresaAfiliadaController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _tipoVehiculoController = TextEditingController();
  final _capacidadController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _placaController = TextEditingController();
  bool _papelesAlDia = true;
  
  String _selectedUserType = 'camionero';
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
  }

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
    _tipoVehiculoController.dispose();
    _capacidadController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Datos exactamente como los necesita la API
        final Map<String, dynamic> userData;
        
        if (_selectedUserType == 'camionero') {
          userData = {
            "nombre": _nombreController.text.trim(),
            "correo": _correoController.text.trim(),
            "contraseña": _passwordController.text,
            "tipoUsuario": "camionero",
            "telefono": _telefonoController.text.trim(),
            "empresaAfiliada": _empresaAfiliadaController.text.trim(),
            "licenciaExpedicion": _licenciaController.text.trim(),
            "numeroCedula": _cedulaController.text.trim(),
            "camion": {
              "tipoVehiculo": _tipoVehiculoController.text.trim(),
              "capacidadCarga": int.parse(_capacidadController.text.isEmpty ? "1000" : _capacidadController.text.trim()),
              "marca": _marcaController.text.trim(),
              "modelo": _modeloController.text.trim(),
              "placa": _placaController.text.trim(),
              "papelesAlDia": _papelesAlDia
            }
          };
        } else {
          userData = {
            "nombre": _nombreController.text.trim(),
            "correo": _correoController.text.trim(),
            "contraseña": _passwordController.text,
            "tipoUsuario": "contratista",
            "telefono": _telefonoController.text.trim(),
            "empresa": _empresaController.text.trim(),
            "disponibleParaSolicitarCamioneros": true
          };
        }

        final authService = context.read<AuthService>();
        await authService.register(userData);
        await SessionBootstrap.applyAuthenticatedSession(
          auth: authService,
          notification: context.read<NotificationService>(),
          location: context.read<LocationService>(),
        );
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } on AuthFailure catch (e) {
        setState(() => _errorMessage = e.message);
      } catch (_) {
        setState(() {
          _errorMessage = 'No se pudo completar el registro. Intenta de nuevo.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrarse'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading 
          ? const LoadingWidget(message: 'Registrando usuario...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tipo de usuario
                    const Text(
                      'Tipo de usuario:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Opciones de tipo de usuario
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'camionero',
                          label: Text('Camionero'),
                          icon: Icon(Icons.local_shipping),
                        ),
                        ButtonSegment(
                          value: 'contratista',
                          label: Text('Contratista'),
                          icon: Icon(Icons.business),
                        ),
                      ],
                      selected: {_selectedUserType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedUserType = newSelection.first;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Mensaje de error si existe
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade800),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Campos comunes para todos los usuarios
                    _buildSection('Información Personal', [
                      // Nombre
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese su nombre';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Correo
                      TextFormField(
                        controller: _correoController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese su correo';
                          }
                          if (!value.contains('@')) {
                            return 'Ingrese un correo válido';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese una contraseña';
                          }
                          if (value.length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Teléfono
                      TextFormField(
                        controller: _telefonoController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese su teléfono';
                          }
                          return null;
                        },
                      ),
                    ]),
                    
                    const SizedBox(height: 24),
                    
                    // Campos específicos según tipo de usuario
                    if (_selectedUserType == 'camionero') ...[
                      _buildSection('Información del Camionero', [
                        // Empresa afiliada
                        TextFormField(
                          controller: _empresaAfiliadaController,
                          decoration: const InputDecoration(
                            labelText: 'Empresa afiliada',
                            prefixIcon: Icon(Icons.business),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Número de cédula
                        TextFormField(
                          controller: _cedulaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Número de cédula',
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese su número de cédula';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Fecha de licencia
                        TextFormField(
                          controller: _licenciaController,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de vencimiento licencia (YYYY-MM-DD)',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese la fecha de vencimiento';
                            }
                            // Validación simple de formato de fecha
                            RegExp dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                            if (!dateRegex.hasMatch(value)) {
                              return 'Formato de fecha inválido (YYYY-MM-DD)';
                            }
                            return null;
                          },
                        ),
                      ]),
                      
                      const SizedBox(height: 24),
                      
                      _buildSection('Información del Vehículo', [
                        // Tipo de vehículo
                        TextFormField(
                          controller: _tipoVehiculoController,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de vehículo',
                            prefixIcon: Icon(Icons.local_shipping),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese el tipo de vehículo';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Capacidad de carga
                        TextFormField(
                          controller: _capacidadController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Capacidad de carga (kg)',
                            prefixIcon: Icon(Icons.scale),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese la capacidad de carga';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Marca
                        TextFormField(
                          controller: _marcaController,
                          decoration: const InputDecoration(
                            labelText: 'Marca del vehículo',
                            prefixIcon: Icon(Icons.directions_car),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Modelo
                        TextFormField(
                          controller: _modeloController,
                          decoration: const InputDecoration(
                            labelText: 'Modelo/Año del vehículo',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Placa
                        TextFormField(
                          controller: _placaController,
                          decoration: const InputDecoration(
                            labelText: 'Placa del vehículo',
                            prefixIcon: Icon(Icons.tag),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese la placa del vehículo';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Papeles al día
                        SwitchListTile(
                          title: const Text('Papeles al día'),
                          value: _papelesAlDia,
                          onChanged: (bool value) {
                            setState(() {
                              _papelesAlDia = value;
                            });
                          },
                          secondary: Icon(
                            _papelesAlDia ? Icons.check_circle : Icons.warning,
                            color: _papelesAlDia ? Colors.green : Colors.orange,
                          ),
                        ),
                      ]),
                    ],
                    
                    // Campos específicos para contratista
                    if (_selectedUserType == 'contratista') ...[
                      _buildSection('Información de la Empresa', [
                        // Nombre de empresa
                        TextFormField(
                          controller: _empresaController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la empresa',
                            prefixIcon: Icon(Icons.business),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese el nombre de la empresa';
                            }
                            return null;
                          },
                        ),
                      ]),
                    ],
                    
                    const SizedBox(height: 30),
                    
                    // Botón de registro
                    ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('REGISTRARSE'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Opción para ir a la pantalla de login
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        '¿Ya tienes una cuenta? Inicia sesión',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
  
  // Helper para crear secciones con título y contenido
  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
} 
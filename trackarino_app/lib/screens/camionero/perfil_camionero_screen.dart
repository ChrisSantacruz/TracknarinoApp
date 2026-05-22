import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PerfilCamioneroScreen extends StatefulWidget {
  final User? usuario;
  final bool embedded;

  const PerfilCamioneroScreen({
    super.key,
    this.usuario,
    this.embedded = false,
  });

  @override
  State<PerfilCamioneroScreen> createState() => _PerfilCamioneroScreenState();
}

class _PerfilCamioneroScreenState extends State<PerfilCamioneroScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final List<String> _metodosPago = ['Visa', 'Nequi', 'Efectivo'];
  String? _selectedMetodoPago;
  bool _isDisponible = true;
  
  final Map<String, dynamic> _estadisticas = {
    'viajesCompletados': null,
    'kilometrosRecorridos': null,
    'calificacionPromedio': null,
    'ingresosMes': null,
  };

  @override
  void initState() {
    super.initState();
    _selectedMetodoPago = widget.usuario?.metodoPago;
    _cargarEstadoInicial();
    _cargarPerfilCamionero();
    
    // Inicializar estadísticas con datos del usuario si están disponibles
    if (widget.usuario != null) {
      final usuario = widget.usuario!;
      if (usuario.calificacion != null || usuario.viajesCompletados != null) {
        _estadisticas['viajesCompletados'] = usuario.viajesCompletados ?? 0;
        _estadisticas['calificacionPromedio'] = usuario.calificacion ?? 0.0;
      }
    }
  }
  
  // Cargar estado inicial de disponibilidad
  Future<void> _cargarEstadoInicial() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final disponible = await authService.obtenerEstadoDisponible();
    if (mounted) {
      setState(() {
        _isDisponible = disponible;
      });
    }
  }
  
  // Cargar datos del perfil desde el backend
  Future<void> _cargarPerfilCamionero() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Obtener datos del perfil desde el backend
      final authService = Provider.of<AuthService>(context, listen: false);
      final usuario = await authService.obtenerPerfilCamionero();
      
      if (usuario != null) {
        setState(() {
          _selectedMetodoPago = usuario.metodoPago;
          _isDisponible = usuario.isDisponible;
          // Actualizar otras estadísticas si es necesario
        });
      }
    } catch (e) {
      debugPrint('Error al cargar perfil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Función para seleccionar una foto de perfil
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        // En Flutter Web, usar Network/Memory image en lugar de File
        final bytes = await pickedFile.readAsBytes();
        
        setState(() {
          // Guardar la ruta para referencia
          _profileImage = File(pickedFile.path);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagen seleccionada. Funcionalidad de subida pendiente.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        // TODO: Aquí iría el código para subir la imagen al servidor
        // await _subirImagenAlServidor(bytes);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  // Función para actualizar método de pago
  Future<void> _actualizarMetodoPago(String metodoPago) async {
    setState(() {
      _isLoading = true;
      _selectedMetodoPago = metodoPago;
    });

    try {
      await Provider.of<AuthService>(context, listen: false).actualizarMetodoPago(metodoPago);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Método de pago actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedMetodoPago = widget.usuario?.metodoPago;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Función para actualizar disponibilidad
  Future<void> _toggleDisponibilidad() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final nuevoEstado = !_isDisponible;
      
      // Guardar en AuthService
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.guardarEstadoDisponible(nuevoEstado);
      
      // Iniciar o detener el servicio de ubicación según disponibilidad
      final locationService = Provider.of<LocationService>(context, listen: false);
      if (nuevoEstado) {
        await locationService.startTracking();
      } else {
        locationService.stopTracking();
      }
      
      setState(() {
        _isDisponible = nuevoEstado;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ahora estás ${_isDisponible ? 'disponible' : 'no disponible'} para viajes')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar disponibilidad: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Función para cerrar sesión
  Future<void> _cerrarSesion() async {
    try {
      // Detener el servicio de ubicación antes de cerrar sesión
      final locationService = Provider.of<LocationService>(context, listen: false);
      locationService.stopTracking();
      
      await Provider.of<AuthService>(context, listen: false).logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  // Función para registrar un vehículo
  Future<void> _registrarVehiculo() async {
    // Aquí iría el código para registrar el vehículo
    // Por ejemplo, mostrar un formulario para ingresar los datos del vehículo
    // y luego enviar estos datos al servidor
    debugPrint('Registrar vehículo');
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final usuario = widget.usuario ?? authService.currentUser;

    if (usuario == null) {
      return const Center(child: Text('No hay información del usuario'));
    }

    final body = RefreshIndicator(
        onRefresh: _cargarPerfilCamionero,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Banner superior con foto de perfil
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Banner superior
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withAlpha(179), // 0.7 * 255 = 178.5 ≈ 179
                        ],
                      ),
                    ),
                  ),
                  
                  // Foto de perfil
                  Positioned(
                    bottom: -50,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 56,
                          backgroundImage: _profileImage != null 
                            ? FileImage(_profileImage!) as ImageProvider
                            : const AssetImage('assets/images/default_profile.png'),
                          backgroundColor: Colors.grey[200],
                          child: _profileImage == null 
                            ? Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.grey[400],
                              )
                            : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Información del perfil
              const SizedBox(height: 60),
              
              // Nombre del usuario
              Text(
                usuario.nombre,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              // Correo
              Text(
                usuario.correo,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 16),
              
              _buildRatingSummary(),
              
              const SizedBox(height: 24),
              
              // Estado del camionero con toggle
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: _isDisponible 
                    ? Colors.green.withAlpha(26) // 0.1 * 255 = 25.5 ≈ 26
                    : Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isDisponible ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isDisponible ? 'Disponible' : 'No disponible',
                      style: TextStyle(
                        color: _isDisponible ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _isDisponible,
                          onChanged: (_) => _toggleDisponibilidad(),
                          activeColor: Colors.green,
                        ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Estadísticas del camionero
              _buildStatsGrid(),
              
              const SizedBox(height: 16),
              
              // Secciones de información
              _buildInfoSection('Información Personal', [
                _buildInfoRow('Teléfono', usuario.telefono ?? 'No especificado'),
                _buildInfoRow('Empresa afiliada', usuario.empresaAfiliada ?? 'No especificada'),
                _buildInfoRow('Documento', usuario.numeroCedula ?? 'No especificado'),
              ]),
              
              _buildInfoSection('Información del Camión', [
                _buildInfoRow('Tipo', usuario.camion?['tipoVehiculo'] ?? 'No especificado'),
                _buildInfoRow('Placa', usuario.camion?['placa'] ?? 'No especificada'),
                _buildInfoRow('Marca', usuario.camion?['marca'] ?? 'No especificada'),
                _buildInfoRow('Modelo', usuario.camion?['modelo'] ?? 'No especificado'),
                _buildInfoRow('Capacidad', '${usuario.camion?['capacidadCarga'] ?? 'No especificada'} kg'),
              ]),
              
              _buildInfoSection('Método de Pago', [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Wrap(
                        spacing: 8,
                        children: _metodosPago.map((metodoPago) {
                          final isSelected = _selectedMetodoPago == metodoPago;
                          return ChoiceChip(
                            label: Text(metodoPago),
                            selected: isSelected,
                            selectedColor: Theme.of(context).primaryColor.withAlpha(51), // 0.2 * 255 = 51
                            onSelected: (_) => _actualizarMetodoPago(metodoPago),
                          );
                        }).toList(),
                      ),
                ),
              ]),
              
              const SizedBox(height: 32),
              
              // Botón para cerrar sesión
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton.icon(
                  onPressed: _cerrarSesion,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.red.withAlpha(26), // 0.1 * 255 = 25.5 ≈ 26
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: _registrarVehiculo,
          ),
        ],
      ),
      body: body,
    );
  }
  
  Widget _buildRatingSummary() {
    final rating = _estadisticas['calificacionPromedio'] as double?;

    if (rating == null) {
      return const Text(
        'Sin calificación disponible',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(5, (index) {
          return Icon(
            index < rating.floor()
                ? Icons.star
                : index < rating
                    ? Icons.star_half
                    : Icons.star_border,
            color: Colors.amber,
            size: 24,
          );
        }),
        const SizedBox(width: 8),
        Text(
          '$rating',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Viajes', 
          _estadisticas['viajesCompletados']?.toString() ?? 'No disponible',
          Icons.directions_car,
          Colors.blue
        ),
        _buildStatCard(
          'Kilómetros', 
          _estadisticas['kilometrosRecorridos']?.toString() ?? 'No disponible',
          Icons.route,
          Colors.green
        ),
        _buildStatCard(
          'Ingresos (mes)', 
          _estadisticas['ingresosMes'] != null
              ? '\$${(_estadisticas['ingresosMes'] / 1000).round()}K'
              : 'No disponible',
          Icons.attach_money,
          Colors.amber
        ),
        _buildStatCard(
          'Disponibilidad', 
          _isDisponible ? 'Activa' : 'Inactiva',
          Icons.access_time_filled,
          _isDisponible ? Colors.green : Colors.red
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26), // 0.1 * 255 = 25.5 ≈ 26
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
} 
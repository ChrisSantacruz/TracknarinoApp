import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/narino_municipalities.dart';
import '../../services/ors_service.dart';
import '../../services/oportunidad_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/premium_operational_widgets.dart';

class CrearOportunidadScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onPublished;

  const CrearOportunidadScreen({
    super.key,
    this.embedded = false,
    this.onPublished,
  });

  @override
  State<CrearOportunidadScreen> createState() => _CrearOportunidadScreenState();
}

class _CrearOportunidadScreenState extends State<CrearOportunidadScreen> {
  static const LatLng _defaultMapCenter = LatLng(1.2136, -77.2811);
  static const Map<String, String> _vehicleLabels = {
    'camion_liviano_npr_nqr': 'Camión carga pequeño (NPR, NQR)',
    'camion_mediano_frr': 'Camión carga mediano (FRR)',
    'camion_grande_ftr_fvr_gh': 'Camión carga grande (FTR, FVR, GH)',
    'tractocamion': 'Tractocamión / mula',
    'camion_refrigerado': 'Camión refrigerado',
    'camion_plataforma': 'Camión plataforma',
    'volqueta': 'Volqueta',
    'camioneta_carga': 'Camioneta de carga',
    'otro': 'Otro',
  };
  static const Map<String, String> _capacityUnitLabels = {
    'toneladas': 'Toneladas',
    'kg': 'Kilogramos',
  };
  static const Map<String, String> _paymentLabels = {
    'transferencia': 'Transferencia',
    'efectivo': 'Efectivo',
    'nequi': 'Nequi',
    'daviplata': 'Daviplata',
    'mixto': 'Mixto',
  };
  static const Map<String, String> _priorityLabels = {
    'baja': 'Baja',
    'media': 'Media',
    'alta': 'Alta',
  };

  final _formKey = GlobalKey<FormState>();
  final _routeMapController = MapController();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _origenController = TextEditingController();
  final _destinoController = TextEditingController();
  final _precioController = TextEditingController();
  final _pesoCargaController = TextEditingController();
  final _tipoCargaController = TextEditingController();
  final _incentivoPrioridadController = TextEditingController();
  final _direccionCargueController = TextEditingController();
  final _direccionDescargueController = TextEditingController();
  final _requisitosController = TextEditingController();
  final _origenLatController = TextEditingController();
  final _origenLngController = TextEditingController();
  final _destinoLatController = TextEditingController();
  final _destinoLngController = TextEditingController();

  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
  String _vehiculoPreferido = 'camion_liviano_npr_nqr';
  String _unidadCapacidad = 'toneladas';
  String _metodoPagoCarga = 'transferencia';
  String _prioridadCarga = 'baja';
  bool _isLoading = false;
  bool _routeLoading = false;
  bool _pickingOrigin = true;
  String _errorMessage = '';
  String _routeMessage =
      'Toca el mapa para marcar origen y destino. La ruta se calcula antes de publicar.';
  LatLng? _originPoint;
  LatLng? _destinationPoint;
  List<LatLng> _routePreview = [];

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _origenController.dispose();
    _destinoController.dispose();
    _precioController.dispose();
    _pesoCargaController.dispose();
    _tipoCargaController.dispose();
    _incentivoPrioridadController.dispose();
    _direccionCargueController.dispose();
    _direccionDescargueController.dispose();
    _requisitosController.dispose();
    _origenLatController.dispose();
    _origenLngController.dispose();
    _destinoLatController.dispose();
    _destinoLngController.dispose();
    super.dispose();
  }

  double _parseCoordinate(String value, String label, double min, double max) {
    final coordinate = double.tryParse(value.trim().replaceAll(',', '.'));
    if (coordinate == null || coordinate < min || coordinate > max) {
      throw Exception('$label debe estar entre $min y $max');
    }
    return coordinate;
  }

  void _setRoutePoint(LatLng point) {
    final nearestMunicipality = _nearestMunicipality(point);
    setState(() {
      if (_pickingOrigin) {
        _originPoint = point;
        _origenController.text = nearestMunicipality.name;
        _origenLatController.text = point.latitude.toStringAsFixed(6);
        _origenLngController.text = point.longitude.toStringAsFixed(6);
        _pickingOrigin = false;
      } else {
        _destinationPoint = point;
        _destinoController.text = nearestMunicipality.name;
        _destinoLatController.text = point.latitude.toStringAsFixed(6);
        _destinoLngController.text = point.longitude.toStringAsFixed(6);
      }
      _routeMessage =
          _originPoint == null || _destinationPoint == null
              ? 'Marca el punto ${_pickingOrigin ? 'de origen' : 'de destino'} para completar la ruta.'
              : 'Calculando ruta rápida con el proveedor operativo...';
    });

    if (_originPoint != null && _destinationPoint != null) {
      _calculateRoutePreview();
    }
  }

  NarinoMunicipality _nearestMunicipality(LatLng point) {
    final distance = const Distance();
    return narinoMunicipalities.reduce((best, candidate) {
      final bestDistance = distance(point, best.center);
      final candidateDistance = distance(point, candidate.center);
      return candidateDistance < bestDistance ? candidate : best;
    });
  }

  void _selectMunicipality({
    required NarinoMunicipality municipality,
    required bool origin,
  }) {
    setState(() {
      if (origin) {
        _origenController.text = municipality.name;
        if (_direccionCargueController.text.trim().isEmpty) {
          _direccionCargueController.text = 'Centro de ${municipality.name}';
        }
        _originPoint = municipality.center;
        _origenLatController.text = municipality.center.latitude
            .toStringAsFixed(6);
        _origenLngController.text = municipality.center.longitude
            .toStringAsFixed(6);
        _pickingOrigin = false;
      } else {
        _destinoController.text = municipality.name;
        if (_direccionDescargueController.text.trim().isEmpty) {
          _direccionDescargueController.text = 'Centro de ${municipality.name}';
        }
        _destinationPoint = municipality.center;
        _destinoLatController.text = municipality.center.latitude
            .toStringAsFixed(6);
        _destinoLngController.text = municipality.center.longitude
            .toStringAsFixed(6);
      }
      _routeMessage =
          _originPoint == null || _destinationPoint == null
              ? 'Municipio seleccionado. Puedes ajustar el punto tocando el mapa.'
              : 'Calculando ruta rápida con el proveedor operativo...';
    });

    _routeMapController.move(municipality.center, 11.5);
    if (_originPoint != null && _destinationPoint != null) {
      _calculateRoutePreview();
    }
  }

  Future<void> _calculateRoutePreview() async {
    final origin = _originPoint;
    final destination = _destinationPoint;
    if (origin == null || destination == null) return;

    setState(() {
      _routeLoading = true;
      _routeMessage = 'Calculando ruta más rápida disponible...';
    });

    try {
      final routeData = await ORSService.obtenerRuta(origin, destination);
      if (!mounted) return;
      final points = List<LatLng>.from(routeData['coordinates'] as List);
      final distance = routeData['distance'] as double?;
      final duration = routeData['duration'] as int?;
      setState(() {
        _routePreview = points;
        _routeMessage =
            'Ruta validada${distance == null ? '' : ' · ${distance.toStringAsFixed(1)} km'}${duration == null ? '' : ' · ${_formattedDurationText(duration)}'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routePreview = [origin, destination];
        _routeMessage =
            'No se pudo validar la ruta ahora. Se guardarán los puntos para que el sistema recalcule y busque alternativa al iniciar el viaje.';
      });
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  String _formattedDurationText(int minutes) {
    if (minutes <= 0) return 'tiempo no disponible';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours h' : '$hours h $remaining min';
  }

  Future<void> _mostrarSelectorFecha() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (fechaSeleccionada == null || !mounted) return;

    final horaSeleccionada = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaSeleccionada),
    );

    if (horaSeleccionada == null) return;

    setState(() {
      _fechaSeleccionada = DateTime(
        fechaSeleccionada.year,
        fechaSeleccionada.month,
        fechaSeleccionada.day,
        horaSeleccionada.hour,
        horaSeleccionada.minute,
      );
    });
  }

  Future<void> _crearOportunidad() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage =
            'Completa los campos obligatorios marcados antes de publicar.';
      });
      return;
    }
    if (_originPoint == null || _destinationPoint == null) {
      setState(() {
        _errorMessage =
            'Selecciona municipio de origen y destino, o marca ambos puntos en el mapa.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final precioParsed = double.tryParse(
        _precioController.text.replaceAll(',', ''),
      );
      final capacidadParsed = double.tryParse(
        _pesoCargaController.text.trim().replaceAll(',', '.'),
      );
      final incentivoParsed =
          double.tryParse(
            _incentivoPrioridadController.text.trim().replaceAll(',', ''),
          ) ??
          0;

      if (precioParsed == null || capacidadParsed == null) {
        throw Exception('Precio o capacidad inválidos');
      }
      if (incentivoParsed < 0) {
        throw Exception('El incentivo no puede ser negativo');
      }
      final prioridadFinal =
          incentivoParsed <= 0
              ? 'baja'
              : _prioridadCarga == 'baja'
              ? 'media'
              : _prioridadCarga;

      final origenLat = _parseCoordinate(
        _origenLatController.text,
        'Latitud de origen',
        -90,
        90,
      );
      final origenLng = _parseCoordinate(
        _origenLngController.text,
        'Longitud de origen',
        -180,
        180,
      );
      final destinoLat = _parseCoordinate(
        _destinoLatController.text,
        'Latitud de destino',
        -90,
        90,
      );
      final destinoLng = _parseCoordinate(
        _destinoLngController.text,
        'Longitud de destino',
        -180,
        180,
      );

      final data = {
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'origen': _origenController.text.trim(),
        'destino': _destinoController.text.trim(),
        'origin': {
          'name': _origenController.text.trim(),
          'address': _direccionCargueController.text.trim(),
          'coordinates': [origenLng, origenLat],
        },
        'destination': {
          'name': _destinoController.text.trim(),
          'address': _direccionDescargueController.text.trim(),
          'coordinates': [destinoLng, destinoLat],
        },
        'direccionCargue': _direccionCargueController.text.trim(),
        'direccionDescargue': _direccionDescargueController.text.trim(),
        'fecha': _fechaSeleccionada.toIso8601String(),
        'precio': precioParsed,
        'pesoCarga':
            _unidadCapacidad == 'toneladas' ? capacidadParsed.round() : null,
        'capacidadRequerida': capacidadParsed,
        'unidadCapacidad': _unidadCapacidad,
        'tipoCarga': _tipoCargaController.text.trim(),
        'vehiculoPreferido': _vehiculoPreferido,
        'metodoPagoCarga': _metodoPagoCarga,
        'prioridad': prioridadFinal,
        'incentivoPrioridad': incentivoParsed,
        'requisitosEspeciales':
            _requisitosController.text.isEmpty
                ? null
                : _requisitosController.text.trim(),
        'estado': 'disponible',
        'finalizada': false,
      };

      final oportunidad = await OportunidadService.crearOportunidadCompleta(
        data,
      );

      if (!mounted) return;
      if (oportunidad == null) {
        setState(() => _errorMessage = 'No se pudo crear la carga.');
        return;
      }

      if (widget.embedded) {
        widget.onPublished?.call();
      } else {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carga publicada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = PremiumGradientScaffold(
      safeArea: !widget.embedded,
      child: CustomScrollView(
        slivers: [
          if (!widget.embedded)
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: const Text('Nueva carga'),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumScreenHeader(
                      eyebrow: 'Contratista',
                      title: 'Publicar carga real',
                      subtitle:
                          'Completa origen, destino y coordenadas para que el conductor pueda calcular ruta sin estados rotos.',
                      trailing: IconButton.filledTonal(
                        onPressed: _isLoading ? null : _mostrarSelectorFecha,
                        icon: const Icon(Icons.event_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_errorMessage.isNotEmpty) ...[
                      _ErrorBanner(message: _errorMessage),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _ShipmentSummaryCard(
                      title:
                          _tituloController.text.trim().isEmpty
                              ? 'Carga sin título'
                              : _tituloController.text.trim(),
                      route:
                          '${_origenController.text.trim().isEmpty ? 'Origen' : _origenController.text.trim()} → ${_destinoController.text.trim().isEmpty ? 'Destino' : _destinoController.text.trim()}',
                      date: DateFormat(
                        'dd MMM yyyy, HH:mm',
                      ).format(_fechaSeleccionada),
                      price:
                          _precioController.text.trim().isEmpty
                              ? 'Valor pendiente'
                              : '\$${_precioController.text.trim()}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PremiumGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionTitle(
                            title: 'Carga',
                            subtitle: 'Información visible para camioneros.',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PremiumTextField(
                            controller: _tituloController,
                            label: 'Título',
                            hint: 'Ej: Lácteos hacia Pasto',
                            icon: Icons.inventory_2_outlined,
                            validator: _required('Ingresa un título'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PremiumTextField(
                            controller: _tipoCargaController,
                            label: 'Tipo de carga',
                            hint: 'Alimentos, materiales, muebles',
                            icon: Icons.category_outlined,
                            validator: _required('Ingresa el tipo de carga'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _ChoiceGroup(
                            title: 'Vehículo preferido',
                            values: _vehicleLabels,
                            selected: _vehiculoPreferido,
                            onSelected:
                                (value) => setState(() {
                                  _vehiculoPreferido = value;
                                }),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: PremiumTextField(
                                  controller: _pesoCargaController,
                                  label:
                                      _unidadCapacidad == 'kg'
                                          ? 'Peso en kilogramos'
                                          : 'Peso en toneladas',
                                  icon: Icons.scale_outlined,
                                  keyboardType: TextInputType.number,
                                  validator: _positiveNumber(
                                    'Ingresa un peso válido',
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: PremiumTextField(
                                  controller: _precioController,
                                  label: 'Precio COP',
                                  icon: Icons.payments_outlined,
                                  keyboardType: TextInputType.number,
                                  validator: _moneyValidator,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _ChoiceGroup(
                            title: 'Unidad de peso',
                            values: _capacityUnitLabels,
                            selected: _unidadCapacidad,
                            onSelected:
                                (value) =>
                                    setState(() => _unidadCapacidad = value),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _ChoiceGroup(
                            title: 'Método de pago de la carga',
                            values: _paymentLabels,
                            selected: _metodoPagoCarga,
                            onSelected:
                                (value) =>
                                    setState(() => _metodoPagoCarga = value),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _ChoiceGroup(
                            title: 'Prioridad',
                            values: _priorityLabels,
                            selected: _prioridadCarga,
                            onSelected:
                                (value) =>
                                    setState(() => _prioridadCarga = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Para prioridad media o alta es recomendable ofrecer un bono. Si el bono es 0, la carga queda en prioridad baja.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.graphite300),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PremiumTextField(
                            controller: _incentivoPrioridadController,
                            label: 'Bono por prioridad COP',
                            hint: '0, 15000, 20000...',
                            icon: Icons.trending_up_rounded,
                            keyboardType: TextInputType.number,
                            validator: _optionalNonNegativeMoney,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PremiumTextField(
                            controller: _descripcionController,
                            label: 'Descripción',
                            icon: Icons.notes_outlined,
                            maxLines: 3,
                            validator: _required('Ingresa una descripción'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PremiumTextField(
                            controller: _requisitosController,
                            label: 'Requisitos especiales',
                            hint: 'Opcional',
                            icon: Icons.rule_folder_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PremiumGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionTitle(
                            title: 'Ruta operativa',
                            subtitle:
                                'Elige municipios de Nariño para marcarlos automáticamente o ajusta los puntos tocando el mapa.',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _RouteMapPicker(
                            origin: _originPoint,
                            destination: _destinationPoint,
                            routePreview: _routePreview,
                            pickingOrigin: _pickingOrigin,
                            loading: _routeLoading,
                            message: _routeMessage,
                            mapController: _routeMapController,
                            onPickModeChanged:
                                (value) =>
                                    setState(() => _pickingOrigin = value),
                            onTap: _setRoutePoint,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _LocationBlock(
                            title: 'Origen',
                            cityController: _origenController,
                            addressController: _direccionCargueController,
                            latController: _origenLatController,
                            lngController: _origenLngController,
                            color: AppColors.emerald400,
                            onMunicipalitySelected:
                                (municipality) => _selectMunicipality(
                                  municipality: municipality,
                                  origin: true,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _LocationBlock(
                            title: 'Destino',
                            cityController: _destinoController,
                            addressController: _direccionDescargueController,
                            latController: _destinoLatController,
                            lngController: _destinoLngController,
                            color: AppColors.alertCritical,
                            onMunicipalitySelected:
                                (municipality) => _selectMunicipality(
                                  municipality: municipality,
                                  origin: false,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          InkWell(
                            onTap: _mostrarSelectorFecha,
                            borderRadius: BorderRadius.circular(18),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha de entrega',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                                suffixIcon: Icon(Icons.expand_more_rounded),
                              ),
                              child: Text(
                                DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(_fechaSeleccionada),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PremiumPrimaryButton(
                      label: 'Publicar carga',
                      icon: Icons.cloud_upload_outlined,
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _crearOportunidad,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;
    return content;
  }

  String? Function(String?) _required(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  String? Function(String?) _positiveNumber(String message) {
    return (value) {
      final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
      if (parsed == null || parsed <= 0) return message;
      return null;
    };
  }

  String? _moneyValidator(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', ''));
    if (parsed == null || parsed <= 0) return 'Ingresa un precio válido';
    return null;
  }

  String? _optionalNonNegativeMoney(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final parsed = double.tryParse(raw.replaceAll(',', ''));
    if (parsed == null || parsed < 0) return 'Ingresa un bono válido';
    return null;
  }
}

class _ChoiceGroup extends StatelessWidget {
  final String title;
  final Map<String, String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ChoiceGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.graphite200,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children:
              values.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected == entry.key,
                  onSelected: (_) => onSelected(entry.key),
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _RouteMapPicker extends StatelessWidget {
  final LatLng? origin;
  final LatLng? destination;
  final List<LatLng> routePreview;
  final bool pickingOrigin;
  final bool loading;
  final String message;
  final MapController mapController;
  final ValueChanged<bool> onPickModeChanged;
  final ValueChanged<LatLng> onTap;

  const _RouteMapPicker({
    required this.origin,
    required this.destination,
    required this.routePreview,
    required this.pickingOrigin,
    required this.loading,
    required this.message,
    required this.mapController,
    required this.onPickModeChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (origin != null)
        Marker(
          point: origin!,
          width: 42,
          height: 42,
          builder:
              (_) =>
                  _MapPin(color: AppColors.emerald400, icon: Icons.trip_origin),
        ),
      if (destination != null)
        Marker(
          point: destination!,
          width: 42,
          height: 42,
          builder:
              (_) => _MapPin(color: AppColors.alertCritical, icon: Icons.flag),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 260,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  center:
                      origin ??
                      destination ??
                      _CrearOportunidadScreenState._defaultMapCenter,
                  zoom: 11.5,
                  onTap: (_, point) => onTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  if (routePreview.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePreview,
                          strokeWidth: 5,
                          color: AppColors.emerald400.withValues(alpha: 0.82),
                        ),
                      ],
                    ),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: _MapPickerToolbar(
                  pickingOrigin: pickingOrigin,
                  onPickModeChanged: onPickModeChanged,
                ),
              ),
              if (loading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.inkBlack.withValues(alpha: 0.28),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumInfoRow(
          icon: Icons.route_outlined,
          label: 'Ruta asistida',
          value: message,
          color: AppColors.emerald400,
        ),
      ],
    );
  }
}

class _MapPickerToolbar extends StatelessWidget {
  final bool pickingOrigin;
  final ValueChanged<bool> onPickModeChanged;

  const _MapPickerToolbar({
    required this.pickingOrigin,
    required this.onPickModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.graphite950.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: _PickerModeButton(
                label: 'Marcar origen',
                selected: pickingOrigin,
                color: AppColors.emerald400,
                onTap: () => onPickModeChanged(true),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PickerModeButton(
                label: 'Marcar destino',
                selected: !pickingOrigin,
                color: AppColors.alertCritical,
                onTap: () => onPickModeChanged(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PickerModeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:
              selected
                  ? color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected
                    ? color.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? color : AppColors.graphite300,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.graphite950,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _LocationBlock extends StatelessWidget {
  final String title;
  final TextEditingController cityController;
  final TextEditingController addressController;
  final TextEditingController latController;
  final TextEditingController lngController;
  final Color color;
  final ValueChanged<NarinoMunicipality> onMunicipalitySelected;

  const _LocationBlock({
    required this.title,
    required this.cityController,
    required this.addressController,
    required this.latController,
    required this.lngController,
    required this.color,
    required this.onMunicipalitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumStatusPill(label: title, color: color),
        const SizedBox(height: AppSpacing.md),
        _MunicipalitySelector(
          selectedName: cityController.text,
          label: 'Municipio de Nariño',
          onSelected: onMunicipalitySelected,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          controller: addressController,
          label: 'Dirección / punto de referencia',
          hint: 'Opcional si usas el centro del municipio',
          icon: Icons.pin_drop_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumInfoRow(
          icon: Icons.gps_fixed_rounded,
          label: 'Coordenada seleccionada',
          value:
              latController.text.trim().isEmpty ||
                      lngController.text.trim().isEmpty
                  ? 'Pendiente: marca el punto en el mapa'
                  : '${latController.text}, ${lngController.text}',
          color: color,
        ),
      ],
    );
  }
}

class _MunicipalitySelector extends StatelessWidget {
  final String selectedName;
  final String label;
  final ValueChanged<NarinoMunicipality> onSelected;

  const _MunicipalitySelector({
    required this.selectedName,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected =
        narinoMunicipalities
            .where((municipality) => municipality.name == selectedName)
            .firstOrNull;

    return DropdownButtonFormField<NarinoMunicipality>(
      initialValue: selected,
      isExpanded: true,
      dropdownColor: Colors.white,
      menuMaxHeight: 320,
      style: const TextStyle(
        color: AppColors.graphite900,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.94),
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.graphite800,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: const Icon(
          Icons.location_city_outlined,
          color: AppColors.graphite700,
        ),
      ),
      items:
          narinoMunicipalities
              .map(
                (municipality) => DropdownMenuItem(
                  value: municipality,
                  child: Text(
                    municipality.name,
                    style: const TextStyle(
                      color: AppColors.graphite900,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
      validator:
          (value) => value == null ? 'Selecciona un municipio de Nariño' : null,
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }
}

class _ShipmentSummaryCard extends StatelessWidget {
  final String title;
  final String route;
  final String date;
  final String price;

  const _ShipmentSummaryCard({
    required this.title,
    required this.route,
    required this.date,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      borderColor: AppColors.emerald400.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumInfoRow(
            icon: Icons.route_outlined,
            label: 'Ruta',
            value: route,
            color: AppColors.emerald400,
          ),
          PremiumInfoRow(
            icon: Icons.schedule_outlined,
            label: 'Entrega',
            value: date,
            color: AppColors.statusSyncing,
          ),
          PremiumInfoRow(
            icon: Icons.payments_outlined,
            label: 'Pago',
            value: price,
            color: AppColors.statusActive,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

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

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      borderColor: AppColors.alertCritical.withValues(alpha: 0.35),
      child: PremiumInfoRow(
        icon: Icons.error_outline_rounded,
        label: 'No se pudo publicar',
        value: message,
        color: AppColors.alertCritical,
      ),
    );
  }
}

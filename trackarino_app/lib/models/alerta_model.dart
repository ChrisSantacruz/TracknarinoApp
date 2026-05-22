import '../utils/geo_utils.dart';

class AlertaSeguridad {
  final String? id;
  final String tipo;
  final String? descripcion;
  final String usuario;
  final Map<String, double> coords;
  final DateTime timestamp;
  final String? imagenUrl;

  AlertaSeguridad({
    this.id,
    required this.tipo,
    this.descripcion,
    required this.usuario,
    required this.coords,
    required this.timestamp,
    this.imagenUrl,
  });

  factory AlertaSeguridad.fromJson(Map<String, dynamic> json) {
    // Extraer usuario (puede ser String o Map)
    String usuarioId;
    if (json['usuario'] is String) {
      usuarioId = json['usuario'];
    } else if (json['usuario'] is Map) {
      usuarioId = json['usuario']['_id'] ?? json['usuario']['id'] ?? 'desconocido';
    } else {
      usuarioId = 'desconocido';
    }

    // Extraer timestamp (puede ser timestamp o createdAt)
    DateTime fechaCreacion;
    try {
      if (json.containsKey('timestamp') && json['timestamp'] != null) {
        fechaCreacion = DateTime.parse(json['timestamp']);
      } else if (json.containsKey('createdAt') && json['createdAt'] != null) {
        fechaCreacion = DateTime.parse(json['createdAt']);
      } else {
        fechaCreacion = DateTime.now();
      }
    } catch (e) {
      fechaCreacion = DateTime.now();
    }

    final coordResult = parseLocationPayload(json);
    if (!coordResult.isValid || coordResult.coordinate == null) {
      throw FormatException('Alerta sin coordenadas válidas');
    }

    return AlertaSeguridad(
      id: json['_id'] ?? json['id'],
      tipo: json['tipo'] ?? 'otro',
      descripcion: json['descripcion'],
      usuario: usuarioId,
      coords: coordResult.coordinate!.toCoordsMap(),
      timestamp: fechaCreacion,
      imagenUrl: json['imagenUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo,
      'descripcion': descripcion,
      'usuario': usuario,
      'coords': coords,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  // Lista de tipos de alerta válidos
  static List<String> get tiposAlerta => [
    'trancon', 'sospecha', 'intento_robo', 'robo', 'obstaculo'
  ];

  // Obtiene un ícono según el tipo de alerta
  String get iconoAlerta {
    switch (tipo) {
      case 'trancon': return 'assets/icons/trafico.svg';
      case 'sospecha': return 'assets/icons/sospecha.svg';
      case 'intento_robo': return 'assets/icons/robo.svg';
      case 'robo': return 'assets/icons/peligro.svg';
      case 'obstaculo': return 'assets/icons/obstaculo.svg';
      default: return 'assets/icons/alerta.svg';
    }
  }
} 
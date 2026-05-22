import '../utils/geo_utils.dart';

class Ubicacion {
  final String? id;
  final String camionero;
  final Map<String, double> coords;
  final DateTime timestamp;
  final double? velocidad;
  final double? precision;
  final double? rumbo;

  Ubicacion({
    this.id,
    required this.camionero,
    required this.coords,
    required this.timestamp,
    this.velocidad,
    this.precision,
    this.rumbo,
  });

  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    final parsed = parseLocationPayload(json);
    if (!parsed.isValid || parsed.coordinate == null) {
      throw FormatException(parsed.error ?? 'Ubicación sin coordenadas válidas');
    }

    final timestamp = parseServerDate(json['timestamp']);
    if (timestamp == null) {
      throw FormatException('timestamp inválido');
    }

    return Ubicacion(
      id: json['_id'],
      camionero: json['camionero'] is Map
          ? (json['camionero']['_id'] ?? json['camionero']['id']).toString()
          : json['camionero'].toString(),
      coords: parsed.coordinate!.toCoordsMap(),
      timestamp: timestamp,
      velocidad: (json['speed'] ?? json['velocidad'])?.toDouble(),
      precision: (json['accuracy'] ?? json['precision'])?.toDouble(),
      rumbo: (json['heading'] ?? json['rumbo'])?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'camionero': camionero,
      'coords': coords,
      'coordinates': [coords['lng'], coords['lat']],
      'timestamp': timestamp.toIso8601String(),
      if (velocidad != null) 'speed': velocidad,
      if (precision != null) 'accuracy': precision,
      if (rumbo != null) 'heading': rumbo,
    };
  }
} 
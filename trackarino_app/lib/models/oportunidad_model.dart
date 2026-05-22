import '../utils/geo_utils.dart';

class GeoPointData {
  final String name;
  final String address;
  final double lng;
  final double lat;

  GeoPointData({
    required this.name,
    required this.address,
    required this.lng,
    required this.lat,
  });

  factory GeoPointData.fromJson(Map<String, dynamic> json) {
    final parsed = parseCoordinatesFromDynamic(json['coordinates']);
    if (!parsed.isValid || parsed.coordinate == null) {
      throw FormatException(parsed.error ?? 'Coordenadas inválidas');
    }

    return GeoPointData(
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      lng: parsed.coordinate!.lng,
      lat: parsed.coordinate!.lat,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'coordinates': [lng, lat],
    };
  }
}

class Oportunidad {
  final String? id;
  final String titulo;
  final String? descripcion;
  final String origen;
  final String destino;
  final String? direccionCargue;
  final String? direccionDescargue;
  final DateTime fecha;
  final double precio;
  final String estado;
  final bool finalizada;
  final String contratista;
  final String? camioneroAsignado;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? pesoCarga; // Peso en toneladas
  final String? tipoCarga;
  final String? requisitosEspeciales;
  final int? distanciaKm;
  final int? duracionEstimadaHoras;
  final GeoPointData? origin;
  final GeoPointData? destination;

  Oportunidad({
    this.id,
    required this.titulo,
    this.descripcion,
    required this.origen,
    required this.destino,
    this.direccionCargue,
    this.direccionDescargue,
    required this.fecha,
    required this.precio,
    required this.estado,
    required this.finalizada,
    required this.contratista,
    this.camioneroAsignado,
    this.createdAt,
    this.updatedAt,
    this.pesoCarga,
    this.tipoCarga,
    this.requisitosEspeciales,
    this.distanciaKm,
    this.duracionEstimadaHoras,
    this.origin,
    this.destination,
  });

  factory Oportunidad.fromJson(Map<String, dynamic> json) {
    // Extraer contratista (puede ser String o Map)
    String contratistaId;
    if (json['contratista'] is String) {
      contratistaId = json['contratista'];
    } else if (json['contratista'] is Map) {
      contratistaId = json['contratista']['_id'] ?? json['contratista']['id'] ?? 'desconocido';
    } else {
      contratistaId = 'desconocido';
    }

    // Extraer camioneroAsignado (puede ser String, Map o null)
    String? camioneroId;
    if (json['camioneroAsignado'] == null) {
      camioneroId = null;
    } else if (json['camioneroAsignado'] is String) {
      camioneroId = json['camioneroAsignado'];
    } else if (json['camioneroAsignado'] is Map) {
      camioneroId = json['camioneroAsignado']['_id'] ?? json['camioneroAsignado']['id'];
    }

    GeoPointData? parseGeoPoint(dynamic value) {
      if (value is Map<String, dynamic>) {
        try {
          return GeoPointData.fromJson(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final origin = parseGeoPoint(json['origin']);
    final destination = parseGeoPoint(json['destination']);

    return Oportunidad(
      id: json['_id'],
      titulo: json['titulo'] ?? 'Oportunidad sin título',
      descripcion: json['descripcion'],
      origen: origin?.name ?? json['origen'] ?? 'Origen sin nombre',
      destino: destination?.name ?? json['destino'] ?? 'Destino sin nombre',
      direccionCargue: origin?.address ?? json['direccionCargue'],
      direccionDescargue: destination?.address ?? json['direccionDescargue'],
      fecha: DateTime.parse(json['fecha']),
      precio: (json['precio'] as num).toDouble(),
      estado: json['estado'] == 'finalizada' ? 'entregada' : (json['estado'] ?? 'disponible'),
      finalizada: (json['finalizada'] as bool?) ?? (json['estado'] == 'entregada'),
      contratista: contratistaId,
      camioneroAsignado: camioneroId,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      pesoCarga: json['pesoCarga'],
      tipoCarga: json['tipoCarga'],
      requisitosEspeciales: json['requisitosEspeciales'],
      distanciaKm: json['distanciaKm'],
      duracionEstimadaHoras: json['duracionEstimadaHoras'],
      origin: origin,
      destination: destination,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'origen': origen,
      'destino': destino,
      if (origin != null) 'origin': origin!.toJson(),
      if (destination != null) 'destination': destination!.toJson(),
      'direccionCargue': direccionCargue,
      'direccionDescargue': direccionDescargue,
      'fecha': fecha.toIso8601String(),
      'precio': precio,
      'estado': estado,
      'finalizada': finalizada,
      'contratista': contratista,
      'camioneroAsignado': camioneroAsignado,
      if (pesoCarga != null) 'pesoCarga': pesoCarga,
      if (tipoCarga != null) 'tipoCarga': tipoCarga,
      if (requisitosEspeciales != null) 'requisitosEspeciales': requisitosEspeciales,
      if (distanciaKm != null) 'distanciaKm': distanciaKm,
      if (duracionEstimadaHoras != null) 'duracionEstimadaHoras': duracionEstimadaHoras,
    };
  }
} 
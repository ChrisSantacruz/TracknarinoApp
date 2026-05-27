import '../utils/geo_utils.dart';

class FleetTrackingItem {
  final String camioneroId;
  final String nombre;
  final String telefono;
  final String placaVehiculo;
  final GeoCoordinate? ubicacion;
  final String trackingStatus;
  final DateTime? lastSeenAt;
  final DateTime? serverReceivedAt;
  final int? ageMs;
  final bool isStale;
  final bool isOffline;
  final bool coordinatesValid;
  final bool hasLocation;
  final String origenViaje;
  final String destinoViaje;
  final String carga;
  final double heading;
  final bool hasActiveTrip;
  final GeoCoordinate? originPoint;
  final GeoCoordinate? destinationPoint;

  FleetTrackingItem({
    required this.camioneroId,
    required this.nombre,
    required this.telefono,
    required this.placaVehiculo,
    required this.ubicacion,
    required this.trackingStatus,
    required this.lastSeenAt,
    required this.serverReceivedAt,
    required this.ageMs,
    required this.isStale,
    required this.isOffline,
    required this.coordinatesValid,
    required this.hasLocation,
    required this.origenViaje,
    required this.destinoViaje,
    required this.carga,
    required this.heading,
    required this.hasActiveTrip,
    required this.originPoint,
    required this.destinationPoint,
  });

  factory FleetTrackingItem.fromJson(Map<String, dynamic> json) {
    final camionero = json['camionero'];
    final camioneroMap =
        camionero is Map<String, dynamic> ? camionero : <String, dynamic>{};
    final camioneroId =
        (camioneroMap['id'] ?? camioneroMap['_id'] ?? '').toString();

    final latestLocation = json['latestLocation'];
    final locationMap =
        latestLocation is Map<String, dynamic> ? latestLocation : null;
    final coordResult = parseLocationPayload(locationMap);

    final activeTrip = json['activeTrip'];
    final tripMap = activeTrip is Map<String, dynamic> ? activeTrip : null;

    String tripField(String geoKey, String legacyKey) {
      if (tripMap == null) return 'Sin viaje activo';
      final geo = tripMap[geoKey];
      if (geo is Map && geo['name'] != null) return geo['name'].toString();
      return (tripMap[legacyKey] ?? 'Sin viaje activo').toString();
    }

    final camion = camioneroMap['camion'];
    final placa =
        camion is Map
            ? (camion['placa'] ?? 'No registrada').toString()
            : 'No registrada';
    final originPoint =
        tripMap == null
            ? null
            : parseCoordinatesFromDynamic(
              (tripMap['origin'] as Map?)?['coordinates'],
            ).coordinate;
    final destinationPoint =
        tripMap == null
            ? null
            : parseCoordinatesFromDynamic(
              (tripMap['destination'] as Map?)?['coordinates'],
            ).coordinate;

    return FleetTrackingItem(
      camioneroId: camioneroId,
      nombre: (camioneroMap['nombre'] ?? 'Camionero sin nombre').toString(),
      telefono: (camioneroMap['telefono'] ?? 'No registrado').toString(),
      placaVehiculo: placa,
      ubicacion: coordResult.coordinate,
      trackingStatus: (json['trackingStatus'] ?? 'no_location').toString(),
      lastSeenAt: parseServerDate(
        json['lastSeenAt'] ?? json['lastUpdateAt'] ?? locationMap?['timestamp'],
      ),
      serverReceivedAt: parseServerDate(
        json['serverReceivedAt'] ?? locationMap?['serverReceivedAt'],
      ),
      ageMs: (json['ageMs'] as num?)?.toInt(),
      isStale: json['isStale'] == true,
      isOffline: json['isOffline'] == true,
      coordinatesValid: json['coordinatesValid'] == true,
      hasLocation: json['hasLocation'] == true || coordResult.isValid,
      origenViaje: tripField('origin', 'origen'),
      destinoViaje: tripField('destination', 'destino'),
      carga:
          tripMap != null
              ? (tripMap['tipoCarga'] ?? 'Carga sin clasificar').toString()
              : 'Sin carga activa',
      heading:
          ((locationMap?['heading'] ?? locationMap?['rumbo'] ?? 0) as num)
              .toDouble(),
      hasActiveTrip: tripMap != null,
      originPoint: originPoint,
      destinationPoint: destinationPoint,
    );
  }
}

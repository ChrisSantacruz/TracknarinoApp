class GeoCoordinate {
  final double lat;
  final double lng;

  const GeoCoordinate({required this.lat, required this.lng});

  Map<String, double> toCoordsMap() => {'lat': lat, 'lng': lng};

  List<double> toLngLatList() => [lng, lat];
}

class GeoCoordinateParseResult {
  final GeoCoordinate? coordinate;
  final String? error;

  const GeoCoordinateParseResult({this.coordinate, this.error});

  bool get isValid => coordinate != null;
}

GeoCoordinateParseResult parseCoordinatesFromDynamic(dynamic value) {
  if (value is Map) {
    final lat = _toDouble(value['lat']);
    final lng = _toDouble(value['lng']);
    if (lat != null && lng != null && _isValidRange(lat, lng)) {
      return GeoCoordinateParseResult(coordinate: GeoCoordinate(lat: lat, lng: lng));
    }
  }

  if (value is List && value.length >= 2) {
    final lng = _toDouble(value[0]);
    final lat = _toDouble(value[1]);
    if (lat != null && lng != null && _isValidRange(lat, lng)) {
      return GeoCoordinateParseResult(coordinate: GeoCoordinate(lat: lat, lng: lng));
    }
  }

  return const GeoCoordinateParseResult(error: 'Coordenadas inválidas');
}

GeoCoordinateParseResult parseLocationPayload(Map<String, dynamic>? json) {
  if (json == null) {
    return const GeoCoordinateParseResult(error: 'Payload vacío');
  }

  final fromCoords = parseCoordinatesFromDynamic(json['coords']);
  if (fromCoords.isValid) return fromCoords;

  return parseCoordinatesFromDynamic(json['coordinates']);
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim().replaceAll(',', '.'));
  return null;
}

bool _isValidRange(double lat, double lng) {
  return lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0 && lng == 0);
}

DateTime? parseServerDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

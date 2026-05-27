import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/trucker_place.dart';

class NarinoTruckerPlacesService {
  static final Uri _overpassUrl = Uri.parse(
    'https://overpass-api.de/api/interpreter',
  );

  static const double _south = 0.45;
  static const double _north = 2.75;
  static const double _west = -79.05;
  static const double _east = -76.55;

  static Future<List<TruckerPlace>> fetchPlaces({
    required Set<TruckerPlaceCategory> categories,
  }) async {
    if (categories.isEmpty) return [];

    final query = _buildQuery(categories);
    final response = await http
        .post(_overpassUrl, body: {'data': query})
        .timeout(const Duration(seconds: 14));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Overpass respondió ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = (body['elements'] as List<dynamic>? ?? const []);
    final places = <TruckerPlace>[];
    final seen = <String>{};

    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;
      final place = _parseElement(raw);
      if (place == null || !_isInsideNarinoBounds(place.position)) continue;
      if (seen.add(place.id)) places.add(place);
    }

    places.sort((a, b) => a.name.compareTo(b.name));
    return places.take(120).toList();
  }

  static String _buildQuery(Set<TruckerPlaceCategory> categories) {
    final blocks = <String>[];
    for (final category in categories) {
      blocks.addAll(_selectorsFor(category));
    }

    return '''
[out:json][timeout:14];
area["boundary"="administrative"]["admin_level"="4"]["name"="Nariño"]->.narino;
(
${blocks.map((selector) => '  $selector(area.narino);').join('\n')}
);
out center tags 120;
''';
  }

  static List<String> _selectorsFor(TruckerPlaceCategory category) {
    switch (category) {
      case TruckerPlaceCategory.fuel:
        return ['node["amenity"="fuel"]', 'way["amenity"="fuel"]'];
      case TruckerPlaceCategory.tire:
        return [
          'node["shop"="tyres"]',
          'way["shop"="tyres"]',
          'node["service"="tyres"]',
          'way["service"="tyres"]',
        ];
      case TruckerPlaceCategory.mechanic:
        return [
          'node["shop"="car_repair"]',
          'way["shop"="car_repair"]',
          'node["amenity"="vehicle_inspection"]',
          'way["amenity"="vehicle_inspection"]',
        ];
      case TruckerPlaceCategory.parking:
        return ['node["amenity"="parking"]', 'way["amenity"="parking"]'];
      case TruckerPlaceCategory.food:
        return [
          'node["amenity"="restaurant"]',
          'way["amenity"="restaurant"]',
          'node["amenity"="fast_food"]',
          'way["amenity"="fast_food"]',
        ];
      case TruckerPlaceCategory.emergency:
        return [
          'node["amenity"="hospital"]',
          'way["amenity"="hospital"]',
          'node["amenity"="police"]',
          'way["amenity"="police"]',
        ];
    }
  }

  static TruckerPlace? _parseElement(Map<String, dynamic> raw) {
    final tags = Map<String, dynamic>.from(raw['tags'] as Map? ?? const {});
    final lat = (raw['lat'] ?? (raw['center'] as Map?)?['lat']) as num?;
    final lon = (raw['lon'] ?? (raw['center'] as Map?)?['lon']) as num?;
    if (lat == null || lon == null) return null;

    final category = _categoryFromTags(tags);
    if (category == null) return null;

    final id = '${raw['type']}_${raw['id']}_${category.name}';
    final fallbackName = '${category.label} en ruta';
    final name = (tags['name'] as String?)?.trim();
    final address = _composeAddress(tags);

    return TruckerPlace(
      id: id,
      name: name == null || name.isEmpty ? fallbackName : name,
      category: category,
      position: LatLng(lat.toDouble(), lon.toDouble()),
      address: address,
      phone: (tags['phone'] ?? tags['contact:phone']) as String?,
    );
  }

  static TruckerPlaceCategory? _categoryFromTags(Map<String, dynamic> tags) {
    final amenity = tags['amenity'];
    final shop = tags['shop'];
    final service = tags['service'];

    if (amenity == 'fuel') return TruckerPlaceCategory.fuel;
    if (shop == 'tyres' || service == 'tyres') {
      return TruckerPlaceCategory.tire;
    }
    if (shop == 'car_repair' || amenity == 'vehicle_inspection') {
      return TruckerPlaceCategory.mechanic;
    }
    if (amenity == 'parking') return TruckerPlaceCategory.parking;
    if (amenity == 'restaurant' || amenity == 'fast_food') {
      return TruckerPlaceCategory.food;
    }
    if (amenity == 'hospital' || amenity == 'police') {
      return TruckerPlaceCategory.emergency;
    }
    return null;
  }

  static String? _composeAddress(Map<String, dynamic> tags) {
    final parts =
        [
          tags['addr:street'],
          tags['addr:housenumber'],
          tags['addr:city'],
          tags['addr:town'],
          tags['addr:village'],
        ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();

    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static bool _isInsideNarinoBounds(LatLng position) {
    return position.latitude >= _south &&
        position.latitude <= _north &&
        position.longitude >= _west &&
        position.longitude <= _east;
  }
}

import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../api_service.dart';
import '../observability/operational_logger.dart';

class RouteProviderException implements Exception {
  final String message;
  const RouteProviderException(this.message);
  @override
  String toString() => message;
}

class ORSService {
  static const int _maxAttempts = 3;

  /// Obtiene la ruta entre dos puntos usando el proveedor backend con reintentos.
  static Future<Map<String, dynamic>> obtenerRuta(
    LatLng origen,
    LatLng destino, {
    int intentos = 0,
  }) async {
    try {
      OperationalLogger.info(
        OperationalLogCategory.routing,
        'route_provider_request_started',
        fields: {'attempt': intentos + 1},
      );

      final data = {
        'origen': [origen.longitude, origen.latitude],  // OSRM usa [lng, lat]
        'destino': [destino.longitude, destino.latitude],
      };

      final url = '${ApiConfig.baseUrl}/ors/ruta';
      final response = await ApiService.post(url, data);

      // Parsear la respuesta
      if (response['coordinates'] != null) {
        final List<LatLng> routePoints = [];
        
        for (var coord in response['coordinates']) {
          if (coord is List && coord.length >= 2) {
            // OSRM devuelve [lng, lat], convertir a LatLng
            routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
          }
        }

        // Convertir distancia y duración a double/int correctamente
        final distancia = response['distancia'] is String 
            ? double.parse(response['distancia']) 
            : (response['distancia'] as num).toDouble();
        
        final duracionRaw = response['duracion'];
        final duracion =
            duracionRaw is String
                ? int.tryParse(duracionRaw) ?? 0
                : (duracionRaw as num?)?.toInt() ?? 0;

        if (routePoints.length < 2) {
          throw const RouteProviderException(
            'La ruta recibida no tiene geometría suficiente.',
          );
        }

        OperationalLogger.info(
          OperationalLogCategory.routing,
          'route_provider_request_completed',
          fields: {
            'routePoints': routePoints.length,
            'distanceKm': distancia.round(),
            'durationMinutes': duracion,
          },
        );

        return {
          'coordinates': routePoints,
          'distance': distancia,
          'duration': duracion,
        };
      }

      throw const RouteProviderException('Respuesta inválida del proveedor de rutas.');
    } catch (e) {
      OperationalLogger.error(
        OperationalLogCategory.routing,
        'route_provider_request_failed',
        error: e,
        fields: {'attempt': intentos + 1},
      );
      if (intentos + 1 < _maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (intentos + 1)));
        return obtenerRuta(origen, destino, intentos: intentos + 1);
      }
      if (e is RouteProviderException) rethrow;
      throw const RouteProviderException(
        'No se pudo calcular la ruta. Revisa tu conexión e intenta de nuevo.',
      );
    }
  }

  /// Obtiene instrucciones de navegación paso a paso
  static Future<List<String>> obtenerInstrucciones(LatLng origen, LatLng destino) async {
    try {
      await obtenerRuta(origen, destino);
      return [];
    } catch (e) {
      OperationalLogger.error(
        OperationalLogCategory.routing,
        'route_instruction_request_failed',
        error: e,
      );
      return [];
    }
  }
}

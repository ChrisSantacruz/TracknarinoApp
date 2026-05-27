import 'package:flutter/foundation.dart';

class ApiConfig {
  static const bool isDevelopment = bool.fromEnvironment(
    'TRACKNARINO_DEV',
    defaultValue: true,
  );
  static const String _productionBaseUrl = String.fromEnvironment(
    'TRACKNARINO_API_URL',
  );

  // Determinar la URL base correcta según la plataforma
  static String get _baseUrl {
    if (isDevelopment) {
      if (kIsWeb) {
        return 'http://localhost:4001/api';
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:4001/api';
      }
      return 'http://localhost:4001/api';
    }

    if (_productionBaseUrl.isEmpty) {
      throw StateError('TRACKNARINO_API_URL is required outside development');
    }
    return _productionBaseUrl;
  }

  // Permitir acceso público a la URL base
  static String get baseUrl => _baseUrl;
  static String get realtimeUrl => _baseUrl.replaceFirst(RegExp(r'/api$'), '');

  // Rutas de API
  static String get auth => '$_baseUrl/auth';
  static String get users => '$_baseUrl/users';
  static String get oportunidades => '$_baseUrl/oportunidades';
  static String get ubicacion => '$_baseUrl/ubicacion';
  static String get alertas => '$_baseUrl/alertas';
  static String get calificaciones => '$_baseUrl/calificaciones';
  static String get contratistas => '$_baseUrl/contratistas';
  static String get operations => '$_baseUrl/operations';

  // Rutas de autenticación
  static String get login => '$auth/login';
  static String get register => '$auth/register';

  // Tiempo de espera para solicitudes API
  static const int timeoutSeconds = 30;

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  // Parámetros de autenticación
  static const String tokenKey = 'auth_token';
}

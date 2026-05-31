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
        return 'http://localhost:4000/api';
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:4000/api';
      }
      return 'http://localhost:4000/api';
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
  static String get historial => '$_baseUrl/historial';
  static String get notificaciones => '$_baseUrl/notificaciones';

  // Rutas de autenticación
  static String get login => '$auth/login';
  static String get register => '$auth/register';
  static String get googleLogin => '$auth/google';
  static String get simulationLogin => '$auth/simulation';
  static String get configureRole => '$auth/role';

  // Tiempo de espera para solicitudes API
  static const int timeoutSeconds = 30;

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static const String googleAndroidServerClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_SERVER_CLIENT_ID',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  // Parámetros de autenticación
  static const String tokenKey = 'auth_token';
}

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'observability/operational_logger.dart';
import 'services/auth_service.dart'; // Para manejo de tokens

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isTimeout;

  const ApiException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
    this.isTimeout = false,
  });

  bool get isRetryable =>
      isNetworkError ||
      isTimeout ||
      statusCode == null ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() => message;
}

class ApiService {
  static Future<void> Function()? onUnauthorized;
  // Headers comunes para todas las peticiones
  static Map<String, String> _getHeaders({bool needsAuth = true}) {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    return headers;
  }

  // Agregar token de autorización a los headers
  static Future<Map<String, String>> _getAuthHeaders({
    bool needsAuth = true,
  }) async {
    Map<String, String> headers = _getHeaders(needsAuth: needsAuth);

    // Agregar token de autenticación si es necesario
    if (needsAuth) {
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        OperationalLogger.warning(
          OperationalLogCategory.security,
          'api_auth_token_missing',
        );
      }
    }

    return headers;
  }

  // Método GET
  static Future<dynamic> get(String url, {bool needsAuth = true}) async {
    try {
      _logRequest('GET', url, needsAuth: needsAuth);

      final uri = Uri.parse(url);
      final headers = await _getAuthHeaders(needsAuth: needsAuth);
      final response = await http
          .get(uri, headers: headers)
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      return _processResponse(response);
    } catch (e) {
      _logRequestError('GET', url, e);
      throw _handleError(e);
    }
  }

  // Método POST
  static Future<dynamic> post(
    String url,
    dynamic data, {
    bool needsAuth = true,
  }) async {
    try {
      _logRequest('POST', url, needsAuth: needsAuth);

      final uri = Uri.parse(url);
      final headers = await _getAuthHeaders(needsAuth: needsAuth);
      final response = await http
          .post(uri, headers: headers, body: jsonEncode(data))
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      return _processResponse(response);
    } catch (e) {
      _logRequestError('POST', url, e);
      throw _handleError(e);
    }
  }

  // Método POST sin autenticación (para login/registro)
  static Future<dynamic> postUnauth(String url, dynamic data) async {
    return post(url, data, needsAuth: false);
  }

  // Método PUT
  static Future<dynamic> put(
    String url,
    dynamic data, {
    bool needsAuth = true,
  }) async {
    try {
      _logRequest('PUT', url, needsAuth: needsAuth);

      final uri = Uri.parse(url);
      final headers = await _getAuthHeaders(needsAuth: needsAuth);
      final response = await http
          .put(uri, headers: headers, body: jsonEncode(data))
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      return _processResponse(response);
    } catch (e) {
      _logRequestError('PUT', url, e);
      throw _handleError(e);
    }
  }

  // Método DELETE
  static Future<dynamic> delete(String url, {bool needsAuth = true}) async {
    try {
      _logRequest('DELETE', url, needsAuth: needsAuth);

      final uri = Uri.parse(url);
      final headers = await _getAuthHeaders(needsAuth: needsAuth);
      final response = await http
          .delete(uri, headers: headers)
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      return _processResponse(response);
    } catch (e) {
      _logRequestError('DELETE', url, e);
      throw _handleError(e);
    }
  }

  // Procesar respuesta HTTP y manejar códigos de estado
  static dynamic _processResponse(http.Response response) {
    OperationalLogger.info(
      OperationalLogCategory.connectivity,
      'api_response',
      fields: {'statusCode': response.statusCode},
    );

    if (response.statusCode == 204 || response.body.isEmpty) {
      return {};
    }

    dynamic decodedBody;
    try {
      decodedBody = json.decode(response.body);
    } catch (e) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const ApiException(
          'Error en el formato de la respuesta del servidor',
        );
      }
      throw ApiException(
        _defaultMessageForStatus(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    if (response.statusCode == 401) {
      final handler = onUnauthorized;
      if (handler != null) {
        unawaited(handler());
      }
    }

    throw ApiException(
      _extractErrorMessage(decodedBody, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  static String _extractErrorMessage(dynamic decodedBody, int statusCode) {
    if (decodedBody is Map<String, dynamic>) {
      final message =
          decodedBody['mensaje'] ??
          decodedBody['message'] ??
          decodedBody['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    return _defaultMessageForStatus(statusCode);
  }

  static String _defaultMessageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Solicitud incorrecta. Por favor revisa los datos enviados.';
      case 401:
        return 'No autorizado. Por favor inicia sesión de nuevo.';
      case 403:
        return 'Acceso denegado. No tienes permiso para esta acción.';
      case 404:
        return 'La información solicitada no se encontró.';
      case 422:
        return 'Error de validación en los datos.';
      default:
        return 'Error en el servidor. Por favor intenta más tarde.';
    }
  }

  // Manejar errores comunes
  static ApiException _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }

    if (error is http.ClientException) {
      return const ApiException(
        'Error de conexión. Revisa tu conexión a internet.',
        isNetworkError: true,
      );
    }

    if (error is FormatException) {
      return const ApiException('Error en el formato de los datos.');
    }

    if (error is TimeoutException) {
      return const ApiException(
        'Tiempo de espera agotado. Intenta de nuevo más tarde.',
        isTimeout: true,
      );
    }

    if (error is String) {
      return ApiException(error);
    }

    return const ApiException('Se produjo un error inesperado.');
  }

  static void _logRequest(
    String method,
    String url, {
    required bool needsAuth,
  }) {
    OperationalLogger.info(
      OperationalLogCategory.connectivity,
      'api_request',
      fields: {
        'method': method,
        'path': Uri.tryParse(url)?.path ?? url,
        'needsAuth': needsAuth,
      },
    );
  }

  static void _logRequestError(String method, String url, Object error) {
    OperationalLogger.warning(
      OperationalLogCategory.connectivity,
      'api_request_failed',
      fields: {
        'method': method,
        'path': Uri.tryParse(url)?.path ?? url,
        'errorType': error.runtimeType.toString(),
      },
    );
  }
}

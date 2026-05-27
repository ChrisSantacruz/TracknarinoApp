import 'package:flutter/foundation.dart';

import '../api_service.dart';
import '../config/api_config.dart';
import '../models/oportunidad_model.dart';
import '../offline/sync_engine.dart';
import 'auth_service.dart';

class TripActionQueuedException implements Exception {
  final String message;

  const TripActionQueuedException(this.message);

  @override
  String toString() => message;
}

class OportunidadService {
  // Obtener listado de oportunidades disponibles
  static Future<List<Oportunidad>> obtenerOportunidadesDisponibles() async {
    try {
      final response = await ApiService.get(ApiConfig.oportunidades);
      return (response as List)
          .map((data) => Oportunidad.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener oportunidades: $e');
      rethrow;
    }
  }

  static Future<List<Oportunidad>> obtenerOportunidadesContratista() async {
    try {
      final response = await ApiService.get(ApiConfig.oportunidades);
      return (response as List)
          .map((data) => Oportunidad.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener oportunidades del contratista: $e');
      rethrow;
    }
  }

  // Obtener detalles de una oportunidad específica
  static Future<Oportunidad?> obtenerDetalleOportunidad(String id) async {
    try {
      final response = await ApiService.get('${ApiConfig.oportunidades}/$id');
      return Oportunidad.fromJson(response);
    } catch (e) {
      debugPrint('Error al obtener detalle de oportunidad: $e');
      return null;
    }
  }

  // Aplicar a una oportunidad
  static Future<Map<String, dynamic>> aplicarOportunidad(
    String oportunidadId,
  ) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.oportunidades}/aplicar/$oportunidadId',
        {},
      );
      return response;
    } catch (e) {
      debugPrint('Error al aplicar a oportunidad: $e');
      rethrow;
    }
  }

  // Crear una nueva oportunidad (solo contratistas)
  static Future<Oportunidad?> crearOportunidad({
    required String titulo,
    String? descripcion,
    required String origen,
    required String destino,
    required DateTime fecha,
    required double precio,
  }) async {
    try {
      final data = {
        'titulo': titulo,
        'descripcion': descripcion,
        'origen': origen,
        'destino': destino,
        'fecha': fecha.toIso8601String(),
        'precio': precio,
      };

      final response = await ApiService.post(
        '${ApiConfig.oportunidades}/crear',
        data,
      );
      return Oportunidad.fromJson(response['oportunidad']);
    } catch (e) {
      debugPrint('Error al crear oportunidad: $e');
      return null;
    }
  }

  // Crear una nueva oportunidad con todos los campos (solo contratistas)
  static Future<Oportunidad?> crearOportunidadCompleta(
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('Intentando crear oportunidad con datos: $data');
      final response = await ApiService.post(
        '${ApiConfig.oportunidades}/crear',
        data,
      );

      debugPrint('Respuesta del servidor al crear oportunidad: $response');
      return Oportunidad.fromJson(response['oportunidad']);
    } catch (e) {
      debugPrint('Error detallado al crear oportunidad completa: $e');
      rethrow;
    }
  }

  // Asignar un camionero a una oportunidad (solo contratistas)
  static Future<bool> asignarCamionero({
    required String oportunidadId,
    required String camioneroId,
  }) async {
    try {
      final data = {'camioneroId': camioneroId};

      await ApiService.post(
        '${ApiConfig.oportunidades}/asignar/$oportunidadId',
        data,
      );
      return true;
    } catch (e) {
      debugPrint('Error al asignar camionero: $e');
      return false;
    }
  }

  // Finalizar una carga (solo contratistas)
  static Future<bool> finalizarCarga(String oportunidadId) async {
    try {
      await ApiService.post(
        '${ApiConfig.oportunidades}/finalizar/$oportunidadId',
        {},
      );
      return true;
    } catch (e) {
      debugPrint('Error al finalizar carga: $e');
      return false;
    }
  }

  /// Aceptar una oportunidad (nuevo método con validaciones)
  static Future<Oportunidad> aceptarOportunidad(String oportunidadId) async {
    final endpoint = '${ApiConfig.oportunidades}/$oportunidadId/aceptar';
    try {
      final response = await ApiService.put(endpoint, {});

      return Oportunidad.fromJson(response['oportunidad']);
    } catch (e) {
      if (e is ApiException && e.isRetryable) {
        await _queueTripAction(
          endpoint: endpoint,
          method: 'PUT',
          action: 'aceptar',
          oportunidadId: oportunidadId,
        );
        throw const TripActionQueuedException(
          'Aceptación guardada. Se confirmará cuando vuelva la conexión.',
        );
      }
      debugPrint('Error al aceptar oportunidad: $e');
      rethrow;
    }
  }

  static Future<Oportunidad> enviarOfertaPrecio({
    required String oportunidadId,
    required double precioOfertado,
    String? mensaje,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.oportunidades}/$oportunidadId/oferta',
      {
        'precioOfertado': precioOfertado,
        if (mensaje != null && mensaje.trim().isNotEmpty)
          'mensaje': mensaje.trim(),
      },
    );
    return Oportunidad.fromJson(response['oportunidad']);
  }

  static Future<Oportunidad> cancelarOfertaPrecio(String oportunidadId) async {
    final response = await ApiService.delete(
      '${ApiConfig.oportunidades}/$oportunidadId/oferta',
    );
    return Oportunidad.fromJson(response['oportunidad']);
  }

  static Future<Oportunidad> enviarContraofertaPrecio({
    required String oportunidadId,
    required double precioContraoferta,
    String? mensaje,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.oportunidades}/$oportunidadId/contraoferta',
      {
        'precioContraoferta': precioContraoferta,
        if (mensaje != null && mensaje.trim().isNotEmpty)
          'mensaje': mensaje.trim(),
      },
    );
    return Oportunidad.fromJson(response['oportunidad']);
  }

  static Future<Oportunidad> aceptarOfertaCamionero(String oportunidadId) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.oportunidades}/$oportunidadId/oferta/aceptar',
        {},
      );
      return Oportunidad.fromJson(response['oportunidad']);
    } catch (_) {
      final response = await ApiService.post(
        '${ApiConfig.oportunidades}/oferta/aceptar/$oportunidadId',
        {},
      );
      return Oportunidad.fromJson(response['oportunidad']);
    }
  }

  static Future<Oportunidad> aceptarContraoferta(String oportunidadId) async {
    final response = await ApiService.put(
      '${ApiConfig.oportunidades}/$oportunidadId/contraoferta/aceptar',
      {},
    );
    return Oportunidad.fromJson(response['oportunidad']);
  }

  /// Obtener viaje activo del camionero
  static Future<Oportunidad?> obtenerViajeActivo() async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.oportunidades}/viaje-activo',
      );

      if (response['viajeActivo'] == null) {
        return null;
      }

      return Oportunidad.fromJson(response['viajeActivo']);
    } catch (e) {
      debugPrint('Error al obtener viaje activo: $e');
      return null;
    }
  }

  /// Iniciar viaje
  static Future<Oportunidad> iniciarViaje(String oportunidadId) async {
    final endpoint = '${ApiConfig.oportunidades}/$oportunidadId/iniciar';
    try {
      final response = await ApiService.put(endpoint, {});

      return Oportunidad.fromJson(response['oportunidad']);
    } catch (e) {
      if (e is ApiException && e.isRetryable) {
        await _queueTripAction(
          endpoint: endpoint,
          method: 'PUT',
          action: 'iniciar',
          oportunidadId: oportunidadId,
        );
        throw const TripActionQueuedException(
          'Inicio de viaje guardado. Queda pendiente de confirmación del servidor.',
        );
      }
      debugPrint('Error al iniciar viaje: $e');
      rethrow;
    }
  }

  static Future<void> _queueTripAction({
    required String endpoint,
    required String method,
    required String action,
    required String oportunidadId,
  }) async {
    final timestamp = DateTime.now().toUtc();
    final localUserId = await AuthService.getStoredUserId();
    final clientEventId =
        'trip_${action}_${oportunidadId}_${timestamp.millisecondsSinceEpoch}';

    await SyncEngine.instance.enqueueTripAction(
      endpoint: endpoint,
      method: method,
      payload: {
        'clientEventId': clientEventId,
        'clientTimestamp': timestamp.toIso8601String(),
        'action': action,
        'oportunidadId': oportunidadId,
        if (localUserId != null) 'localUserId': localUserId,
      },
      clientEventId: clientEventId,
      clientTimestamp: timestamp,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config/api_config.dart';
import '../models/alerta_model.dart';
import '../api_service.dart';
import '../offline/sync_engine.dart';
import 'auth_service.dart';

class AlertaService {
  // Crear una nueva alerta de seguridad
  static Future<AlertaSeguridad?> crearAlerta({
    required String tipo,
    required Map<String, double> coords,
    String? descripcion,
    String? imagePath,
    bool compartir = true,
  }) async {
    try {
      final timestamp = DateTime.now().toUtc();
      final localUserId = await AuthService.getStoredUserId();
      final clientEventId =
          'alert_${timestamp.millisecondsSinceEpoch}_${tipo}_${coords['lat']?.toStringAsFixed(5)}_${coords['lng']?.toStringAsFixed(5)}';
      final Map<String, dynamic> data = {
        'tipo': tipo,
        'coords': coords,
        'descripcion': descripcion,
        'compartir': compartir,
        'timestamp': timestamp.toIso8601String(),
        'clientEventId': clientEventId,
        if (localUserId != null) 'localUserId': localUserId,
      };

      if (imagePath != null) {
        throw Exception(
          'La subida de imágenes de alertas aún no está disponible en el backend',
        );
      }

      await SyncEngine.instance.enqueueAlert(
        endpoint: ApiConfig.alertas,
        payload: data,
        clientEventId: clientEventId,
        clientTimestamp: timestamp,
      );

      return AlertaSeguridad(
        id: clientEventId,
        tipo: tipo,
        descripcion: descripcion,
        usuario: 'local',
        coords: coords,
        timestamp: timestamp,
      );
    } catch (e) {
      debugPrint('Error al crear alerta: $e');
      rethrow;
    }
  }

  // Obtener alertas cercanas a una posición
  static Future<List<AlertaSeguridad>> obtenerAlertasCercanas(
    Position position,
  ) async {
    try {
      final data = {
        'lat': position.latitude,
        'lng': position.longitude,
        'radio': 50000, // 50 km de radio para buscar alertas
      };

      final response = await ApiService.post(
        '${ApiConfig.alertas}/cercanas',
        data,
      );

      // La respuesta es directamente un array de alertas
      return (response as List)
          .map((data) => AlertaSeguridad.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener alertas cercanas: $e');
      rethrow;
    }
  }

  // Obtener todas las alertas recientes (últimas 24 horas)
  static Future<List<AlertaSeguridad>> obtenerAlertasRecientes() async {
    try {
      final response = await ApiService.get('${ApiConfig.alertas}/recientes');
      return (response as List)
          .map((data) => AlertaSeguridad.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener alertas recientes: $e');
      rethrow;
    }
  }

  // Confirmar una alerta existente
  static Future<bool> confirmarAlerta(String alertaId) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.alertas}/confirmar/$alertaId',
        {},
      );

      return response['success'] == true;
    } catch (e) {
      debugPrint('Error al confirmar alerta: $e');
      return false;
    }
  }

  // Compartir una alerta existente
  static Future<bool> compartirAlerta(String alertaId) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.alertas}/compartir/$alertaId',
        {},
      );

      return response['success'] == true;
    } catch (e) {
      debugPrint('Error al compartir alerta: $e');
      return false;
    }
  }
}

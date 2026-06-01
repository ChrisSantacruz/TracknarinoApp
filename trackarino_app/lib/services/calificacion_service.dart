import '../api_service.dart';
import '../config/api_config.dart';

class CalificacionService {
  static Future<List<Map<String, dynamic>>> listarPorUsuario(
    String usuarioId,
  ) async {
    final response = await ApiService.get(
      '${ApiConfig.calificaciones}/listar/$usuarioId',
    );
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<void> crearCalificacion({
    required String usuarioId,
    required String tipoServicio,
    required int calificacion,
    String? comentario,
  }) async {
    await ApiService.post('${ApiConfig.calificaciones}/crear', {
      'usuarioId': usuarioId,
      'tipoServicio': tipoServicio,
      'calificacion': calificacion,
      if (comentario != null && comentario.trim().isNotEmpty)
        'comentario': comentario.trim(),
    });
  }
}

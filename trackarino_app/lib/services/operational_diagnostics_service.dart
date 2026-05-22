import '../api_service.dart';
import '../config/api_config.dart';
import '../models/operational_diagnostics_model.dart';

class OperationalDiagnosticsService {
  const OperationalDiagnosticsService._();

  static Future<OperationalDiagnostics> fetchDiagnostics({
    int sinceHours = 24,
  }) async {
    final response = await ApiService.get(
      '${ApiConfig.operations}/diagnostics?sinceHours=$sinceHours',
    );

    final diagnostics = response['diagnostics'];
    if (diagnostics is! Map) {
      throw const ApiException('Respuesta de diagnósticos inválida.');
    }

    return OperationalDiagnostics.fromJson(
      diagnostics.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

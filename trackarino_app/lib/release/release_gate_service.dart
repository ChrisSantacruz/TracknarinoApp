import '../api_service.dart';
import '../config/api_config.dart';
import 'operational_release_gate.dart';

class ReleaseGateService {
  const ReleaseGateService._();

  static Future<OperationalReleaseStatus> fetchReleaseGates() async {
    final response = await ApiService.get('${ApiConfig.operations}/release-gates');
    final releaseGates = response['releaseGates'];
    if (releaseGates is! Map) {
      throw const ApiException('Respuesta de release gates inválida.');
    }

    return OperationalReleaseStatus.fromJson(
      releaseGates.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

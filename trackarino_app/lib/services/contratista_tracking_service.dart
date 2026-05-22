import '../config/api_config.dart';
import '../api_service.dart';
import '../models/fleet_tracking_item.dart';

/// Polling-based fleet tracking for contractors (future: WebSocket subscription).
class ContratistaTrackingService {
  static Future<List<FleetTrackingItem>> fetchFleet() async {
    final response = await ApiService.get(
      '${ApiConfig.contratistas}/tracking/flota',
    );

    final fleet = response['fleet'];
    if (fleet is! List) return [];

    return fleet
        .whereType<Map<String, dynamic>>()
        .map(FleetTrackingItem.fromJson)
        .toList();
  }
}

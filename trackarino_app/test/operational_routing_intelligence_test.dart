import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackarino_app/models/alerta_model.dart';
import 'package:trackarino_app/offline/connectivity_service.dart';
import 'package:trackarino_app/routing/operational_routing_intelligence.dart';

void main() {
  const route = [LatLng(0, 0), LatLng(0, 0.02)];
  final createdAt = DateTime.utc(2026, 5, 22, 12);

  test('keeps small GPS drift on route until deviation is confirmed', () {
    final controller = OperationalRoutingController();
    controller.replaceRoute(route, createdAt: createdAt);

    final assessment = controller.assess(
      currentPosition: const LatLng(0.0011, 0.01),
      alerts: const [],
      connectivity: ConnectivityHealth.internetReachable,
      now: createdAt.add(const Duration(minutes: 5)),
    );

    expect(assessment.deviationSeverity, RouteDeviationSeverity.onRoute);
    expect(assessment.health, RouteHealthState.healthy);
    expect(assessment.rerouteRecommended, isFalse);
  });

  test('confirms significant off-route behavior after repeated samples', () {
    final controller = OperationalRoutingController();
    controller.replaceRoute(route, createdAt: createdAt);

    OperationalRouteAssessment assessment = controller.assess(
      currentPosition: const LatLng(0.003, 0.01),
      alerts: const [],
      connectivity: ConnectivityHealth.internetReachable,
      now: createdAt.add(const Duration(minutes: 5)),
    );

    assessment = controller.assess(
      currentPosition: const LatLng(0.003, 0.0102),
      alerts: const [],
      connectivity: ConnectivityHealth.internetReachable,
      now: createdAt.add(const Duration(minutes: 6)),
    );

    assessment = controller.assess(
      currentPosition: const LatLng(0.003, 0.0104),
      alerts: const [],
      connectivity: ConnectivityHealth.internetReachable,
      now: createdAt.add(const Duration(minutes: 7)),
    );

    expect(assessment.deviationSeverity, RouteDeviationSeverity.significant);
    expect(assessment.health, RouteHealthState.degraded);
    expect(assessment.rerouteRecommended, isTrue);
    expect(assessment.rerouteTrigger, RerouteTrigger.severeDeviation);
  });

  test('scores severe real alerts intersecting the active corridor', () {
    final controller = OperationalRoutingController();
    controller.replaceRoute(route, createdAt: createdAt);
    final alert = AlertaSeguridad(
      id: 'a1',
      tipo: 'robo',
      usuario: 'u1',
      coords: const {'lat': 0.0002, 'lng': 0.011},
      timestamp: createdAt.add(const Duration(minutes: 2)),
    );

    final assessment = controller.assess(
      currentPosition: const LatLng(0, 0.01),
      alerts: [alert],
      connectivity: ConnectivityHealth.internetReachable,
      now: createdAt.add(const Duration(minutes: 10)),
    );

    expect(assessment.corridorAlerts, hasLength(1));
    expect(assessment.health, RouteHealthState.degraded);
    expect(assessment.rerouteRecommended, isTrue);
    expect(assessment.rerouteTrigger, RerouteTrigger.blockedCorridor);
    expect(assessment.degradedSegments, isNotEmpty);
  });

  test('preserves route offline without recommending fake reroute', () {
    final controller = OperationalRoutingController();
    controller.replaceRoute(route, createdAt: createdAt);

    final assessment = controller.assess(
      currentPosition: const LatLng(0.003, 0.01),
      alerts: const [],
      connectivity: ConnectivityHealth.offline,
      now: createdAt.add(const Duration(minutes: 8)),
    );

    expect(assessment.health, RouteHealthState.offline);
    expect(assessment.offline, isTrue);
    expect(assessment.rerouteRecommended, isFalse);
    expect(assessment.rerouteConfidence, RerouteConfidence.unavailable);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trackarino_app/device_lab/device_lab_bundle.dart';
import 'package:trackarino_app/device_lab/device_lab_capture_profile.dart';
import 'package:trackarino_app/models/operational_diagnostics_model.dart';
import 'package:trackarino_app/release/operational_release_gate.dart';

void main() {
  test('parses Phase 10 diagnostics without inventing missing metrics', () {
    final diagnostics = OperationalDiagnostics.fromJson({
      'generatedAt': '2026-05-22T00:00:00.000Z',
      'severity': 'warning',
      'window': {'since': '2026-05-21T00:00:00.000Z', 'hours': 24},
      'fleetHealth': {
        'totalTracked': 3,
        'active': 1,
        'stale': 1,
        'offline': 1,
        'offlineReplay': 0,
        'poorAccuracy': 0,
        'severity': 'warning',
      },
      'routeAnalytics': {
        'activeRoutes': 2,
        'counts': {'rerouteFrequency': 1},
        'operationalPressure': {
          'reroutePressure': 1,
          'routeReplacementPressure': 0,
          'degradedRouteFrequency': 1,
          'corridorInstability': 0,
        },
      },
      'realtimeHealth': {
        'nodeId': 'node-test',
        'connectedSockets': 2,
        'knownRooms': 4,
        'adapter': {'status': 'ready', 'type': 'redis'},
        'reconnectStorm': {'state': 'normal', 'recentConnectionCount': 1},
        'roomOccupancy': [
          {'room': 'route:real-route', 'sockets': 2},
        ],
        'scaling': {
          'multiNodeCompatible': true,
          'stickySessionsRequired': true,
        },
      },
      'providerHealth': {
        'provider': 'public_osrm',
        'status': 'unknown',
        'successes': 0,
        'failures': 0,
        'recentFailureRate': 0,
      },
      'operationalMetrics': {
        'counters': [
          {'key': 'socket.emit.rooms', 'total': 2, 'samples': 1},
        ],
        'latency': [
          {'key': 'socket.emit.latency_ms', 'samples': 1, 'p95': 4},
        ],
      },
      'environmentReadiness': {
        'ok': true,
        'features': {
          'redisSocketAdapter': true,
          'operationalReplay': true,
          'routeDiagnostics': true,
        },
        'providers': {'providerReady': true},
      },
      'replayReadiness': {
        'timelineAvailable': true,
        'routeLifecycleReplay': true,
        'offlineRecoveryVisibility': 'mobile_local_queue',
        'rawGpsPlaybackStored': false,
        'note': 'real audit only',
      },
      'timeline': [
        {
          'eventType': 'route.degraded',
          'severity': 'warning',
          'occurredAt': '2026-05-22T00:00:00.000Z',
        },
      ],
    });

    expect(diagnostics.routeAnalytics.operationalPressure.reroutePressure, 1);
    expect(diagnostics.realtimeHealth.multiNodeCompatible, isTrue);
    expect(diagnostics.realtimeHealth.roomOccupancy.single.sockets, 2);
    expect(diagnostics.operationalMetrics.counters.single.total, 2);
  });

  test('exports device-lab bundles as replay-ready evidence metadata', () {
    final bundle = DeviceLabDiagnosticsBundle(
      profile: DeviceLabCaptureProfile(
        sessionId: 'session-1',
        correlationId: 'corr-1',
        scenarioType: DeviceLabScenarioType.degradedNetwork,
        startedAt: DateTime.utc(2026, 5, 22),
      ),
      generatedAt: DateTime.utc(2026, 5, 22, 1),
      timeline: [
        DeviceLabTimelineEvent(
          type: 'connectivity.degraded',
          occurredAt: DateTime.utc(2026, 5, 22, 0, 30),
          severity: 'warning',
        ),
      ],
    );

    final json = jsonDecode(bundle.toPrettyJson()) as Map<String, dynamic>;
    expect(json['replayReady'], isTrue);
    expect(json['profile']['correlationId'], 'corr-1');
    expect(json['timeline'], hasLength(1));
    expect(json['replayPolicy'], contains('interpolation'));
  });

  test('parses release gates without treating blockers as success', () {
    final release = OperationalReleaseStatus.fromJson({
      'generatedAt': '2026-05-22T00:00:00.000Z',
      'overallState': 'fail',
      'releaseConfidenceScore': {
        'value': 31,
        'basis': 'gate-derived only',
      },
      'gates': [
        {
          'id': 'evidence_completeness',
          'category': 'evidence_completeness',
          'severity': 'critical',
          'state': 'blocked',
          'evidenceRequired': ['release_evidence_manifest'],
          'issues': [
            {
              'severity': 'critical',
              'code': 'EVIDENCE_MANIFEST_NOT_CONFIGURED',
              'message': 'missing manifest',
            },
          ],
        },
      ],
      'readinessScores': [
        {'category': 'evidence_completeness', 'score': 0, 'state': 'fail'},
      ],
      'unresolvedBlockers': [
        {
          'gateId': 'evidence_completeness',
          'severity': 'critical',
          'code': 'EVIDENCE_MANIFEST_NOT_CONFIGURED',
          'message': 'missing manifest',
        },
      ],
      'evidence': {
        'completeness': {
          'scenarioCoverage': 0,
          'verifiedArtifacts': 0,
          'checkedArtifacts': 0,
          'missingScenarioTypes': ['long_route'],
        },
      },
      'operationalNotes': ['no fake evidence'],
    });

    expect(release.overallState, 'fail');
    expect(release.confidenceScore, 31);
    expect(release.gates.single.state, 'blocked');
    expect(release.unresolvedBlockers.single.code, contains('EVIDENCE'));
    expect(release.evidenceCompleteness.missingScenarioTypes, contains('long_route'));
  });
}

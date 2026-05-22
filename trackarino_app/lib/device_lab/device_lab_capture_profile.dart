enum DeviceLabScenarioType {
  longTrip,
  degradedNetwork,
  reconnectStorm,
  tunnelLostSignal,
  gpsDrift,
  batterySensitiveTracking,
  memoryPressure,
}

class DeviceLabCaptureProfile {
  final String sessionId;
  final String correlationId;
  final DeviceLabScenarioType scenarioType;
  final DateTime startedAt;
  final Map<String, String> labels;

  const DeviceLabCaptureProfile({
    required this.sessionId,
    required this.correlationId,
    required this.scenarioType,
    required this.startedAt,
    this.labels = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'sessionId': sessionId,
      'correlationId': correlationId,
      'scenarioType': scenarioType.name,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'labels': labels,
      'truthPolicy':
          'Captured evidence only. No fake sessions, GPS movement, telemetry, ETAs, or operational states.',
    };
  }
}

class DeviceLabTimelineEvent {
  final String type;
  final DateTime occurredAt;
  final String? routeId;
  final String? tripId;
  final String? severity;
  final Map<String, Object?> metadata;

  const DeviceLabTimelineEvent({
    required this.type,
    required this.occurredAt,
    this.routeId,
    this.tripId,
    this.severity,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      if (routeId != null) 'routeId': routeId,
      if (tripId != null) 'tripId': tripId,
      if (severity != null) 'severity': severity,
      'metadata': metadata,
    };
  }
}

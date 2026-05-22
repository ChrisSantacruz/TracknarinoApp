class OperationalDiagnostics {
  final DateTime generatedAt;
  final String severity;
  final DiagnosticsWindow window;
  final FleetHealth fleetHealth;
  final RouteAnalytics routeAnalytics;
  final RealtimeHealth realtimeHealth;
  final ProviderHealth providerHealth;
  final OperationalMetrics operationalMetrics;
  final EnvironmentReadiness environmentReadiness;
  final ReplayReadiness replayReadiness;
  final List<IncidentTimelineEvent> timeline;

  const OperationalDiagnostics({
    required this.generatedAt,
    required this.severity,
    required this.window,
    required this.fleetHealth,
    required this.routeAnalytics,
    required this.realtimeHealth,
    required this.providerHealth,
    required this.operationalMetrics,
    required this.environmentReadiness,
    required this.replayReadiness,
    required this.timeline,
  });

  factory OperationalDiagnostics.fromJson(Map<String, dynamic> json) {
    return OperationalDiagnostics(
      generatedAt:
          DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
      severity: json['severity']?.toString() ?? 'info',
      window: DiagnosticsWindow.fromJson(_map(json['window'])),
      fleetHealth: FleetHealth.fromJson(_map(json['fleetHealth'])),
      routeAnalytics: RouteAnalytics.fromJson(_map(json['routeAnalytics'])),
      realtimeHealth: RealtimeHealth.fromJson(_map(json['realtimeHealth'])),
      providerHealth: ProviderHealth.fromJson(_map(json['providerHealth'])),
      operationalMetrics: OperationalMetrics.fromJson(
        _map(json['operationalMetrics']),
      ),
      environmentReadiness: EnvironmentReadiness.fromJson(
        _map(json['environmentReadiness']),
      ),
      replayReadiness: ReplayReadiness.fromJson(_map(json['replayReadiness'])),
      timeline:
          _list(json['timeline'])
              .map((event) => IncidentTimelineEvent.fromJson(_map(event)))
              .toList(),
    );
  }
}

class DiagnosticsWindow {
  final DateTime since;
  final int hours;

  const DiagnosticsWindow({required this.since, required this.hours});

  factory DiagnosticsWindow.fromJson(Map<String, dynamic> json) {
    return DiagnosticsWindow(
      since:
          DateTime.tryParse(json['since']?.toString() ?? '') ?? DateTime.now(),
      hours: (json['hours'] as num?)?.toInt() ?? 24,
    );
  }
}

class FleetHealth {
  final int totalTracked;
  final int active;
  final int stale;
  final int offline;
  final int offlineReplay;
  final int poorAccuracy;
  final String severity;

  const FleetHealth({
    required this.totalTracked,
    required this.active,
    required this.stale,
    required this.offline,
    required this.offlineReplay,
    required this.poorAccuracy,
    required this.severity,
  });

  factory FleetHealth.fromJson(Map<String, dynamic> json) {
    return FleetHealth(
      totalTracked: (json['totalTracked'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      stale: (json['stale'] as num?)?.toInt() ?? 0,
      offline: (json['offline'] as num?)?.toInt() ?? 0,
      offlineReplay: (json['offlineReplay'] as num?)?.toInt() ?? 0,
      poorAccuracy: (json['poorAccuracy'] as num?)?.toInt() ?? 0,
      severity: json['severity']?.toString() ?? 'info',
    );
  }
}

class RouteAnalytics {
  final int activeRoutes;
  final Map<String, int> counts;
  final List<NamedCount> rerouteCauses;
  final List<RouteHotspot> invalidationHotspots;
  final List<RouteHotspot> corridorAlertDensity;
  final List<ProviderReliability> providerReliability;
  final OperationalPressure operationalPressure;

  const RouteAnalytics({
    required this.activeRoutes,
    required this.counts,
    required this.rerouteCauses,
    required this.invalidationHotspots,
    required this.corridorAlertDensity,
    required this.providerReliability,
    required this.operationalPressure,
  });

  factory RouteAnalytics.fromJson(Map<String, dynamic> json) {
    return RouteAnalytics(
      activeRoutes: (json['activeRoutes'] as num?)?.toInt() ?? 0,
      counts: _intMap(_map(json['counts'])),
      rerouteCauses:
          _list(json['rerouteCauses'])
              .map((item) => NamedCount.fromJson(_map(item), 'reason'))
              .toList(),
      invalidationHotspots:
          _list(json['invalidationHotspots'])
              .map((item) => RouteHotspot.fromJson(_map(item)))
              .toList(),
      corridorAlertDensity:
          _list(json['corridorAlertDensity'])
              .map((item) => RouteHotspot.fromJson(_map(item)))
              .toList(),
      providerReliability:
          _list(json['providerReliability'])
              .map((item) => ProviderReliability.fromJson(_map(item)))
              .toList(),
      operationalPressure: OperationalPressure.fromJson(
        _map(json['operationalPressure']),
      ),
    );
  }
}

class OperationalPressure {
  final int reroutePressure;
  final int routeReplacementPressure;
  final int degradedRouteFrequency;
  final int corridorInstability;

  const OperationalPressure({
    required this.reroutePressure,
    required this.routeReplacementPressure,
    required this.degradedRouteFrequency,
    required this.corridorInstability,
  });

  factory OperationalPressure.fromJson(Map<String, dynamic> json) {
    return OperationalPressure(
      reroutePressure: (json['reroutePressure'] as num?)?.toInt() ?? 0,
      routeReplacementPressure:
          (json['routeReplacementPressure'] as num?)?.toInt() ?? 0,
      degradedRouteFrequency:
          (json['degradedRouteFrequency'] as num?)?.toInt() ?? 0,
      corridorInstability: (json['corridorInstability'] as num?)?.toInt() ?? 0,
    );
  }
}

class NamedCount {
  final String name;
  final int count;

  const NamedCount({required this.name, required this.count});

  factory NamedCount.fromJson(Map<String, dynamic> json, String nameKey) {
    return NamedCount(
      name: json[nameKey]?.toString() ?? 'sin clasificar',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class RouteHotspot {
  final String routeId;
  final String? reason;
  final int count;
  final DateTime? lastSeenAt;

  const RouteHotspot({
    required this.routeId,
    required this.reason,
    required this.count,
    required this.lastSeenAt,
  });

  factory RouteHotspot.fromJson(Map<String, dynamic> json) {
    return RouteHotspot(
      routeId: json['routeId']?.toString() ?? 'sin ruta',
      reason: json['reason']?.toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? ''),
    );
  }
}

class ProviderReliability {
  final String provider;
  final int latencySamples;
  final int failures;
  final double? avgLatencyMs;
  final double failureRate;

  const ProviderReliability({
    required this.provider,
    required this.latencySamples,
    required this.failures,
    required this.avgLatencyMs,
    required this.failureRate,
  });

  factory ProviderReliability.fromJson(Map<String, dynamic> json) {
    return ProviderReliability(
      provider: json['provider']?.toString() ?? 'unknown',
      latencySamples: (json['latencySamples'] as num?)?.toInt() ?? 0,
      failures: (json['failures'] as num?)?.toInt() ?? 0,
      avgLatencyMs: (json['avgLatencyMs'] as num?)?.toDouble(),
      failureRate: (json['failureRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RealtimeHealth {
  final String nodeId;
  final int connectedSockets;
  final int knownRooms;
  final String adapterStatus;
  final String adapterType;
  final String reconnectStormState;
  final int recentConnectionCount;
  final List<RoomOccupancy> roomOccupancy;
  final bool multiNodeCompatible;
  final bool stickySessionsRequired;

  const RealtimeHealth({
    required this.nodeId,
    required this.connectedSockets,
    required this.knownRooms,
    required this.adapterStatus,
    required this.adapterType,
    required this.reconnectStormState,
    required this.recentConnectionCount,
    required this.roomOccupancy,
    required this.multiNodeCompatible,
    required this.stickySessionsRequired,
  });

  factory RealtimeHealth.fromJson(Map<String, dynamic> json) {
    final adapter = _map(json['adapter']);
    final storm = _map(json['reconnectStorm']);
    final scaling = _map(json['scaling']);
    return RealtimeHealth(
      nodeId: json['nodeId']?.toString() ?? 'node',
      connectedSockets: (json['connectedSockets'] as num?)?.toInt() ?? 0,
      knownRooms: (json['knownRooms'] as num?)?.toInt() ?? 0,
      adapterStatus: adapter['status']?.toString() ?? 'local',
      adapterType: adapter['type']?.toString() ?? 'memory',
      reconnectStormState: storm['state']?.toString() ?? 'normal',
      recentConnectionCount:
          (storm['recentConnectionCount'] as num?)?.toInt() ?? 0,
      roomOccupancy:
          _list(json['roomOccupancy'])
              .map((item) => RoomOccupancy.fromJson(_map(item)))
              .toList(),
      multiNodeCompatible: scaling['multiNodeCompatible'] == true,
      stickySessionsRequired: scaling['stickySessionsRequired'] == true,
    );
  }
}

class RoomOccupancy {
  final String room;
  final int sockets;

  const RoomOccupancy({required this.room, required this.sockets});

  factory RoomOccupancy.fromJson(Map<String, dynamic> json) {
    return RoomOccupancy(
      room: json['room']?.toString() ?? 'room',
      sockets: (json['sockets'] as num?)?.toInt() ?? 0,
    );
  }
}

class OperationalMetrics {
  final List<OperationalMetricCounter> counters;
  final List<OperationalLatencyMetric> latency;

  const OperationalMetrics({required this.counters, required this.latency});

  factory OperationalMetrics.fromJson(Map<String, dynamic> json) {
    return OperationalMetrics(
      counters:
          _list(json['counters'])
              .map((item) => OperationalMetricCounter.fromJson(_map(item)))
              .toList(),
      latency:
          _list(json['latency'])
              .map((item) => OperationalLatencyMetric.fromJson(_map(item)))
              .toList(),
    );
  }
}

class OperationalMetricCounter {
  final String key;
  final int total;
  final int samples;

  const OperationalMetricCounter({
    required this.key,
    required this.total,
    required this.samples,
  });

  factory OperationalMetricCounter.fromJson(Map<String, dynamic> json) {
    return OperationalMetricCounter(
      key: json['key']?.toString() ?? 'counter',
      total: (json['total'] as num?)?.toInt() ?? 0,
      samples: (json['samples'] as num?)?.toInt() ?? 0,
    );
  }
}

class OperationalLatencyMetric {
  final String key;
  final int samples;
  final double? p95;
  final double? p99;

  const OperationalLatencyMetric({
    required this.key,
    required this.samples,
    required this.p95,
    required this.p99,
  });

  factory OperationalLatencyMetric.fromJson(Map<String, dynamic> json) {
    return OperationalLatencyMetric(
      key: json['key']?.toString() ?? 'latency',
      samples: (json['samples'] as num?)?.toInt() ?? 0,
      p95: (json['p95'] as num?)?.toDouble(),
      p99: (json['p99'] as num?)?.toDouble(),
    );
  }
}

class ProviderHealth {
  final String provider;
  final String status;
  final int successes;
  final int failures;
  final double recentFailureRate;
  final int? lastLatencyMs;

  const ProviderHealth({
    required this.provider,
    required this.status,
    required this.successes,
    required this.failures,
    required this.recentFailureRate,
    required this.lastLatencyMs,
  });

  factory ProviderHealth.fromJson(Map<String, dynamic> json) {
    return ProviderHealth(
      provider: json['provider']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'unknown',
      successes: (json['successes'] as num?)?.toInt() ?? 0,
      failures: (json['failures'] as num?)?.toInt() ?? 0,
      recentFailureRate: (json['recentFailureRate'] as num?)?.toDouble() ?? 0,
      lastLatencyMs: (json['lastLatencyMs'] as num?)?.toInt(),
    );
  }
}

class EnvironmentReadiness {
  final bool ok;
  final bool redisSocketAdapter;
  final bool operationalReplay;
  final bool routeDiagnostics;
  final bool providerReady;

  const EnvironmentReadiness({
    required this.ok,
    required this.redisSocketAdapter,
    required this.operationalReplay,
    required this.routeDiagnostics,
    required this.providerReady,
  });

  factory EnvironmentReadiness.fromJson(Map<String, dynamic> json) {
    final features = _map(json['features']);
    final providers = _map(json['providers']);
    return EnvironmentReadiness(
      ok: json['ok'] == true,
      redisSocketAdapter: features['redisSocketAdapter'] == true,
      operationalReplay: features['operationalReplay'] == true,
      routeDiagnostics: features['routeDiagnostics'] == true,
      providerReady: providers['providerReady'] == true,
    );
  }
}

class ReplayReadiness {
  final bool timelineAvailable;
  final bool routeLifecycleReplay;
  final String offlineRecoveryVisibility;
  final bool rawGpsPlaybackStored;
  final String note;

  const ReplayReadiness({
    required this.timelineAvailable,
    required this.routeLifecycleReplay,
    required this.offlineRecoveryVisibility,
    required this.rawGpsPlaybackStored,
    required this.note,
  });

  factory ReplayReadiness.fromJson(Map<String, dynamic> json) {
    return ReplayReadiness(
      timelineAvailable: json['timelineAvailable'] == true,
      routeLifecycleReplay: json['routeLifecycleReplay'] == true,
      offlineRecoveryVisibility:
          json['offlineRecoveryVisibility']?.toString() ?? 'local',
      rawGpsPlaybackStored: json['rawGpsPlaybackStored'] == true,
      note: json['note']?.toString() ?? '',
    );
  }
}

class IncidentTimelineEvent {
  final String eventType;
  final String? routeId;
  final String? reason;
  final String severity;
  final DateTime occurredAt;

  const IncidentTimelineEvent({
    required this.eventType,
    required this.routeId,
    required this.reason,
    required this.severity,
    required this.occurredAt,
  });

  factory IncidentTimelineEvent.fromJson(Map<String, dynamic> json) {
    return IncidentTimelineEvent(
      eventType: json['eventType']?.toString() ?? 'event',
      routeId: json['routeId']?.toString(),
      reason: json['reason']?.toString(),
      severity: json['severity']?.toString() ?? 'info',
      occurredAt:
          DateTime.tryParse(json['occurredAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];

Map<String, int> _intMap(Map<String, dynamic> value) {
  return value.map((key, val) => MapEntry(key, (val as num?)?.toInt() ?? 0));
}

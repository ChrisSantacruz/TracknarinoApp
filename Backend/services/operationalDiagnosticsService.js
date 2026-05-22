const mongoose = require('mongoose');

const User = require('../models/User');
const OperationalRoute = require('../models/OperationalRoute');
const RouteAuditRecord = require('../models/RouteAuditRecord');
const RouteTelemetryEvent = require('../models/RouteTelemetryEvent');
const UbicacionActual = require('../models/UbicacionActual');
const { STALE_LOCATION_MS, OFFLINE_LOCATION_MS } = require('../config/trackingPolicy');
const { validateOperationalEnvironment } = require('../config/operationalConfig');
const { getProviderHealth } = require('./routingProviderPolicy');
const { getRealtimeDiagnostics } = require('./realtimeService');
const { getOperationalMetricsSnapshot } = require('./operationalMetricsService');

const MAX_WINDOW_HOURS = 168;
const DEFAULT_WINDOW_HOURS = 24;

function resolveUserScope(user) {
  const userId = user.id || user._id;
  const role = user.tipoUsuario || user.tipo;
  return { userId, role };
}

function windowStart(sinceHours) {
  const hours = Math.min(Number(sinceHours) || DEFAULT_WINDOW_HOURS, MAX_WINDOW_HOURS);
  return {
    hours,
    since: new Date(Date.now() - hours * 60 * 60 * 1000),
  };
}

function scopedMatch(user, since) {
  const { userId, role } = resolveUserScope(user);
  const match = { occurredAt: { $gte: since } };
  if (role === 'contratista') {
    match.contractorId = new mongoose.Types.ObjectId(userId);
  } else if (role === 'camionero') {
    match.camioneroId = new mongoose.Types.ObjectId(userId);
  }
  return match;
}

function countBy(items, key = '_id') {
  return items.reduce((result, item) => {
    result[item[key] || 'unknown'] = item.count;
    return result;
  }, {});
}

function severityFromCounts({ critical = 0, warning = 0 }) {
  if (critical > 0) return 'critical';
  if (warning > 0) return 'warning';
  return 'info';
}

async function resolveFleetFilter(user) {
  const { userId, role } = resolveUserScope(user);
  if (role === 'camionero') {
    return { camionero: userId };
  }

  const contractor = await User.findById(userId)
    .select('camionerosAfiliados')
    .lean();
  const camioneroIds = contractor?.camionerosAfiliados || [];
  return { camionero: { $in: camioneroIds } };
}

async function buildFleetHealth(user) {
  const now = Date.now();
  const fleetFilter = await resolveFleetFilter(user);
  const latestLocations = await UbicacionActual.find(fleetFilter)
    .select('camionero oportunidad serverReceivedAt timestamp source accuracy')
    .lean();

  const summary = {
    totalTracked: latestLocations.length,
    active: 0,
    stale: 0,
    offline: 0,
    offlineReplay: 0,
    poorAccuracy: 0,
  };

  for (const location of latestLocations) {
    const receivedAt = location.serverReceivedAt || location.timestamp;
    const ageMs = receivedAt ? now - new Date(receivedAt).getTime() : Number.POSITIVE_INFINITY;
    if (ageMs >= OFFLINE_LOCATION_MS) summary.offline += 1;
    else if (ageMs >= STALE_LOCATION_MS) summary.stale += 1;
    else summary.active += 1;
    if (location.source === 'offline_sync') summary.offlineReplay += 1;
    if (Number(location.accuracy) > 500) summary.poorAccuracy += 1;
  }

  return {
    ...summary,
    thresholds: {
      staleLocationMs: STALE_LOCATION_MS,
      offlineLocationMs: OFFLINE_LOCATION_MS,
    },
    severity: severityFromCounts({
      critical: summary.offline,
      warning: summary.stale + summary.poorAccuracy,
    }),
  };
}

async function buildRouteAnalytics(user, since) {
  const match = scopedMatch(user, since);
  const telemetryMatch = scopedMatch(user, since);

  const [
    auditCounts,
    telemetryCounts,
    rerouteCauses,
    invalidationHotspots,
    corridorIntersections,
    providerEvents,
    activeRoutes,
  ] = await Promise.all([
    RouteAuditRecord.aggregate([
      { $match: match },
      { $group: { _id: '$eventType', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]),
    RouteTelemetryEvent.aggregate([
      { $match: telemetryMatch },
      { $group: { _id: '$eventType', count: { $sum: 1 }, avgLatencyMs: { $avg: '$metrics.latencyMs' } } },
      { $sort: { count: -1 } },
    ]),
    RouteAuditRecord.aggregate([
      { $match: { ...match, eventType: { $in: ['reroute.requested', 'reroute.completed', 'route.replaced'] } } },
      { $group: { _id: { $ifNull: ['$reason', 'unclassified'] }, count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 },
    ]),
    RouteAuditRecord.aggregate([
      { $match: { ...match, eventType: { $in: ['route.invalidated', 'route.degraded', 'route.stale'] }, routeId: { $ne: null } } },
      { $group: { _id: { routeId: '$routeId', reason: { $ifNull: ['$reason', 'unclassified'] } }, count: { $sum: 1 }, lastSeenAt: { $max: '$occurredAt' } } },
      { $sort: { count: -1, lastSeenAt: -1 } },
      { $limit: 12 },
    ]),
    RouteAuditRecord.aggregate([
      { $match: { ...match, eventType: 'corridor.alert_intersection' } },
      { $group: { _id: '$routeId', count: { $sum: 1 }, lastSeenAt: { $max: '$occurredAt' } } },
      { $sort: { count: -1 } },
      { $limit: 12 },
    ]),
    RouteTelemetryEvent.aggregate([
      { $match: { ...telemetryMatch, eventType: { $in: ['provider.latency', 'provider.failure'] } } },
      {
        $group: {
          _id: { provider: { $ifNull: ['$provider', 'unknown'] }, eventType: '$eventType' },
          count: { $sum: 1 },
          avgLatencyMs: { $avg: '$metrics.latencyMs' },
        },
      },
      { $sort: { '_id.provider': 1 } },
    ]),
    OperationalRoute.countDocuments(
      resolveUserScope(user).role === 'contratista'
        ? { contractorId: resolveUserScope(user).userId, state: 'active' }
        : { camioneroId: resolveUserScope(user).userId, state: 'active' },
    ),
  ]);

  const audit = countBy(auditCounts);
  const telemetry = countBy(telemetryCounts);
  const providerSummary = providerEvents.reduce((acc, item) => {
    const provider = item._id.provider;
    acc[provider] = acc[provider] || { provider, latencySamples: 0, failures: 0, avgLatencyMs: null };
    if (item._id.eventType === 'provider.failure') acc[provider].failures = item.count;
    if (item._id.eventType === 'provider.latency') {
      acc[provider].latencySamples = item.count;
      acc[provider].avgLatencyMs = item.avgLatencyMs;
    }
    return acc;
  }, {});

  return {
    activeRoutes,
    counts: {
      rerouteFrequency:
        (audit['reroute.requested'] || 0) +
        (audit['reroute.completed'] || 0) +
        (audit['route.replaced'] || 0),
      routeInvalidations: audit['route.invalidated'] || 0,
      degradedRoutes: audit['route.degraded'] || 0,
      staleRoutes: audit['route.stale'] || 0,
      corridorAlertIntersections: audit['corridor.alert_intersection'] || 0,
      providerFailures: telemetry['provider.failure'] || 0,
    },
    auditCounts,
    telemetryCounts,
    rerouteCauses: rerouteCauses.map((item) => ({ reason: item._id, count: item.count })),
    invalidationHotspots: invalidationHotspots.map((item) => ({
      routeId: item._id.routeId,
      reason: item._id.reason,
      count: item.count,
      lastSeenAt: item.lastSeenAt,
    })),
    corridorAlertDensity: corridorIntersections.map((item) => ({
      routeId: item._id || 'unassigned',
      count: item.count,
      lastSeenAt: item.lastSeenAt,
    })),
    providerReliability: Object.values(providerSummary).map((provider) => ({
      ...provider,
      failureRate:
        provider.failures + provider.latencySamples > 0
          ? provider.failures / (provider.failures + provider.latencySamples)
          : 0,
    })),
    operationalPressure: {
      reroutePressure:
        (audit['reroute.requested'] || 0) +
        (audit['reroute.completed'] || 0) +
        (telemetry['reroute.request'] || 0),
      routeReplacementPressure:
        (audit['route.replaced'] || 0) +
        (telemetry['route.replacement'] || 0),
      degradedRouteFrequency:
        (audit['route.degraded'] || 0) +
        (audit['route.stale'] || 0) +
        (telemetry['route.degradation'] || 0) +
        (telemetry['route.stale'] || 0),
      corridorInstability:
        (audit['corridor.alert_intersection'] || 0) +
        (telemetry['corridor.alert_intersection'] || 0),
    },
  };
}

async function buildIncidentTimeline(user, since, limit = 30) {
  const match = scopedMatch(user, since);
  const safeLimit = Math.min(Number(limit) || 30, 100);
  const events = await RouteAuditRecord.find(match)
    .sort({ occurredAt: -1 })
    .limit(safeLimit)
    .select('routeId tripId eventType reason severity correlationId occurredAt metadata')
    .lean();

  return events.map((event) => ({
    routeId: event.routeId,
    tripId: event.tripId,
    eventType: event.eventType,
    reason: event.reason,
    severity: event.severity,
    correlationId: event.correlationId,
    occurredAt: event.occurredAt,
    metadata: {
      routeVersion: event.metadata?.routeVersion,
      previousRouteId: event.metadata?.previousRouteId,
      metrics: event.metadata?.metrics,
    },
  }));
}

async function getOperationalDiagnostics({ user, sinceHours, limit }) {
  const { hours, since } = windowStart(sinceHours);
  const [fleetHealth, routeAnalytics, timeline] = await Promise.all([
    buildFleetHealth(user),
    buildRouteAnalytics(user, since),
    buildIncidentTimeline(user, since, limit),
  ]);

  const realtime = getRealtimeDiagnostics();
  const provider = getProviderHealth(process.env.ROUTING_PROVIDER || 'public_osrm');
  const environment = validateOperationalEnvironment();
  const metrics = getOperationalMetricsSnapshot();
  const criticalSignals =
    routeAnalytics.counts.providerFailures +
    routeAnalytics.counts.routeInvalidations +
    (realtime.reconnectStorm.state === 'degraded' ? 1 : 0);

  return {
    generatedAt: new Date().toISOString(),
    window: {
      since: since.toISOString(),
      hours,
    },
    severity: severityFromCounts({
      critical: criticalSignals,
      warning: routeAnalytics.counts.degradedRoutes + routeAnalytics.counts.staleRoutes + fleetHealth.stale,
    }),
    fleetHealth,
    routeAnalytics,
    realtimeHealth: realtime,
    providerHealth: provider,
    operationalMetrics: metrics,
    environmentReadiness: {
      ok: environment.ok,
      environment: environment.environment,
      features: environment.features,
      providers: environment.providers,
      realtime: environment.realtime,
    },
    replayReadiness: {
      timelineAvailable: true,
      routeLifecycleReplay: true,
      offlineRecoveryVisibility: 'mobile_local_queue',
      rawGpsPlaybackStored: false,
      note: 'La línea de incidente usa audit/telemetry reales y evita duplicar historial GPS crudo.',
    },
    timeline,
  };
}

module.exports = {
  getOperationalDiagnostics,
};

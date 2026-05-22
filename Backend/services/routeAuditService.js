const RouteAuditRecord = require('../models/RouteAuditRecord');
const operationalLogger = require('../utils/operationalLogger');
const { recordRouteTelemetry } = require('./routeTelemetryService');

const SENSITIVE_METADATA_KEYS = ['coordinates', 'geometry', 'encodedPolyline', 'token', 'authorization'];
const AUDIT_TO_TELEMETRY_EVENT = Object.freeze({
  'route.replaced': 'route.replacement',
  'route.invalidated': 'route.invalidation',
  'route.degraded': 'route.degradation',
  'route.stale': 'route.stale',
  'reroute.requested': 'reroute.request',
  'provider.failure': 'provider.failure',
  'corridor.alert_intersection': 'corridor.alert_intersection',
});

function sanitizeAuditMetadata(metadata = {}) {
  return Object.entries(metadata).reduce((safe, [key, value]) => {
    const lowerKey = key.toLowerCase();
    if (SENSITIVE_METADATA_KEYS.some((sensitiveKey) => lowerKey.includes(sensitiveKey))) {
      safe[key] = '[redacted]';
    } else if (Array.isArray(value)) {
      safe[key] = value.slice(0, 25);
    } else if (value && typeof value === 'object') {
      safe[key] = sanitizeAuditMetadata(value);
    } else {
      safe[key] = value;
    }
    return safe;
  }, {});
}

async function createRouteAuditRecord({
  routeId,
  tripId,
  camioneroId,
  contractorId,
  eventType,
  reason,
  severity = 'info',
  metadata = {},
  correlationId,
  clientEventId,
  occurredAt,
}) {
  const payload = {
    routeId,
    tripId,
    camioneroId,
    contractorId,
    eventType,
    reason,
    severity,
    metadata: sanitizeAuditMetadata(metadata),
    correlationId,
    clientEventId,
    occurredAt: occurredAt || new Date(),
  };

  try {
    const audit = await RouteAuditRecord.create(payload);
    operationalLogger.info('routing', eventType.replaceAll('.', '_'), {
      routeId,
      tripId: tripId?.toString?.() || tripId,
      contractorId: contractorId?.toString?.() || contractorId,
      severity,
      reason,
      correlationId,
    });

    const telemetryEvent = AUDIT_TO_TELEMETRY_EVENT[eventType];
    if (telemetryEvent) {
      await recordRouteTelemetry(telemetryEvent, {
        routeId,
        tripId,
        camioneroId,
        contractorId,
        reason,
        correlationId,
        metrics: metadata.metrics,
      });
    }

    return audit;
  } catch (error) {
    if (error?.code === 11000 && clientEventId) {
      return RouteAuditRecord.findOne({ tripId, clientEventId, eventType });
    }
    throw error;
  }
}

module.exports = {
  sanitizeAuditMetadata,
  createRouteAuditRecord,
};

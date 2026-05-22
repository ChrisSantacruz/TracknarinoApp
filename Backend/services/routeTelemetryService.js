const RouteTelemetryEvent = require('../models/RouteTelemetryEvent.js');
const operationalLogger = require('../utils/operationalLogger');

async function recordRouteTelemetry(eventType, fields = {}) {
  const telemetry = {
    eventType,
    routeId: fields.routeId,
    tripId: fields.tripId,
    camioneroId: fields.camioneroId,
    contractorId: fields.contractorId,
    provider: fields.provider,
    metrics: fields.metrics || {},
    reason: fields.reason,
    correlationId: fields.correlationId,
    occurredAt: fields.occurredAt || new Date(),
  };

  operationalLogger.info('routing', eventType.replaceAll('.', '_'), {
    routeId: telemetry.routeId,
    tripId: telemetry.tripId?.toString?.() || telemetry.tripId,
    provider: telemetry.provider,
    reason: telemetry.reason,
    correlationId: telemetry.correlationId,
    metrics: telemetry.metrics,
  });

  try {
    return await RouteTelemetryEvent.create(telemetry);
  } catch (error) {
    operationalLogger.warning('routing', 'telemetry_persist_failed', {
      eventType,
      error: error.message,
    });
    return null;
  }
}

module.exports = {
  recordRouteTelemetry,
};

const { emitRouteStateChanged, emitRouteAuditEvent } = require('./realtimeService');

function buildRouteStatePayload(route, type = 'route.state.changed') {
  const routeId = route.routeId;
  const oportunidadId = route.tripId?.toString?.() || route.tripId;
  const camioneroId = route.camioneroId?.toString?.() || route.camioneroId;
  const contratistaId = route.contractorId?.toString?.() || route.contractorId;

  return {
    version: 1,
    eventId: `${type}:${routeId}:${route.routeVersion}:${new Date().toISOString()}`,
    type,
    routeId,
    oportunidadId,
    camioneroId,
    contratistaId,
    geometryHash: route.geometryHash,
    provider: route.provider,
    routeVersion: route.routeVersion,
    state: route.state,
    rerouteReason: route.rerouteReason || null,
    emittedAt: new Date().toISOString(),
  };
}

function buildRouteAuditPayload(audit) {
  const routeId = audit.routeId;
  const oportunidadId = audit.tripId?.toString?.() || audit.tripId;
  const camioneroId = audit.camioneroId?.toString?.() || audit.camioneroId;
  const contratistaId = audit.contractorId?.toString?.() || audit.contractorId;

  return {
    version: 1,
    eventId: `route.audit:${audit._id?.toString?.() || Date.now()}`,
    type: audit.eventType,
    routeId,
    oportunidadId,
    camioneroId,
    contratistaId,
    reason: audit.reason || null,
    severity: audit.severity,
    occurredAt: new Date(audit.occurredAt || audit.createdAt || Date.now()).toISOString(),
    emittedAt: new Date().toISOString(),
  };
}

async function publishRouteStateChanged(route, type) {
  const payload = buildRouteStatePayload(route, type);
  emitRouteStateChanged(payload, {
    contratistaId: payload.contratistaId,
    camioneroId: payload.camioneroId,
    oportunidadId: payload.oportunidadId,
    routeId: payload.routeId,
  });
  return payload;
}

async function publishRouteAuditEvent(audit) {
  const payload = buildRouteAuditPayload(audit);
  emitRouteAuditEvent(payload, {
    contratistaId: payload.contratistaId,
    camioneroId: payload.camioneroId,
    oportunidadId: payload.oportunidadId,
    routeId: payload.routeId,
  });
  return payload;
}

module.exports = {
  buildRouteStatePayload,
  buildRouteAuditPayload,
  publishRouteStateChanged,
  publishRouteAuditEvent,
};

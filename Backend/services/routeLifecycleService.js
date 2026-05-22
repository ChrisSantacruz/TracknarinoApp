const crypto = require('crypto');
const mongoose = require('mongoose');

const Oportunidad = require('../models/Oportunidad');
const OperationalRoute = require('../models/OperationalRoute');
const RouteAuditRecord = require('../models/RouteAuditRecord');
const RouteTelemetryEvent = require('../models/RouteTelemetryEvent');
const { getOrCreateRouteGeometry, decodeRoutePolyline } = require('./routeGeometryService');
const { createRouteAuditRecord } = require('./routeAuditService');
const { publishRouteStateChanged, publishRouteAuditEvent } = require('./routeEventService');
const { recordRouteTelemetry } = require('./routeTelemetryService');
const operationalLogger = require('../utils/operationalLogger');

function buildRouteId(tripId, routeVersion, geometryHash) {
  const suffix = crypto
    .createHash('sha1')
    .update(`${tripId}:${routeVersion}:${geometryHash}:${Date.now()}`)
    .digest('hex')
    .slice(0, 10);
  return `route_${tripId}_${routeVersion}_${suffix}`;
}

function assertObjectId(value, fieldName) {
  if (!mongoose.Types.ObjectId.isValid(value)) {
    const error = new Error(`${fieldName} inválido`);
    error.statusCode = 400;
    throw error;
  }
}

async function resolveRouteTripForUser({ tripId, user }) {
  assertObjectId(tripId, 'tripId');

  const trip = await Oportunidad.findById(tripId)
    .select('contratista camioneroAsignado estado origin destination')
    .lean();

  if (!trip) {
    const error = new Error('Viaje no encontrado');
    error.statusCode = 404;
    throw error;
  }

  const userId = user.id || user._id;
  const role = user.tipoUsuario || user.tipo;
  const contractorId = trip.contratista?.toString?.();
  const camioneroId = trip.camioneroAsignado?.toString?.();

  if (role === 'contratista' && contractorId !== userId) {
    const error = new Error('No tienes permisos para administrar rutas de este viaje');
    error.statusCode = 403;
    throw error;
  }

  if (role === 'camionero' && camioneroId !== userId) {
    const error = new Error('No tienes permisos para registrar rutas de este viaje');
    error.statusCode = 403;
    throw error;
  }

  if (!camioneroId) {
    const error = new Error('El viaje no tiene camionero asignado para persistir ruta operacional');
    error.statusCode = 409;
    throw error;
  }

  return { trip, contractorId, camioneroId };
}

function serializeRoute(routeDoc, geometryDoc = null, { includeGeometry = false } = {}) {
  const route = routeDoc.toJSON ? routeDoc.toJSON() : routeDoc;
  const geometry = geometryDoc || route.geometry;

  const serialized = {
    routeId: route.routeId,
    tripId: route.tripId,
    camioneroId: route.camioneroId,
    contractorId: route.contractorId,
    geometryHash: route.geometryHash,
    provider: route.provider,
    routeVersion: route.routeVersion,
    state: route.state,
    rerouteReason: route.rerouteReason,
    parentRouteId: route.parentRouteId,
    replacedByRouteId: route.replacedByRouteId,
    summary: route.summary,
    diagnostics: route.diagnostics,
    createdAt: route.createdAt,
    replacedAt: route.replacedAt,
    updatedAt: route.updatedAt,
  };

  if (includeGeometry && geometry?.encodedPolyline) {
    serialized.geometry = {
      coordinates: decodeRoutePolyline(geometry.encodedPolyline),
      compression: geometry.compression,
      pointCount: geometry.pointCount,
      bbox: geometry.bbox,
    };
  }

  return serialized;
}

async function persistOperationalRoute({ user, body }) {
  const {
    tripId,
    coordinates,
    provider = 'public_osrm',
    rerouteReason,
    clientEventId,
    parentRouteId,
    summary = {},
    diagnostics = {},
    correlationId,
  } = body;

  const { contractorId, camioneroId } = await resolveRouteTripForUser({ tripId, user });
  if (!OperationalRoute.ROUTE_PROVIDERS.includes(provider)) {
    const error = new Error('provider de ruta no soportado');
    error.statusCode = 400;
    throw error;
  }

  if (clientEventId) {
    const existing = await OperationalRoute.findOne({ tripId, clientEventId }).populate('geometry');
    if (existing) {
      return { route: serializeRoute(existing, existing.geometry), duplicate: true };
    }
  }

  const { geometry, geometryHash, deduplicated } = await getOrCreateRouteGeometry({
    coordinates,
    provider,
  });

  const activeRoute = await OperationalRoute.findOne({ tripId, state: 'active' })
    .sort({ routeVersion: -1 });
  const routeVersion = activeRoute ? activeRoute.routeVersion + 1 : 1;
  const routeId = buildRouteId(tripId, routeVersion, geometryHash);
  const createdAt = new Date();

  if (activeRoute) {
    await OperationalRoute.updateOne(
      { _id: activeRoute._id },
      {
        $set: {
          state: 'inactive',
          replacedAt: createdAt,
          replacedByRouteId: routeId,
        },
      },
    );
  }

  const route = await OperationalRoute.create({
    routeId,
    tripId,
    camioneroId,
    contractorId,
    geometryHash,
    geometry: geometry._id,
    provider,
    routeVersion,
    state: 'active',
    rerouteReason,
    parentRouteId: parentRouteId || activeRoute?.routeId,
    clientEventId,
    summary: {
      distanceKm: summary.distanceKm,
      durationMinutes: summary.durationMinutes,
      pointCount: geometry.pointCount,
      bbox: geometry.bbox,
    },
    diagnostics: {
      providerLatencyMs: diagnostics.providerLatencyMs,
      correlationId,
    },
    createdAt,
  });

  const audit = await createRouteAuditRecord({
    routeId,
    tripId,
    camioneroId,
    contractorId,
    eventType: activeRoute ? 'route.replaced' : 'route.created',
    reason: rerouteReason,
    metadata: {
      previousRouteId: activeRoute?.routeId,
      routeVersion,
      geometryHash,
      geometryDeduplicated: deduplicated,
      metrics: {
        routeVersion,
      },
    },
    correlationId,
    clientEventId,
  });

  await publishRouteStateChanged(route, activeRoute ? 'route.replaced' : 'route.created');
  await publishRouteAuditEvent(audit);

  await recordRouteTelemetry('route.replacement', {
    routeId,
    tripId,
    camioneroId,
    contractorId,
    provider,
    reason: rerouteReason,
    metrics: {
      routeVersion,
    },
    correlationId,
  });

  operationalLogger.info('routing', 'route_persisted', {
    routeId,
    tripId,
    routeVersion,
    geometryDeduplicated: deduplicated,
    correlationId,
  });

  return { route: serializeRoute(route, geometry), duplicate: false };
}

async function getActiveOperationalRoute({ tripId, user, includeGeometry = false }) {
  await resolveRouteTripForUser({ tripId, user });

  const activeRoute = await OperationalRoute.findOne({ tripId, state: 'active' })
    .populate('geometry');

  if (!activeRoute) {
    const error = new Error('No hay ruta activa persistida para este viaje');
    error.statusCode = 404;
    throw error;
  }

  return serializeRoute(activeRoute, activeRoute.geometry, { includeGeometry });
}

async function getRouteHistory({ tripId, user, limit = 25 }) {
  await resolveRouteTripForUser({ tripId, user });
  const safeLimit = Math.min(Number(limit) || 25, 100);

  const routes = await OperationalRoute.find({ tripId })
    .sort({ routeVersion: -1 })
    .limit(safeLimit)
    .populate('geometry');

  return routes.map((route) => serializeRoute(route, route.geometry));
}

async function recordRouteLifecycleEvent({ user, body }) {
  const {
    tripId,
    routeId,
    eventType,
    reason,
    severity,
    metadata,
    clientEventId,
    correlationId,
  } = body;

  const { contractorId, camioneroId } = await resolveRouteTripForUser({ tripId, user });
  let route = null;
  if (routeId) {
    route = await OperationalRoute.findOne({ routeId, tripId });
    if (!route) {
      const error = new Error('Ruta operacional no encontrada para este viaje');
      error.statusCode = 404;
      throw error;
    }
  }

  const audit = await createRouteAuditRecord({
    routeId,
    tripId,
    camioneroId,
    contractorId,
    eventType,
    reason,
    severity,
    metadata,
    correlationId,
    clientEventId,
  });

  if (eventType === 'route.invalidated' && route?.state === 'active') {
    route.state = 'inactive';
    route.replacedAt = new Date();
    await route.save();
    await publishRouteStateChanged(route, 'route.invalidated');
  }

  await publishRouteAuditEvent(audit);

  return audit;
}

async function getRouteDiagnostics({ user, sinceHours = 24 }) {
  const userId = user.id || user._id;
  const role = user.tipoUsuario || user.tipo;
  const since = new Date(Date.now() - Math.min(Number(sinceHours) || 24, 168) * 60 * 60 * 1000);
  const match = { occurredAt: { $gte: since } };

  if (role === 'contratista') {
    match.contractorId = new mongoose.Types.ObjectId(userId);
  } else if (role === 'camionero') {
    match.camioneroId = new mongoose.Types.ObjectId(userId);
  }

  const [auditCounts, telemetryCounts, activeRouteCount] = await Promise.all([
    RouteAuditRecord.aggregate([
      { $match: match },
      { $group: { _id: '$eventType', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]),
    RouteTelemetryEvent.aggregate([
      { $match: match },
      { $group: { _id: '$eventType', count: { $sum: 1 }, avgLatencyMs: { $avg: '$metrics.latencyMs' } } },
      { $sort: { count: -1 } },
    ]),
    OperationalRoute.countDocuments(role === 'contratista'
      ? { contractorId: userId, state: 'active' }
      : { camioneroId: userId, state: 'active' }),
  ]);

  return {
    since: since.toISOString(),
    activeRouteCount,
    auditCounts,
    telemetryCounts,
    retention: {
      auditTtlEnabled: false,
      telemetryTtlEnabled: false,
    },
  };
}

module.exports = {
  persistOperationalRoute,
  getActiveOperationalRoute,
  getRouteHistory,
  recordRouteLifecycleEvent,
  getRouteDiagnostics,
  resolveRouteTripForUser,
};

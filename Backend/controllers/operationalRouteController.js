const RouteAuditRecord = require('../models/RouteAuditRecord');
const OperationalRoute = require('../models/OperationalRoute');
const asyncHandler = require('../middleware/asyncHandler');
const { sendError } = require('../middleware/errorMiddleware');
const {
  persistOperationalRoute,
  getActiveOperationalRoute,
  getRouteHistory,
  recordRouteLifecycleEvent,
  getRouteDiagnostics,
  resolveRouteTripForUser,
} = require('../services/routeLifecycleService');
const { getProviderHealth } = require('../services/routingProviderPolicy');

const persistRoute = asyncHandler(async (req, res) => {
  if (!req.body?.tripId || !Array.isArray(req.body?.coordinates)) {
    return sendError(res, 400, 'tripId y coordinates son obligatorios', 'VALIDATION_ERROR');
  }

  const result = await persistOperationalRoute({
    user: req.usuario,
    body: req.body,
  });

  return res.status(result.duplicate ? 200 : 201).json({
    success: true,
    duplicate: result.duplicate,
    route: result.route,
  });
});

const getActiveRoute = asyncHandler(async (req, res) => {
  const route = await getActiveOperationalRoute({
    tripId: req.params.tripId,
    user: req.usuario,
    includeGeometry: req.query.includeGeometry === 'true',
  });

  return res.json({ success: true, route });
});

const getHistory = asyncHandler(async (req, res) => {
  const routes = await getRouteHistory({
    tripId: req.params.tripId,
    user: req.usuario,
    limit: req.query.limit,
  });

  return res.json({ success: true, routes });
});

const recordAudit = asyncHandler(async (req, res) => {
  const allowedEvents = RouteAuditRecord.ROUTE_AUDIT_EVENTS || [];
  if (!req.body?.tripId || !allowedEvents.includes(req.body?.eventType)) {
    return sendError(res, 400, 'tripId y eventType válido son obligatorios', 'VALIDATION_ERROR');
  }

  const audit = await recordRouteLifecycleEvent({
    user: req.usuario,
    body: req.body,
  });

  return res.status(201).json({ success: true, audit });
});

const getRouteAudit = asyncHandler(async (req, res) => {
  const routeId = req.params.routeId;
  const limit = Math.min(Number(req.query.limit) || 50, 100);
  const route = await OperationalRoute.findOne({ routeId }).select('tripId').lean();

  if (!route) {
    return sendError(res, 404, 'Ruta operacional no encontrada', 'NOT_FOUND');
  }

  await resolveRouteTripForUser({ tripId: route.tripId, user: req.usuario });

  const audit = await RouteAuditRecord.find({ routeId })
    .sort({ occurredAt: -1 })
    .limit(limit);

  return res.json({ success: true, audit });
});

const getDiagnostics = asyncHandler(async (req, res) => {
  const diagnostics = await getRouteDiagnostics({
    user: req.usuario,
    sinceHours: req.query.sinceHours,
  });

  return res.json({ success: true, diagnostics });
});

const getProviderDiagnostics = asyncHandler(async (req, res) => {
  return res.json({
    success: true,
    provider: getProviderHealth(process.env.ROUTING_PROVIDER || 'public_osrm'),
  });
});

module.exports = {
  persistRoute,
  getActiveRoute,
  getHistory,
  recordAudit,
  getRouteAudit,
  getDiagnostics,
  getProviderDiagnostics,
};

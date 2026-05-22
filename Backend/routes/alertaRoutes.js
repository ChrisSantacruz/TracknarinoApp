const express = require('express');
const router = express.Router();
const AlertaSeguridad = require('../models/AlertaSeguridad');
const verificarToken = require('../middleware/authMiddleware');
const asyncHandler = require('../middleware/asyncHandler');
const { sendError } = require('../middleware/errorMiddleware');
const { requireFields } = require('../middleware/validateRequest');
const { normalizeLatLngInput } = require('../utils/geoValidation');
const { publishAlertCreated } = require('../services/alertEventService');
const OperationalRoute = require('../models/OperationalRoute');
const { parseBboxQuery, queryCorridorAlerts } = require('../services/routeGeospatialService');
const { resolveRouteTripForUser } = require('../services/routeLifecycleService');

// Crear una alerta
const crearAlertaHandler = asyncHandler(async (req, res) => {
  const { tipo, descripcion, coords, clientEventId, timestamp } = req.body;
  const normalizedCoordinates = normalizeLatLngInput(coords);

  if (!normalizedCoordinates) {
    return sendError(res, 400, 'Coordenadas de alerta inválidas', 'VALIDATION_ERROR');
  }

  let alerta;
  try {
    alerta = new AlertaSeguridad({
      tipo,
      descripcion,
      coords: { lat: normalizedCoordinates.lat, lng: normalizedCoordinates.lng },
      coordinates: normalizedCoordinates.coordinates,
      usuario: req.usuario.id,
      timestamp: timestamp ? new Date(timestamp) : new Date(),
      clientEventId,
      geoMigration: {
        status: 'resolved',
        source: 'api',
        routable: true,
        missingFields: [],
        reviewedAt: new Date(),
      },
    });

    await alerta.save();
  } catch (error) {
    if (error?.code === 11000 && clientEventId) {
      alerta = await AlertaSeguridad.findOne({
        usuario: req.usuario.id,
        clientEventId,
      });
      return res.json({
        mensaje: 'Alerta ya sincronizada',
        alerta,
        duplicate: true,
      });
    }
    throw error;
  }
  await publishAlertCreated(alerta);

  res.status(201).json({ mensaje: 'Alerta registrada con éxito', alerta });
});

const listarAlertasHandler = asyncHandler(async (req, res) => {
  const alertas = await AlertaSeguridad.find()
    .sort({ createdAt: -1 })
    .limit(50)
    .populate('usuario', 'nombre tipoUsuario');

  res.json(alertas);
});

// Rutas para crear alertas (ambas apuntan al mismo handler)
router.post('/crear', verificarToken, requireFields(['tipo', 'coords']), crearAlertaHandler);
router.post('/', verificarToken, requireFields(['tipo', 'coords']), crearAlertaHandler);

// Listar alertas recientes (máx 50)
router.get('/listar', verificarToken, listarAlertasHandler);
router.get('/recientes', verificarToken, listarAlertasHandler);

router.get('/corredor', verificarToken, asyncHandler(async (req, res) => {
  const routeId = typeof req.query.routeId === 'string' ? req.query.routeId.trim() : null;
  const bbox = parseBboxQuery(req.query);
  const severities = typeof req.query.severity === 'string'
    ? req.query.severity.split(',').map((value) => value.trim()).filter(Boolean)
    : [];

  if (!routeId && !bbox) {
    return sendError(res, 400, 'routeId o bbox son obligatorios para consultar alertas de corredor', 'VALIDATION_ERROR');
  }

  if (routeId) {
    const route = await OperationalRoute.findOne({ routeId }).select('tripId').lean();
    if (!route) {
      return sendError(res, 404, 'Ruta operacional no encontrada', 'NOT_FOUND');
    }
    await resolveRouteTripForUser({ tripId: route.tripId, user: req.usuario });
  }

  const result = await queryCorridorAlerts({
    bbox,
    routeId,
    severities,
    limit: req.query.limit,
    recentHours: req.query.recentHours,
    maxRouteDistanceMeters: req.query.maxRouteDistanceMeters,
  });

  res.json({
    success: true,
    ...result,
  });
}));

// Listar alertas cercanas a una ubicación (lat, lng, radio en metros)
router.post('/cercanas', verificarToken, asyncHandler(async (req, res) => {
  const { lat, lng, radio } = req.body;

  const latNumber = Number(lat);
  const lngNumber = Number(lng);

  if (!Number.isFinite(latNumber) || !Number.isFinite(lngNumber)
    || latNumber < -90 || latNumber > 90 || lngNumber < -180 || lngNumber > 180) {
    return sendError(res, 400, 'Latitud y longitud son obligatorios', 'VALIDATION_ERROR');
  }

  const rangoMetros = Number.isFinite(Number(radio)) ? Number(radio) : 50000; // 50km por defecto

  const cercanas = await AlertaSeguridad.find({
    coordinates: {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: [lngNumber, latNumber],
        },
        $maxDistance: rangoMetros,
      },
    },
  })
    .limit(100)
    .populate('usuario', 'nombre tipoUsuario');

  res.json(cercanas);
}));

module.exports = router;

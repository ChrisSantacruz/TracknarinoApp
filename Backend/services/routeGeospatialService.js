const AlertaSeguridad = require('../models/AlertaSeguridad');
const OperationalRoute = require('../models/OperationalRoute');
const { decodeRoutePolyline } = require('./routeGeometryService');
const { haversineDistanceKm, isValidCoordinatePair } = require('../utils/geoValidation');

const ALERT_SEVERITY = Object.freeze({
  robo: 'critical',
  intento_robo: 'critical',
  accidente: 'critical',
  obstaculo: 'warning',
  clima: 'warning',
  trancon: 'warning',
  sospecha: 'warning',
  policia: 'info',
  otro: 'info',
});

function parseBboxQuery(query = {}) {
  const minLng = Number(query.minLng ?? query.west);
  const minLat = Number(query.minLat ?? query.south);
  const maxLng = Number(query.maxLng ?? query.east);
  const maxLat = Number(query.maxLat ?? query.north);

  if (![minLng, minLat, maxLng, maxLat].every(Number.isFinite)) return null;
  if (minLng < -180 || maxLng > 180 || minLat < -90 || maxLat > 90) return null;
  if (minLng >= maxLng || minLat >= maxLat) return null;

  return { minLng, minLat, maxLng, maxLat };
}

function bboxMongoFilter(bbox) {
  return {
    coordinates: {
      $geoWithin: {
        $geometry: {
          type: 'Polygon',
          coordinates: [[
            [bbox.minLng, bbox.minLat],
            [bbox.maxLng, bbox.minLat],
            [bbox.maxLng, bbox.maxLat],
            [bbox.minLng, bbox.maxLat],
            [bbox.minLng, bbox.minLat],
          ]],
        },
      },
    },
  };
}

function expandBbox(bbox, bufferDegrees = 0.02) {
  return {
    minLng: Math.max(-180, bbox.minLng - bufferDegrees),
    minLat: Math.max(-90, bbox.minLat - bufferDegrees),
    maxLng: Math.min(180, bbox.maxLng + bufferDegrees),
    maxLat: Math.min(90, bbox.maxLat + bufferDegrees),
  };
}

function pointInBbox(coordinates, bbox) {
  if (!isValidCoordinatePair(coordinates)) return false;
  const [lng, lat] = coordinates;
  return lng >= bbox.minLng && lng <= bbox.maxLng && lat >= bbox.minLat && lat <= bbox.maxLat;
}

function severityRank(severity) {
  if (severity === 'critical') return 3;
  if (severity === 'warning') return 2;
  return 1;
}

function minDistanceToRouteMeters(alertCoordinates, routeCoordinates, maxRoutePoints = 80) {
  if (!isValidCoordinatePair(alertCoordinates) || !Array.isArray(routeCoordinates) || routeCoordinates.length === 0) {
    return Infinity;
  }

  const step = Math.max(1, Math.ceil(routeCoordinates.length / maxRoutePoints));
  const alertPoint = { lng: alertCoordinates[0], lat: alertCoordinates[1] };
  let bestDistanceMeters = Infinity;

  for (let index = 0; index < routeCoordinates.length; index += step) {
    const [lng, lat] = routeCoordinates[index];
    const distanceMeters = haversineDistanceKm(alertPoint, { lng, lat }) * 1000;
    if (distanceMeters < bestDistanceMeters) bestDistanceMeters = distanceMeters;
  }

  return bestDistanceMeters;
}

function serializeOperationalAlert(alert, routeDistanceMeters = null) {
  const severity = ALERT_SEVERITY[alert.tipo] || 'info';
  return {
    id: alert._id,
    tipo: alert.tipo,
    descripcion: alert.descripcion,
    coords: alert.coords,
    coordinates: alert.coordinates,
    timestamp: alert.timestamp,
    createdAt: alert.createdAt,
    severity,
    routeDistanceMeters,
  };
}

async function queryCorridorAlerts({
  bbox,
  routeId,
  severities = [],
  limit = 100,
  recentHours = 24,
  maxRouteDistanceMeters = 1000,
}) {
  const safeLimit = Math.min(Number(limit) || 100, 200);
  const safeRecentHours = Math.min(Number(recentHours) || 24, 168);
  const safeMaxRouteDistanceMeters = Math.min(Number(maxRouteDistanceMeters) || 1000, 10000);
  const since = new Date(Date.now() - safeRecentHours * 60 * 60 * 1000);
  const query = {
    timestamp: { $gte: since },
    coordinates: { $exists: true },
  };

  let routeCoordinates = null;
  let effectiveBbox = bbox;

  if (routeId) {
    const route = await OperationalRoute.findOne({ routeId }).populate('geometry');
    if (route?.geometry?.encodedPolyline) {
      routeCoordinates = decodeRoutePolyline(route.geometry.encodedPolyline);
      effectiveBbox = expandBbox(route.summary?.bbox || route.geometry.bbox);
    }
  }

  if (effectiveBbox) {
    Object.assign(query, bboxMongoFilter(effectiveBbox));
  }

  const rawAlerts = await AlertaSeguridad.find(query)
    .sort({ timestamp: -1 })
    .limit(safeLimit * 2)
    .populate('usuario', 'nombre tipoUsuario')
    .lean();

  const filtered = rawAlerts
    .map((alert) => {
      const routeDistanceMeters = routeCoordinates
        ? minDistanceToRouteMeters(alert.coordinates, routeCoordinates)
        : null;
      return serializeOperationalAlert(alert, routeDistanceMeters);
    })
    .filter((alert) => {
      if (severities.length > 0 && !severities.includes(alert.severity)) return false;
      if (routeCoordinates && alert.routeDistanceMeters > safeMaxRouteDistanceMeters) return false;
      return true;
    })
    .sort((a, b) => {
      const severityDiff = severityRank(b.severity) - severityRank(a.severity);
      if (severityDiff !== 0) return severityDiff;
      return new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime();
    })
    .slice(0, safeLimit);

  return {
    alerts: filtered,
    query: {
      bbox: effectiveBbox,
      routeId: routeId || null,
      recentHours: safeRecentHours,
      maxRouteDistanceMeters: routeCoordinates ? safeMaxRouteDistanceMeters : null,
    },
  };
}

module.exports = {
  ALERT_SEVERITY,
  parseBboxQuery,
  bboxMongoFilter,
  pointInBbox,
  queryCorridorAlerts,
};

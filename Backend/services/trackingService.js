const mongoose = require('mongoose');
const Ubicacion = require('../models/Ubicacion');
const UbicacionActual = require('../models/UbicacionActual');
const Oportunidad = require('../models/Oportunidad');
const {
  normalizeNumber,
  normalizeLatLngInput,
  parseTimestamp,
  isDuplicateCoordinatePair,
  MAX_ACCEPTABLE_ACCURACY_METERS,
  MIN_MOVEMENT_METERS,
  haversineDistanceKm,
} = require('../utils/geoValidation');
const {
  MAX_CLIENT_CLOCK_SKEW_MS,
  MAX_FUTURE_TIMESTAMP_MS,
  STALE_LOCATION_MS,
  OFFLINE_LOCATION_MS,
  ACTIVE_TRIP_STATES,
} = require('../config/trackingPolicy');
const { publishLocationUpdated } = require('./trackingEventService');

function buildClientEventId(camioneroId, timestamp, coordinates) {
  const ts = new Date(timestamp).getTime();
  const [lng, lat] = coordinates;
  return `${camioneroId}:${ts}:${lng.toFixed(5)}:${lat.toFixed(5)}`;
}

function validateTrackingPayload(body, camioneroId) {
  const normalized = normalizeLatLngInput(body);
  if (!normalized) {
    return { error: 'Latitud y longitud válidas son obligatorias' };
  }

  const timestamp = parseTimestamp(body.timestamp);
  if (!timestamp) {
    return { error: 'timestamp debe ser una fecha válida' };
  }

  const now = Date.now();
  const tsMs = timestamp.getTime();
  if (tsMs > now + MAX_FUTURE_TIMESTAMP_MS) {
    return { error: 'timestamp no puede estar en el futuro' };
  }
  if (now - tsMs > MAX_CLIENT_CLOCK_SKEW_MS) {
    return { error: 'timestamp demasiado antiguo; sincroniza la hora del dispositivo' };
  }

  const accuracy = normalizeNumber(body.accuracy ?? body.precision);
  if (accuracy !== null && accuracy > MAX_ACCEPTABLE_ACCURACY_METERS) {
    return { error: `Precisión GPS insuficiente (>${MAX_ACCEPTABLE_ACCURACY_METERS}m)` };
  }

  const signal = body.signal && typeof body.signal === 'object' ? body.signal : undefined;
  if (signal?.isMocked === true) {
    return { error: 'Ubicación simulada (mock GPS) no permitida' };
  }

  const source = ['gps', 'network', 'offline_sync'].includes(body.source)
    ? body.source
    : 'gps';

  const oportunidadId = mongoose.Types.ObjectId.isValid(body.oportunidadId)
    ? body.oportunidadId
    : undefined;

  const clientEventId = typeof body.clientEventId === 'string' && body.clientEventId.trim()
    ? body.clientEventId.trim()
    : buildClientEventId(camioneroId, timestamp, normalized.coordinates);

  return {
    payload: {
      camionero: camioneroId,
      oportunidad: oportunidadId,
      coordinates: normalized.coordinates,
      coords: { lat: normalized.lat, lng: normalized.lng },
      timestamp,
      serverReceivedAt: new Date(),
      speed: normalizeNumber(body.speed ?? body.velocidad),
      heading: normalizeNumber(body.heading ?? body.rumbo),
      accuracy,
      signal,
      source,
      trackingStatusOverride: ['active', 'stopped', 'offline'].includes(body.trackingStatusOverride)
        ? body.trackingStatusOverride
        : undefined,
      operationalEvent: body.operationalEvent && typeof body.operationalEvent === 'object'
        ? {
          type: ['movement', 'stopped', 'signal_lost', 'signal_recovered'].includes(body.operationalEvent.type)
            ? body.operationalEvent.type
            : undefined,
          reason: typeof body.operationalEvent.reason === 'string'
            ? body.operationalEvent.reason.trim()
            : undefined,
          reportedAt: parseTimestamp(body.operationalEvent.reportedAt) || new Date(),
        }
        : undefined,
      clientEventId,
      sequence: normalizeNumber(body.sequence),
    },
  };
}

async function resolveActiveTripForCamionero(camioneroId) {
  return Oportunidad.findOne({
    camioneroAsignado: camioneroId,
    estado: { $in: ACTIVE_TRIP_STATES },
  }).select('_id estado');
}

function getTrackingStatusFromLocation(location) {
  if (!location) {
    return {
      trackingStatus: 'no_location',
      ageMs: null,
      isStale: false,
      isOffline: true,
      lastSeenAt: null,
    };
  }

  if (location.trackingStatusOverride === 'offline') {
    return {
      trackingStatus: 'offline',
      ageMs: 0,
      isStale: false,
      isOffline: true,
      lastSeenAt: location.timestamp,
      serverReceivedAt: location.serverReceivedAt || location.timestamp,
    };
  }

  if (location.trackingStatusOverride === 'stopped') {
    return {
      trackingStatus: 'stopped',
      ageMs: 0,
      isStale: false,
      isOffline: false,
      lastSeenAt: location.timestamp,
      serverReceivedAt: location.serverReceivedAt || location.timestamp,
    };
  }

  const referenceTime = location.serverReceivedAt || location.timestamp;
  const ageMs = Date.now() - new Date(referenceTime).getTime();
  let trackingStatus = 'offline';
  if (ageMs <= STALE_LOCATION_MS) trackingStatus = 'active';
  else if (ageMs <= OFFLINE_LOCATION_MS) trackingStatus = 'stale';

  return {
    trackingStatus,
    ageMs,
    isStale: trackingStatus === 'stale',
    isOffline: trackingStatus === 'offline',
    lastSeenAt: location.timestamp,
    serverReceivedAt: location.serverReceivedAt || location.timestamp,
  };
}

async function shouldSkipAsDuplicate(camioneroId, payload) {
  const latest = await UbicacionActual.findOne({ camionero: camioneroId }).lean();
  if (!latest?.coordinates) return { skip: false, reason: null, latest };

  const latestCoords = {
    lat: latest.coords?.lat ?? latest.coordinates[1],
    lng: latest.coords?.lng ?? latest.coordinates[0],
  };
  const incoming = { lat: payload.coords.lat, lng: payload.coords.lng };

  if (payload.clientEventId && latest.clientEventId === payload.clientEventId) {
    return { skip: true, reason: 'duplicate_event', latest };
  }

  if (isDuplicateCoordinatePair(latestCoords, incoming, MIN_MOVEMENT_METERS)) {
    const latestTs = new Date(latest.timestamp).getTime();
    const incomingTs = new Date(payload.timestamp).getTime();
    if (incomingTs <= latestTs) {
      return { skip: true, reason: 'stale_or_duplicate_position', latest };
    }
  }

  return { skip: false, reason: null, latest };
}

async function shouldAcceptLatestUpdate(camioneroId, payload, latest) {
  if (!latest?.timestamp) return true;
  return new Date(payload.timestamp).getTime() >= new Date(latest.timestamp).getTime();
}

async function persistLocationUpdate(camioneroId, body, options = {}) {
  const validation = validateTrackingPayload(body, camioneroId);
  if (validation.error) {
    const error = new Error(validation.error);
    error.statusCode = 400;
    throw error;
  }

  const { payload } = validation;

  const activeTrip = options.simulation
    ? null
    : await resolveActiveTripForCamionero(camioneroId);
  if (activeTrip && !payload.oportunidad) {
    payload.oportunidad = activeTrip._id;
  }

  if (payload.oportunidad && !options.simulation) {
    const trip = await Oportunidad.findById(payload.oportunidad).select('camioneroAsignado estado');
    if (!trip || trip.camioneroAsignado?.toString() !== camioneroId) {
      const error = new Error('oportunidadId no corresponde al viaje activo del camionero');
      error.statusCode = 400;
      throw error;
    }
  }

  const duplicateCheck = await shouldSkipAsDuplicate(camioneroId, payload);
  if (duplicateCheck.skip) {
    const statusMeta = getTrackingStatusFromLocation(duplicateCheck.latest);
    return {
      skipped: true,
      reason: duplicateCheck.reason,
      ubicacion: null,
      ubicacionActual: duplicateCheck.latest,
      meta: statusMeta,
    };
  }

  let ubicacion = null;
  try {
    ubicacion = await Ubicacion.create(payload);
  } catch (err) {
    if (err?.code === 11000 && payload.clientEventId) {
      const existing = await Ubicacion.findOne({
        camionero: camioneroId,
        clientEventId: payload.clientEventId,
      });
      if (existing) {
        const statusMeta = getTrackingStatusFromLocation(duplicateCheck.latest);
        return {
          skipped: true,
          reason: 'duplicate_event',
          ubicacion: existing,
          ubicacionActual: duplicateCheck.latest,
          meta: statusMeta,
        };
      }
    }
    throw err;
  }

  let ubicacionActual = duplicateCheck.latest;
  const acceptLatest = await shouldAcceptLatestUpdate(camioneroId, payload, duplicateCheck.latest);

  if (!acceptLatest) {
    const statusMeta = getTrackingStatusFromLocation(duplicateCheck.latest);
    return {
      skipped: true,
      reason: 'stale_latest_update',
      ubicacion,
      ubicacionActual: duplicateCheck.latest,
      meta: statusMeta,
    };
  }

  ubicacionActual = await UbicacionActual.findOneAndUpdate(
    { camionero: camioneroId },
    { $set: payload },
    { upsert: true, new: true, runValidators: true },
  );

  const statusMeta = getTrackingStatusFromLocation(ubicacionActual);
  await publishLocationUpdated(ubicacionActual, statusMeta);

  return {
    skipped: false,
    reason: null,
    ubicacion,
    ubicacionActual,
    meta: statusMeta,
  };
}

async function getLocationHistory(camioneroId, { since = null, limit = 200 } = {}) {
  const safeLimit = Math.min(Number(limit) || 200, 1000);
  const query = { camionero: camioneroId };
  const parsedSince = since ? parseTimestamp(since, null) : null;
  if (parsedSince) {
    query.timestamp = { $gte: parsedSince };
  }

  const historial = await Ubicacion.find(query)
    .sort({ timestamp: -1 })
    .limit(safeLimit);

  return historial;
}

module.exports = {
  buildClientEventId,
  validateTrackingPayload,
  getTrackingStatusFromLocation,
  persistLocationUpdate,
  getLocationHistory,
  resolveActiveTripForCamionero,
};

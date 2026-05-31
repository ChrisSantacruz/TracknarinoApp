const Oportunidad = require('../models/Oportunidad');
const { emitTrackingLocationUpdated } = require('./realtimeService');

/**
 * Event boundary for tracking updates.
 * Phase 2: persist-first Socket.IO emission to scoped rooms.
 */

function buildTrackingEventPayload(locationDoc, meta = {}) {
  const camioneroId = locationDoc.camionero?.toString?.() || locationDoc.camionero;
  const oportunidadId = locationDoc.oportunidad?.toString?.() || locationDoc.oportunidad || null;
  const clientEventId = locationDoc.clientEventId || null;
  const eventTime = new Date(locationDoc.timestamp).toISOString();

  return {
    version: 1,
    eventId: clientEventId
      ? `tracking.location.updated:${clientEventId}`
      : `tracking.location.updated:${camioneroId}:${eventTime}`,
    type: 'tracking.location.updated',
    camioneroId,
    oportunidadId,
    coordinates: locationDoc.coordinates,
    coords: locationDoc.coords,
    timestamp: eventTime,
    serverReceivedAt: new Date(locationDoc.serverReceivedAt || Date.now()).toISOString(),
    source: locationDoc.source,
    sequence: locationDoc.sequence ?? null,
    accuracy: locationDoc.accuracy ?? null,
    heading: locationDoc.heading ?? null,
    speed: locationDoc.speed ?? null,
    trackingStatus: meta.trackingStatus || null,
    meta: {
      ageMs: meta.ageMs ?? null,
      isStale: meta.isStale === true,
      isOffline: meta.isOffline === true,
    },
    emittedAt: new Date().toISOString(),
  };
}

async function resolveTripOwner(locationDoc) {
  if (!locationDoc.oportunidad) return null;

  const trip = await Oportunidad.findById(locationDoc.oportunidad).select('contratista ownerId ownerType').lean();
  return {
    contratistaId: trip?.contratista?.toString?.() || null,
    ownerId: trip?.ownerId?.toString?.() || trip?.contratista?.toString?.() || null,
    ownerType: trip?.ownerType || 'CONTRATISTA',
  };
}

async function publishLocationUpdated(locationDoc, meta = {}) {
  const payload = buildTrackingEventPayload(locationDoc, meta);
  const owner = await resolveTripOwner(locationDoc);
  payload.ownerId = owner?.ownerId || null;
  payload.ownerType = owner?.ownerType || null;

  emitTrackingLocationUpdated(payload, {
    contratistaId: owner?.contratistaId,
    camioneroId: payload.camioneroId,
    oportunidadId: payload.oportunidadId,
  });

  if (process.env.NODE_ENV === 'development') {
    console.debug('[trackingEvent] location.updated', payload.camioneroId, payload.trackingStatus);
  }
  return payload;
}

module.exports = {
  buildTrackingEventPayload,
  publishLocationUpdated,
};

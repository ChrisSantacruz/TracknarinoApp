const { emitTripStateChanged } = require('./realtimeService');

/**
 * Event boundary for trip lifecycle changes.
 * Phase 2: persist-first Socket.IO emission to scoped rooms.
 */

function buildTripEventPayload(oportunidad, eventType) {
  const oportunidadId = oportunidad._id?.toString?.() || oportunidad.id;
  const contratistaId = oportunidad.contratista?.toString?.() || oportunidad.contratista;
  const camioneroId = oportunidad.camioneroAsignado?.toString?.() || oportunidad.camioneroAsignado || null;

  return {
    version: 1,
    eventId: `${eventType}:${oportunidadId}:${oportunidad.estado}:${new Date().toISOString()}`,
    type: eventType,
    oportunidadId,
    estado: oportunidad.estado,
    contratistaId,
    camioneroId,
    origin: oportunidad.origin || null,
    destination: oportunidad.destination || null,
    emittedAt: new Date().toISOString(),
  };
}

async function publishTripStateChanged(oportunidad, previousState = null) {
  const payload = {
    ...buildTripEventPayload(oportunidad, 'trip.state.changed'),
    previousState,
  };

  emitTripStateChanged(payload, {
    contratistaId: payload.contratistaId,
    camioneroId: payload.camioneroId,
    oportunidadId: payload.oportunidadId,
  });

  if (process.env.NODE_ENV === 'development') {
    console.debug('[tripEvent] state.changed', payload.oportunidadId, previousState, '->', payload.estado);
  }
  return payload;
}

module.exports = {
  buildTripEventPayload,
  publishTripStateChanged,
};

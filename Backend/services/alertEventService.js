const { emitAlertCreated } = require('./realtimeService');

function buildAlertCreatedPayload(alerta) {
  const alertaId = alerta._id?.toString?.() || alerta.id;
  const usuarioId = alerta.usuario?._id?.toString?.() || alerta.usuario?.toString?.() || alerta.usuario || null;

  return {
    version: 1,
    eventId: `alert.created:${alertaId}`,
    type: 'alert.created',
    alertaId,
    usuarioId,
    tipo: alerta.tipo,
    descripcion: alerta.descripcion,
    coordinates: alerta.coordinates,
    coords: alerta.coords,
    createdAt: new Date(alerta.createdAt || Date.now()).toISOString(),
    emittedAt: new Date().toISOString(),
  };
}

async function publishAlertCreated(alerta) {
  const payload = buildAlertCreatedPayload(alerta);
  emitAlertCreated(payload);

  if (process.env.NODE_ENV === 'development') {
    console.debug('[alertEvent] created', payload.alertaId, payload.tipo);
  }

  return payload;
}

module.exports = {
  buildAlertCreatedPayload,
  publishAlertCreated,
};

const Offer = require('../models/Offer');
const Oportunidad = require('../models/Oportunidad');
const User = require('../models/User');
const { enviarNotificacionUsuario } = require('./fcmService');
const { emitOfferCreated, emitOfferAccepted, emitOfferRejected } = require('./realtimeService');
const { publishTripStateChanged } = require('./tripEventService');
const { getOwnerId, isOpportunityOwner } = require('./opportunityAccessService');

const ACTIVE_TRIP_STATES = ['asignada', 'aceptada', 'en_ruta'];

function parsePositiveMoney(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function publicOfferQuery(filter = {}) {
  return Offer.find(filter)
    .populate('camionero', 'nombre correo telefono camion reputation calificacion')
    .populate('owner', 'nombre correo empresa fotoPerfil tipoUsuario');
}

async function createOffer({ oportunidadId, camioneroId, precio, comentario }) {
  const precioNormalizado = parsePositiveMoney(precio);
  if (!precioNormalizado) {
    const error = new Error('El precio ofertado debe ser mayor a cero');
    error.statusCode = 400;
    throw error;
  }

  const oportunidad = await Oportunidad.findById(oportunidadId);
  if (!oportunidad) {
    const error = new Error('Oportunidad no encontrada');
    error.statusCode = 404;
    throw error;
  }
  if (oportunidad.estado !== 'disponible') {
    const error = new Error('Solo se pueden ofertar cargas disponibles');
    error.statusCode = 400;
    throw error;
  }

  const ownerId = getOwnerId(oportunidad);
  if (!ownerId) {
    const error = new Error('La oportunidad no tiene propietario operativo');
    error.statusCode = 409;
    throw error;
  }

  const offer = await Offer.findOneAndUpdate(
    {
      oportunidad: oportunidad._id,
      camionero: camioneroId,
      estado: 'pendiente',
    },
    {
      oportunidad: oportunidad._id,
      camionero: camioneroId,
      owner: ownerId,
      ownerType: oportunidad.ownerType || 'CONTRATISTA',
      precio: precioNormalizado,
      comentario,
      estado: 'pendiente',
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  oportunidad.negociacion = {
    ...(oportunidad.negociacion?.toObject?.() || oportunidad.negociacion || {}),
    estado: 'oferta_camionero',
    precioOfertado: precioNormalizado,
    precioContraoferta: undefined,
    camionero: camioneroId,
    ultimaAccionPor: camioneroId,
    ultimaAccionRol: 'camionero',
    mensaje: comentario,
    updatedAt: new Date(),
  };
  await oportunidad.save();

  const populated = await publicOfferQuery({ _id: offer._id }).then((items) => items[0]);
  emitOfferCreated({
    version: 1,
    eventId: `offer.created:${offer._id}:${offer.updatedAt.getTime()}`,
    type: 'offer.created',
    oportunidadId: oportunidad._id.toString(),
    offerId: offer._id.toString(),
    ownerId: ownerId.toString(),
    ownerType: offer.ownerType,
    camioneroId: camioneroId.toString(),
    precio: offer.precio,
    createdAt: offer.createdAt.toISOString(),
  }, { ownerId, camioneroId, oportunidadId: oportunidad._id });

  await enviarNotificacionUsuario(ownerId, 'Nueva oferta recibida', 'Un camionero envio una oferta para tu carga.', {
    type: 'offer.created',
    oportunidadId: oportunidad._id.toString(),
    offerId: offer._id.toString(),
  });

  return { oportunidad, offer: populated || offer };
}

async function listOffersForOpportunity({ oportunidadId, user }) {
  const oportunidad = await Oportunidad.findById(oportunidadId);
  if (!oportunidad) {
    const error = new Error('Oportunidad no encontrada');
    error.statusCode = 404;
    throw error;
  }

  if (!isOpportunityOwner(oportunidad, user) && user.tipoUsuario !== 'camionero') {
    const error = new Error('No tienes permisos para ver ofertas de esta oportunidad');
    error.statusCode = 403;
    throw error;
  }

  const query = { oportunidad: oportunidad._id };
  if (user.tipoUsuario === 'camionero') {
    query.camionero = user.id;
  }

  const offers = await publicOfferQuery(query)
    .sort({ estado: 1, precio: 1, createdAt: -1 });
  return { oportunidad, offers };
}

async function acceptOffer({ offerId, user }) {
  const offer = await Offer.findById(offerId);
  if (!offer) {
    const error = new Error('Oferta no encontrada');
    error.statusCode = 404;
    throw error;
  }

  const oportunidad = await Oportunidad.findById(offer.oportunidad);
  if (!oportunidad) {
    const error = new Error('Oportunidad no encontrada');
    error.statusCode = 404;
    throw error;
  }
  if (!isOpportunityOwner(oportunidad, user)) {
    const error = new Error('Solo el propietario puede aceptar esta oferta');
    error.statusCode = 403;
    throw error;
  }
  if (offer.estado !== 'pendiente' || oportunidad.estado !== 'disponible') {
    const error = new Error('La oferta ya no esta disponible para aceptacion');
    error.statusCode = 400;
    throw error;
  }

  const viajeActivo = await Oportunidad.findOne({
    camioneroAsignado: offer.camionero,
    estado: { $in: ACTIVE_TRIP_STATES },
  });
  if (viajeActivo) {
    const error = new Error('El camionero ya tiene un viaje activo');
    error.statusCode = 400;
    throw error;
  }

  const previousState = oportunidad.estado;
  oportunidad.precio = offer.precio;
  oportunidad.camioneroAsignado = offer.camionero;
  oportunidad.estado = 'aceptada';
  oportunidad.estadoTimestamps = oportunidad.estadoTimestamps || {};
  oportunidad.estadoTimestamps.aceptada = new Date();
  oportunidad.negociacion = {
    ...(oportunidad.negociacion?.toObject?.() || oportunidad.negociacion || {}),
    estado: 'aceptada',
    precioOfertado: offer.precio,
    camionero: offer.camionero,
    ultimaAccionPor: user.id,
    ultimaAccionRol: user.tipoUsuario,
    mensaje: offer.comentario,
    updatedAt: new Date(),
  };

  offer.estado = 'aceptada';
  offer.respondedAt = new Date();
  await Promise.all([
    oportunidad.save(),
    offer.save(),
    Offer.updateMany(
      { oportunidad: oportunidad._id, _id: { $ne: offer._id }, estado: 'pendiente' },
      { estado: 'rechazada', respondedAt: new Date() }
    ),
  ]);

  await publishTripStateChanged(oportunidad, previousState);
  emitOfferAccepted({
    version: 1,
    eventId: `offer.accepted:${offer._id}:${offer.respondedAt.getTime()}`,
    type: 'offer.accepted',
    oportunidadId: oportunidad._id.toString(),
    offerId: offer._id.toString(),
    camioneroId: offer.camionero.toString(),
    ownerId: getOwnerId(oportunidad)?.toString(),
    precio: offer.precio,
    acceptedAt: offer.respondedAt.toISOString(),
  }, {
    ownerId: getOwnerId(oportunidad),
    camioneroId: offer.camionero,
    oportunidadId: oportunidad._id,
  });

  await enviarNotificacionUsuario(offer.camionero, 'Oferta aceptada', 'Tu oferta fue aceptada y el viaje fue asignado.', {
    type: 'offer.accepted',
    oportunidadId: oportunidad._id.toString(),
    offerId: offer._id.toString(),
  });

  return { oportunidad, offer };
}

async function rejectOffer({ offerId, user }) {
  const offer = await Offer.findById(offerId);
  if (!offer) {
    const error = new Error('Oferta no encontrada');
    error.statusCode = 404;
    throw error;
  }
  const oportunidad = await Oportunidad.findById(offer.oportunidad);
  if (!oportunidad || !isOpportunityOwner(oportunidad, user)) {
    const error = new Error('No tienes permisos para rechazar esta oferta');
    error.statusCode = 403;
    throw error;
  }

  offer.estado = 'rechazada';
  offer.respondedAt = new Date();
  await offer.save();

  emitOfferRejected({
    version: 1,
    eventId: `offer.rejected:${offer._id}:${offer.respondedAt.getTime()}`,
    type: 'offer.rejected',
    oportunidadId: oportunidad._id.toString(),
    offerId: offer._id.toString(),
    camioneroId: offer.camionero.toString(),
    rejectedAt: offer.respondedAt.toISOString(),
  }, {
    ownerId: getOwnerId(oportunidad),
    camioneroId: offer.camionero,
    oportunidadId: oportunidad._id,
  });

  await enviarNotificacionUsuario(offer.camionero, 'Oferta rechazada', 'Tu oferta para la carga fue rechazada.', {
    type: 'offer.rejected',
    oportunidadId: oportunidad._id.toString(),
    offerId: offer._id.toString(),
  });

  return { oportunidad, offer };
}

module.exports = {
  createOffer,
  listOffersForOpportunity,
  acceptOffer,
  rejectOffer,
};

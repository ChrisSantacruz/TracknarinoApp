const crypto = require('crypto');
const Oportunidad = require('../models/Oportunidad');
const UbicacionActual = require('../models/UbicacionActual');
const Rating = require('../models/Rating');
const User = require('../models/User');
const { canAccessTrip, isAssignedDriver, isOpportunityOwner } = require('../services/opportunityAccessService');
const { sendError } = require('../middleware/errorMiddleware');

function sanitizeLocation(location) {
  if (!location || typeof location !== 'object') return null;
  const lat = Number(location.lat);
  const lng = Number(location.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return { lat, lng };
}

async function loadAccessibleTrip(req, res) {
  const { allowed, oportunidad } = await canAccessTrip(req.usuario, req.params.tripId);
  if (!oportunidad) {
    sendError(res, 404, 'Viaje no encontrado', 'TRIP_NOT_FOUND');
    return null;
  }
  if (!allowed) {
    sendError(res, 403, 'No tienes permisos para este viaje', 'FORBIDDEN');
    return null;
  }
  return oportunidad;
}

async function saveDeliveryEvidence(req, res) {
  const trip = await loadAccessibleTrip(req, res);
  if (!trip) return;

  if (!isAssignedDriver(trip, req.usuario) && !isOpportunityOwner(trip, req.usuario)) {
    return sendError(res, 403, 'No puedes registrar evidencia de este viaje', 'FORBIDDEN');
  }

  const photos = Array.isArray(req.body.photos)
    ? req.body.photos.map((value) => String(value || '').trim()).filter(Boolean).slice(0, 6)
    : [];
  const location = sanitizeLocation(req.body.location);
  if (req.body.location && !location) {
    return sendError(res, 400, 'Ubicacion de evidencia invalida', 'VALIDATION_ERROR');
  }

  trip.deliveryEvidence = {
    photos,
    observations: String(req.body.observations || '').trim(),
    deliveredAt: req.body.deliveredAt ? new Date(req.body.deliveredAt) : new Date(),
    location,
    signatureName: String(req.body.signatureName || '').trim(),
  };
  await trip.save();

  res.status(201).json({ deliveryEvidence: trip.deliveryEvidence });
}

async function getDeliveryEvidence(req, res) {
  const trip = await loadAccessibleTrip(req, res);
  if (!trip) return;

  res.json({ deliveryEvidence: trip.deliveryEvidence || null });
}

async function enableSharedTracking(req, res) {
  const trip = await loadAccessibleTrip(req, res);
  if (!trip) return;
  if (!isOpportunityOwner(trip, req.usuario)) {
    return sendError(res, 403, 'Solo el propietario puede compartir el seguimiento', 'FORBIDDEN');
  }

  if (!trip.trackingId) {
    trip.trackingId = crypto.randomBytes(18).toString('hex');
  }
  trip.sharedTrackingEnabled = true;
  await trip.save();

  res.json({
    trackingId: trip.trackingId,
    path: `/tracking/shared/${trip.trackingId}`,
  });
}

async function disableSharedTracking(req, res) {
  const trip = await loadAccessibleTrip(req, res);
  if (!trip) return;
  if (!isOpportunityOwner(trip, req.usuario)) {
    return sendError(res, 403, 'Solo el propietario puede desactivar el seguimiento', 'FORBIDDEN');
  }

  trip.sharedTrackingEnabled = false;
  await trip.save();
  res.json({ mensaje: 'Seguimiento compartido desactivado' });
}

async function getSharedTracking(req, res) {
  const trip = await Oportunidad.findOne({
    trackingId: req.params.trackingId,
    sharedTrackingEnabled: true,
  })
    .select('titulo origin destination origen destino estado camioneroAsignado trackingId updatedAt')
    .lean();

  if (!trip) {
    return sendError(res, 404, 'Seguimiento no encontrado', 'TRACKING_NOT_FOUND');
  }

  const location = trip.camioneroAsignado
    ? await UbicacionActual.findOne({ camionero: trip.camioneroAsignado })
      .select('coords coordinates timestamp serverReceivedAt heading speed accuracy')
      .lean()
    : null;

  res.json({
    trackingId: trip.trackingId,
    titulo: trip.titulo,
    estado: trip.estado,
    origin: trip.origin || { name: trip.origen },
    destination: trip.destination || { name: trip.destino },
    location,
    updatedAt: trip.updatedAt,
  });
}

async function rateTrip(req, res) {
  const trip = await loadAccessibleTrip(req, res);
  if (!trip) return;
  if (trip.estado !== 'entregada') {
    return sendError(res, 400, 'Solo se pueden calificar viajes entregados', 'TRIP_NOT_COMPLETED');
  }

  const ratedUserId = String(req.body.ratedUserId || '').trim();
  const stars = Number(req.body.stars);
  if (!ratedUserId || !Number.isFinite(stars) || stars < 1 || stars > 5) {
    return sendError(res, 400, 'ratedUserId y stars entre 1 y 5 son obligatorios', 'VALIDATION_ERROR');
  }
  if (ratedUserId === req.usuario.id) {
    return sendError(res, 400, 'No puedes calificarte a ti mismo', 'VALIDATION_ERROR');
  }

  const ratedUser = await User.findById(ratedUserId).select('tipoUsuario');
  if (!ratedUser) {
    return sendError(res, 404, 'Usuario a calificar no encontrado', 'USER_NOT_FOUND');
  }

  const rating = await Rating.findOneAndUpdate(
    {
      trip: trip._id,
      rater: req.usuario.id,
      ratedUser: ratedUserId,
    },
    {
      trip: trip._id,
      rater: req.usuario.id,
      ratedUser: ratedUserId,
      raterRole: req.usuario.tipoUsuario,
      ratedRole: ratedUser.tipoUsuario,
      stars,
      comment: String(req.body.comment || '').trim(),
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  const [stats] = await Rating.aggregate([
    { $match: { ratedUser: ratedUser._id } },
    { $group: { _id: null, promedio: { $avg: '$stars' }, total: { $sum: 1 } } },
  ]);
  await User.findByIdAndUpdate(ratedUserId, {
    calificacion: stats?.promedio || 0,
    'reputation.promedio': stats?.promedio || 0,
    'reputation.total': stats?.total || 0,
  });

  res.status(201).json({ rating });
}

module.exports = {
  saveDeliveryEvidence,
  getDeliveryEvidence,
  enableSharedTracking,
  disableSharedTracking,
  getSharedTracking,
  rateTrip,
};

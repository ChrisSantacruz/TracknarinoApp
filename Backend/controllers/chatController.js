const ChatMessage = require('../models/ChatMessage');
const { canAccessTrip } = require('../services/opportunityAccessService');
const { sendError } = require('../middleware/errorMiddleware');

async function ensureTripAccess(req, res) {
  const { allowed, oportunidad } = await canAccessTrip(req.usuario, req.params.tripId);
  if (!oportunidad) {
    sendError(res, 404, 'Viaje no encontrado', 'TRIP_NOT_FOUND');
    return null;
  }
  if (!allowed) {
    sendError(res, 403, 'No tienes permisos para acceder a este chat', 'FORBIDDEN');
    return null;
  }
  return oportunidad;
}

async function listChatMessages(req, res) {
  const oportunidad = await ensureTripAccess(req, res);
  if (!oportunidad) return;

  const limit = Math.min(Number(req.query.limit || 50), 100);
  const messages = await ChatMessage.find({ trip: oportunidad._id })
    .sort({ createdAt: -1 })
    .limit(limit)
    .populate('sender', 'nombre correo fotoPerfil tipoUsuario')
    .lean();

  res.json({ messages: messages.reverse() });
}

async function createChatMessage(req, res) {
  const oportunidad = await ensureTripAccess(req, res);
  if (!oportunidad) return;

  const message = String(req.body.message || '').trim();
  if (!message || message.length > 2000) {
    return sendError(res, 400, 'Mensaje invalido', 'VALIDATION_ERROR');
  }

  const chatMessage = await ChatMessage.create({
    trip: oportunidad._id,
    sender: req.usuario.id,
    senderRole: req.usuario.tipoUsuario,
    message,
    deliveredTo: [{ user: req.usuario.id, at: new Date() }],
    readBy: [{ user: req.usuario.id, at: new Date() }],
  });
  await chatMessage.populate('sender', 'nombre correo fotoPerfil tipoUsuario');

  res.status(201).json({ message: chatMessage });
}

async function markChatRead(req, res) {
  const oportunidad = await ensureTripAccess(req, res);
  if (!oportunidad) return;

  await ChatMessage.updateMany(
    {
      trip: oportunidad._id,
      'readBy.user': { $ne: req.usuario.id },
    },
    {
      $push: { readBy: { user: req.usuario.id, at: new Date() } },
    }
  );

  res.json({ mensaje: 'Chat marcado como leido' });
}

module.exports = {
  listChatMessages,
  createChatMessage,
  markChatRead,
};

const express = require('express');
const router = express.Router();
const User = require('../models/User');
const verificarToken = require('../middleware/authMiddleware');
const asyncHandler = require('../middleware/asyncHandler');
const { sendError } = require('../middleware/errorMiddleware');
const { sanitizeUser } = require('../utils/auth');

function authMoved(req, res) {
  return sendError(
    res,
    410,
    'Esta ruta de autenticación fue movida. Usa /api/auth.',
    'AUTH_ROUTE_MOVED'
  );
}

router.post('/registro', authMoved);
router.post('/login', authMoved);
router.put('/actualizar-pago', authMoved);

// Obtener perfil del usuario autenticado
router.get('/perfil', verificarToken, asyncHandler(async (req, res) => {
  const usuario = await User.findById(req.usuario.id).select('-contraseña');

  if (!usuario) {
    return sendError(res, 404, 'Usuario no encontrado', 'USER_NOT_FOUND');
  }

  return res.json({ usuario: sanitizeUser(usuario) });
}));

router.get('/:id/reputation', verificarToken, asyncHandler(async (req, res) => {
  const usuario = await User.findById(req.params.id).select('tipoUsuario calificacion reputation');
  if (!usuario) {
    return sendError(res, 404, 'Usuario no encontrado', 'USER_NOT_FOUND');
  }

  return res.json({
    userId: usuario._id,
    tipoUsuario: usuario.tipoUsuario,
    promedio: usuario.reputation?.promedio ?? usuario.calificacion ?? 0,
    total: usuario.reputation?.total ?? 0,
    totalViajes: usuario.reputation?.totalViajes ?? 0,
    totalContrataciones: usuario.reputation?.totalContrataciones ?? 0,
    totalOperaciones: usuario.reputation?.totalOperaciones ?? 0,
  });
}));

module.exports = router;

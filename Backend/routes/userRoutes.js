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

module.exports = router;

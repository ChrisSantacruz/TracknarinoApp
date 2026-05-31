const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../utils/auth');
const { sendError } = require('./errorMiddleware');

function verificarToken(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return sendError(res, 401, 'Token no proporcionado', 'AUTH_TOKEN_MISSING');
  }

  try {
    const decoded = jwt.verify(token, getJwtSecret());
    req.usuario = {
      ...decoded,
      tipoUsuario: decoded.tipoUsuario || decoded.tipo,
      sessionType: decoded.sessionType,
      isSimulation: decoded.sessionType === 'SIMULATION_DRIVER',
    };
    next();
  } catch (error) {
    return sendError(res, 401, 'Token inválido o expirado', 'AUTH_TOKEN_INVALID');
  }
}

module.exports = verificarToken;

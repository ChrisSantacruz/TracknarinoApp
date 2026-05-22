const jwt = require('jsonwebtoken');

const TOKEN_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '1d';

function getJwtSecret() {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET es obligatorio para iniciar el backend');
  }

  return process.env.JWT_SECRET;
}

function buildAuthToken(usuario) {
  return jwt.sign(
    {
      id: usuario._id.toString(),
      tipoUsuario: usuario.tipoUsuario,
    },
    getJwtSecret(),
    { expiresIn: TOKEN_EXPIRES_IN }
  );
}

function sanitizeUser(usuario) {
  if (!usuario) return usuario;

  const safeUser = typeof usuario.toObject === 'function'
    ? usuario.toObject()
    : { ...usuario };

  delete safeUser.contraseña;
  delete safeUser.__v;

  return safeUser;
}

module.exports = {
  buildAuthToken,
  getJwtSecret,
  sanitizeUser,
};

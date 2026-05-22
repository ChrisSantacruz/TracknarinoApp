function sendError(res, status, message, code, details) {
  const payload = {
    success: false,
    mensaje: message,
    error: message,
  };

  if (code) payload.code = code;
  if (details && process.env.NODE_ENV === 'development') payload.details = details;

  return res.status(status).json(payload);
}

function notFound(req, res) {
  return sendError(res, 404, 'Ruta no encontrada', 'NOT_FOUND');
}

function errorHandler(err, req, res, next) {
  if (res.headersSent) {
    return next(err);
  }

  const status = err.status || err.statusCode || 500;
  const message = status === 500 ? 'Error interno del servidor' : err.message;

  console.error(`[${req.method} ${req.originalUrl}] ${err.message}`);
  return sendError(res, status, message, err.code, err.stack);
}

module.exports = {
  sendError,
  notFound,
  errorHandler,
};

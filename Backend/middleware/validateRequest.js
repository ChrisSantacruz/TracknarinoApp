const { sendError } = require('./errorMiddleware');

function requireFields(fields) {
  return (req, res, next) => {
    const missingFields = fields.filter((field) => {
      const value = req.body?.[field];
      return value === undefined || value === null || value === '';
    });

    if (missingFields.length > 0) {
      return sendError(
        res,
        400,
        `Campos obligatorios faltantes: ${missingFields.join(', ')}`,
        'VALIDATION_ERROR'
      );
    }

    next();
  };
}

function validateCoordinatePair(field) {
  return (req, res, next) => {
    const value = req.body?.[field];
    const isValid =
      Array.isArray(value) &&
      value.length === 2 &&
      value.every((coordinate) => Number.isFinite(Number(coordinate)));

    if (!isValid) {
      return sendError(res, 400, `${field} debe ser un array [lng, lat]`, 'VALIDATION_ERROR');
    }

    next();
  };
}

module.exports = {
  requireFields,
  validateCoordinatePair,
};

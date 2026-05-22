const express = require('express');
const router = express.Router();
const { obtenerRutaORS } = require('../services/orsService');
const verificarToken = require('../middleware/authMiddleware');
const asyncHandler = require('../middleware/asyncHandler');
const { validateCoordinatePair } = require('../middleware/validateRequest');

// POST /api/ors/ruta - Protegido para evitar abuso del proxy de rutas
router.post(
  '/ruta',
  verificarToken,
  validateCoordinatePair('origen'),
  validateCoordinatePair('destino'),
  asyncHandler(async (req, res) => {
    const { origen, destino } = req.body;
    const correlationId = req.headers['x-correlation-id'] || req.body.correlationId;

    const resultado = await obtenerRutaORS(origen, destino, { correlationId });

    if (resultado.error) {
      return res.status(502).json({ error: resultado.error, provider: resultado.provider, correlationId: resultado.correlationId });
    }

    res.json(resultado);
  })
);

module.exports = router;

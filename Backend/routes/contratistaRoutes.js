const express = require('express');
const router = express.Router();
const {
  afiliarCamionero,
  rechazarAfiliacion,
  obtenerFlotaTracking
} = require('../controllers/contratistaController');
const verificarToken = require('../middleware/authMiddleware');
const soloRol = require('../middleware/rolMiddleware');

// Afiliar camionero a contratista
router.post('/afiliar/:id', verificarToken, soloRol('contratista'), afiliarCamionero);

// Rechazar afiliación de camionero
router.post('/rechazar/:id', verificarToken, soloRol('contratista'), rechazarAfiliacion);

// Tracking real de flota para polling de contratistas
router.get('/tracking/flota', verificarToken, soloRol('contratista'), obtenerFlotaTracking);

module.exports = router;

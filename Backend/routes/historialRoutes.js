const express = require('express');
const router = express.Router();
const {
  historialCamionero,
  historialContratista,
  historialCliente
} = require('../controllers/historialController');
const verificarToken = require('../middleware/authMiddleware');
const soloRol = require('../middleware/rolMiddleware');

// Consultar historial de cargas de camionero
router.get('/camionero', verificarToken, soloRol('camionero'), historialCamionero);

// Consultar historial de asignaciones de contratista
router.get('/contratista', verificarToken, soloRol('contratista'), historialContratista);

// Consultar historial de cargas de cliente
router.get('/cliente', verificarToken, soloRol('cliente'), historialCliente);

module.exports = router;

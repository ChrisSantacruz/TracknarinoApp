const express = require('express');

const verificarToken = require('../middleware/authMiddleware');
const soloRol = require('../middleware/rolMiddleware');
const {
  persistRoute,
  getActiveRoute,
  getHistory,
  recordAudit,
  getRouteAudit,
  getDiagnostics,
  getProviderDiagnostics,
} = require('../controllers/operationalRouteController');

const router = express.Router();

router.use(verificarToken);
router.use(soloRol(['contratista', 'camionero']));

router.post('/routes', persistRoute);
router.get('/routes/:tripId/active', getActiveRoute);
router.get('/routes/:tripId/history', getHistory);
router.post('/audit', recordAudit);
router.get('/audit/:routeId', getRouteAudit);
router.get('/diagnostics', getDiagnostics);
router.get('/provider-health', getProviderDiagnostics);

module.exports = router;

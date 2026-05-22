const express = require('express');

const verificarToken = require('../middleware/authMiddleware');
const soloRol = require('../middleware/rolMiddleware');
const {
  getDiagnostics,
  getReadiness,
  getReleaseGateStatus,
} = require('../controllers/operationalDiagnosticsController');

const router = express.Router();

router.get('/readiness', getReadiness);
router.get('/release-gates', getReleaseGateStatus);

router.use(verificarToken);
router.use(soloRol(['contratista', 'camionero']));

router.get('/diagnostics', getDiagnostics);

module.exports = router;

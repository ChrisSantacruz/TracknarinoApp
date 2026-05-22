const asyncHandler = require('../middleware/asyncHandler');
const { getOperationalDiagnostics } = require('../services/operationalDiagnosticsService');
const { getOperationsReadiness } = require('../services/operationalReadinessService');
const { recordCounter } = require('../services/operationalMetricsService');
const { getReleaseGates } = require('../release/releaseGateService');

const getDiagnostics = asyncHandler(async (req, res) => {
  recordCounter('operations.diagnostics.request', 1, {
    role: req.usuario?.tipoUsuario || req.usuario?.tipo || 'unknown',
  });
  const diagnostics = await getOperationalDiagnostics({
    user: req.usuario,
    sinceHours: req.query.sinceHours,
    limit: req.query.limit,
  });

  return res.json({
    success: true,
    diagnostics,
  });
});

const getReadiness = asyncHandler(async (req, res) => {
  recordCounter('operations.readiness.request');
  const readiness = await getOperationsReadiness();
  return res.status(readiness.ready ? 200 : 503).json({
    success: readiness.ready,
    readiness,
  });
});

const getReleaseGateStatus = asyncHandler(async (req, res) => {
  recordCounter('operations.release_gates.request');
  const releaseGates = await getReleaseGates();
  return res.status(200).json({
    success: releaseGates.overallState !== 'fail',
    releaseGates,
  });
});

module.exports = {
  getDiagnostics,
  getReadiness,
  getReleaseGateStatus,
};

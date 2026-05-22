const { getOperationsReadiness } = require('../services/operationalReadinessService');
const { getOperationalMetricsSnapshot } = require('../services/operationalMetricsService');
const { validateEvidenceManifest } = require('./evidenceManifestValidator');
const { detectOperationalRegressions } = require('./regressionDetector');
const { RELEASE_GATES, READINESS_CATEGORIES } = require('./releaseGateDefinitions');

function gateState(hasCritical, hasWarning, blocked = false) {
  if (blocked) return 'blocked';
  if (hasCritical) return 'fail';
  if (hasWarning) return 'warning';
  return 'pass';
}

function issue(severity, code, message, details = {}) {
  return { severity, code, message, details };
}

function buildGate(definition, state, issues, notes = []) {
  return {
    ...definition,
    state,
    passed: state === 'pass' || state === 'warning',
    issues,
    notes,
  };
}

function hasArtifactType(evidence, type) {
  return (evidence.artifactTypes || []).includes(type) ||
    (evidence.completeness?.presentScenarioTypes || []).includes(type);
}

function readinessIssuesByCode(readiness, codes) {
  return (readiness.issues || []).filter((item) => codes.includes(item.code));
}

function scoreGate(state) {
  if (state === 'pass') return 100;
  if (state === 'warning') return 72;
  if (state === 'blocked') return 35;
  return 0;
}

function buildReadinessScores(gates, readiness, evidence) {
  const byCategory = new Map(READINESS_CATEGORIES.map((category) => [category, []]));
  for (const gate of gates) {
    byCategory.get(gate.category)?.push(scoreGate(gate.state));
  }

  if (readiness.providers.routing.status === 'degraded') {
    byCategory.get('provider_stability')?.push(45);
  } else if (readiness.providers.routing.status === 'healthy') {
    byCategory.get('provider_stability')?.push(100);
  } else {
    byCategory.get('provider_stability')?.push(70);
  }

  byCategory.get('replay_integrity')?.push(evidence.passed ? 100 : 25);
  byCategory.get('evidence_completeness')?.push(Math.round((evidence.completeness?.scenarioCoverage || 0) * 100));

  return READINESS_CATEGORIES.map((category) => {
    const scores = byCategory.get(category) || [];
    const score = scores.length
      ? Math.round(scores.reduce((sum, value) => sum + value, 0) / scores.length)
      : 0;
    return {
      category,
      score,
      state: score >= 85 ? 'pass' : score >= 65 ? 'warning' : 'fail',
    };
  });
}

function computeReleaseConfidence(gates, readinessScores) {
  const gateAverage = gates.length
    ? gates.reduce((sum, gate) => sum + scoreGate(gate.state), 0) / gates.length
    : 0;
  const readinessAverage = readinessScores.length
    ? readinessScores.reduce((sum, item) => sum + item.score, 0) / readinessScores.length
    : 0;
  return {
    value: Math.round((gateAverage * 0.7) + (readinessAverage * 0.3)),
    basis: 'Derived only from live readiness gates, bounded runtime diagnostics, regression comparison, and validated evidence manifest state.',
  };
}

async function getReleaseGates() {
  const readiness = await getOperationsReadiness();
  const metrics = getOperationalMetricsSnapshot();
  const evidence = await validateEvidenceManifest(process.env.RELEASE_EVIDENCE_MANIFEST_PATH);
  const regressions = await detectOperationalRegressions({ metrics });
  const gateById = Object.fromEntries(RELEASE_GATES.map((gate) => [gate.id, gate]));

  const deploymentIssues = [
    ...readinessIssuesByCode(readiness, ['ENV_MISSING', 'ROUTING_PROVIDER_NOT_READY', 'MONGO_NOT_READY', 'MONGO_NOT_CONNECTED']),
  ];
  const indexIssues = readiness.indexes?.issues || [];
  const redisIssues = readinessIssuesByCode(readiness, ['SOCKET_REDIS_ADAPTER_NOT_READY', 'SOCKET_REDIS_NOT_CONFIGURED']);
  const socketIssues = readinessIssuesByCode(readiness, ['SOCKET_REDIS_ADAPTER_NOT_READY', 'RECONNECT_STORM_DETECTED']);
  const evidenceCritical = (evidence.issues || []).filter((item) => item.severity === 'critical');

  const dependencyIssues = [];
  if (!hasArtifactType(evidence, 'dependency_audit')) {
    dependencyIssues.push(issue('critical', 'DEPENDENCY_AUDIT_MISSING', 'No hay artefacto dependency_audit validado en el manifiesto de release.'));
  }

  const offlineIssues = [];
  if (!hasArtifactType(evidence, 'offline_replay_recovery')) {
    offlineIssues.push(issue('critical', 'OFFLINE_REPLAY_EVIDENCE_MISSING', 'No hay evidencia firmada para offline replay recovery.'));
  }
  offlineIssues.push(...evidenceCritical.filter((item) => ['TIMELINE_MISSING', 'CORRELATION_BROKEN', 'REPLAY_EXPECTATION_UNMET'].includes(item.code)));

  const routePersistenceIssues = [];
  if (!readiness.routePersistence?.modelReady || !readiness.routePersistence?.auditTrailReady || !readiness.routePersistence?.telemetryReady) {
    routePersistenceIssues.push(issue('critical', 'ROUTE_PERSISTENCE_NOT_READY', 'La persistencia/auditoría/telemetría de rutas no está completa.'));
  }
  if (!hasArtifactType(evidence, 'route_persistence_snapshot')) {
    routePersistenceIssues.push(issue('warning', 'ROUTE_PERSISTENCE_EVIDENCE_MISSING', 'No hay snapshot de persistencia de rutas en el manifiesto.'));
  }

  const gates = [
    buildGate(
      gateById.deployment_blockers,
      gateState(deploymentIssues.some((item) => item.severity === 'critical'), deploymentIssues.length > 0),
      deploymentIssues,
      ['Docker healthchecks deben apuntar a /api/health y conservar estados 503 cuando Mongo/env/provider no están listos.'],
    ),
    buildGate(
      gateById.dependency_vulnerability,
      gateState(dependencyIssues.some((item) => item.severity === 'critical'), false),
      dependencyIssues,
      ['El endpoint no ejecuta npm audit en caliente; exige evidencia auditada y firmada.'],
    ),
    buildGate(
      gateById.missing_index,
      gateState(indexIssues.some((item) => item.severity === 'critical'), indexIssues.some((item) => item.severity === 'warning')),
      indexIssues,
      ['MongoDB getIndexes/indexes() se usa como verificación de presencia; no se crean índices desde el gate.'],
    ),
    buildGate(
      gateById.redis_readiness,
      gateState(redisIssues.some((item) => item.severity === 'critical'), redisIssues.some((item) => item.severity === 'warning')),
      redisIssues,
      ['Redis readiness requiere conexión real del adapter y política explícita de staging/producción.'],
    ),
    buildGate(
      gateById.socket_io_scaling,
      gateState(socketIssues.some((item) => item.severity === 'critical'), socketIssues.some((item) => item.severity === 'warning')),
      socketIssues,
      ['Socket.IO con Redis adapter clásico requiere sticky sessions para polling HTTP.'],
    ),
    buildGate(
      gateById.offline_replay_integrity,
      gateState(offlineIssues.some((item) => item.severity === 'critical'), offlineIssues.some((item) => item.severity === 'warning')),
      offlineIssues,
      ['Replay se valida desde timeline/correlationId; no se interpola GPS ni se inventa recuperación.'],
    ),
    buildGate(
      gateById.route_persistence_integrity,
      gateState(routePersistenceIssues.some((item) => item.severity === 'critical'), routePersistenceIssues.some((item) => item.severity === 'warning')),
      routePersistenceIssues,
    ),
    buildGate(
      gateById.operational_regression,
      gateState(regressions.issues.some((item) => item.severity === 'critical'), regressions.issues.length > 0, !regressions.checked),
      regressions.issues,
      ['Las regresiones usan métricas acotadas en memoria y baseline explícito; sin stack pesado de observabilidad.'],
    ),
    buildGate(
      gateById.evidence_completeness,
      gateState(evidenceCritical.length > 0, (evidence.issues || []).some((item) => item.severity === 'warning'), !evidence.checked),
      evidence.issues,
      ['La evidencia faltante baja readiness; nunca se genera evidencia sintética.'],
    ),
  ];

  const unresolvedBlockers = gates
    .filter((gate) => gate.state === 'fail' || gate.state === 'blocked')
    .flatMap((gate) => gate.issues.map((item) => ({ gateId: gate.id, ...item })));
  const readinessScores = buildReadinessScores(gates, readiness, evidence);
  const releaseConfidenceScore = computeReleaseConfidence(gates, readinessScores);
  const warningCount = gates.filter((gate) => gate.state === 'warning').length;

  return {
    generatedAt: new Date().toISOString(),
    overallState: unresolvedBlockers.length > 0 ? 'fail' : warningCount > 0 ? 'warning' : 'pass',
    releaseConfidenceScore,
    readinessScores,
    gates,
    evidence,
    regressions,
    unresolvedBlockers,
    operationalNotes: [
      'Confidence is gate-derived and not a claim of field validation unless evidence is present and verified.',
      'Device-lab and staging failure runs must attach signed artifacts before production release.',
      'Degraded states remain visible as warnings/blockers instead of fallback success.',
    ],
  };
}

module.exports = {
  getReleaseGates,
};

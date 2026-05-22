const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

const DEFAULT_MAX_EVIDENCE_AGE_DAYS = Number(process.env.RELEASE_EVIDENCE_MAX_AGE_DAYS || 14);

function issue(severity, code, message, details = {}) {
  return { severity, code, message, details };
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeScenario(raw, fallbackId) {
  return {
    id: raw.id || raw.scenarioId || raw.scenario || fallbackId,
    type: raw.type || raw.scenarioType || raw.scenario || 'unknown',
    sessionId: raw.sessionId || raw.profile?.sessionId,
    correlationId: raw.correlationId || raw.profile?.correlationId,
    signedBy: raw.signedBy || raw.signature?.signedBy,
    signedAt: raw.signedAt || raw.signature?.signedAt,
    capturedAt: raw.capturedAt || raw.generatedAt || raw.profile?.startedAt,
    artifacts: asArray(raw.artifacts).concat(asArray(raw.captures)),
    diagnosticsSnapshots: asArray(raw.diagnosticsSnapshots),
    timeline: asArray(raw.timeline).concat(asArray(raw.diagnostics?.timeline)),
    replayExpectation: raw.replayExpectation || raw.replayExpectations || {},
    metadata: raw.metadata || {},
  };
}

function collectScenarios(manifest) {
  if (Array.isArray(manifest.scenarios)) {
    return manifest.scenarios.map((scenario, index) => normalizeScenario(scenario, `scenario-${index + 1}`));
  }

  if (manifest.scenario || manifest.profile || Array.isArray(manifest.timeline)) {
    return [normalizeScenario(manifest, manifest.scenario || 'single-capture')];
  }

  return [];
}

function isEvidenceStale(value, now = Date.now()) {
  if (!value) return false;
  const timestamp = new Date(value).getTime();
  if (!Number.isFinite(timestamp)) return true;
  const maxAgeMs = DEFAULT_MAX_EVIDENCE_AGE_DAYS * 24 * 60 * 60 * 1000;
  return now - timestamp > maxAgeMs;
}

async function hashFile(filePath) {
  const buffer = await fs.readFile(filePath);
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function resolveArtifactPath(manifestDir, artifact) {
  const artifactPath = artifact.path || artifact.file || artifact.relativePath;
  if (!artifactPath) return null;
  return path.isAbsolute(artifactPath) ? artifactPath : path.resolve(manifestDir, artifactPath);
}

function validateScenarioShape(scenario) {
  const issues = [];
  if (!scenario.sessionId) {
    issues.push(issue('critical', 'EVIDENCE_SESSION_MISSING', 'La evidencia no declara sessionId.', { scenario: scenario.id }));
  }
  if (!scenario.correlationId) {
    issues.push(issue('warning', 'EVIDENCE_CORRELATION_MISSING', 'La evidencia no declara correlationId.', { scenario: scenario.id }));
  }
  if (!scenario.signedBy || !scenario.signedAt) {
    issues.push(issue('critical', 'EVIDENCE_SIGNATURE_MISSING', 'La evidencia no tiene metadata de firma operacional.', { scenario: scenario.id }));
  }
  if (isEvidenceStale(scenario.capturedAt || scenario.signedAt)) {
    issues.push(issue('warning', 'EVIDENCE_STALE', 'La evidencia supera la ventana operacional configurada.', {
      scenario: scenario.id,
      maxAgeDays: DEFAULT_MAX_EVIDENCE_AGE_DAYS,
    }));
  }
  if (scenario.timeline.length === 0) {
    issues.push(issue('critical', 'TIMELINE_MISSING', 'La evidencia no contiene timeline verificable.', { scenario: scenario.id }));
  }

  const timelineCorrelationIds = new Set(
    scenario.timeline.map((event) => event.correlationId).filter(Boolean),
  );
  if (scenario.correlationId && timelineCorrelationIds.size > 0 && !timelineCorrelationIds.has(scenario.correlationId)) {
    issues.push(issue('critical', 'CORRELATION_BROKEN', 'El correlationId del escenario no aparece en el timeline.', {
      scenario: scenario.id,
      correlationId: scenario.correlationId,
      timelineCorrelationIds: Array.from(timelineCorrelationIds),
    }));
  }

  const requiredEventTypes = asArray(scenario.replayExpectation.requiredEventTypes);
  if (requiredEventTypes.length > 0) {
    const eventTypes = new Set(scenario.timeline.map((event) => event.eventType || event.type).filter(Boolean));
    const missing = requiredEventTypes.filter((eventType) => !eventTypes.has(eventType));
    if (missing.length > 0) {
      issues.push(issue('critical', 'REPLAY_EXPECTATION_UNMET', 'El timeline no cumple los eventos requeridos para replay.', {
        scenario: scenario.id,
        missing,
      }));
    }
  }

  return issues;
}

async function validateArtifacts(manifestDir, scenario) {
  const issues = [];
  const checkedArtifacts = [];
  const artifacts = scenario.artifacts.concat(scenario.diagnosticsSnapshots);

  if (artifacts.length === 0) {
    issues.push(issue('critical', 'ARTIFACTS_MISSING', 'El escenario no declara artefactos verificables.', { scenario: scenario.id }));
    return { issues, checkedArtifacts };
  }

  for (const artifact of artifacts) {
    const resolvedPath = resolveArtifactPath(manifestDir, artifact);
    if (!resolvedPath) {
      issues.push(issue('critical', 'ARTIFACT_PATH_MISSING', 'Artefacto sin path verificable.', { scenario: scenario.id }));
      continue;
    }

    try {
      const actualSha256 = await hashFile(resolvedPath);
      const expectedSha256 = artifact.sha256 || artifact.hash;
      const verified = expectedSha256 ? actualSha256 === expectedSha256 : false;
      checkedArtifacts.push({
        scenario: scenario.id,
        path: resolvedPath,
        type: artifact.type || artifact.kind || 'artifact',
        sha256: actualSha256,
        expectedSha256,
        verified,
      });

      if (!expectedSha256) {
        issues.push(issue('critical', 'ARTIFACT_HASH_MISSING', 'Artefacto sin sha256 esperado.', {
          scenario: scenario.id,
          path: resolvedPath,
        }));
      } else if (!verified) {
        issues.push(issue('critical', 'ARTIFACT_HASH_MISMATCH', 'El hash del artefacto no coincide con el manifiesto.', {
          scenario: scenario.id,
          path: resolvedPath,
        }));
      }
    } catch (error) {
      issues.push(issue('critical', 'ARTIFACT_UNREADABLE', 'No se pudo leer un artefacto declarado.', {
        scenario: scenario.id,
        path: resolvedPath,
        error: error.message,
      }));
    }
  }

  return { issues, checkedArtifacts };
}

function buildCompleteness(scenarios, checkedArtifacts) {
  const requiredScenarioTypes = [
    'long_route',
    'degraded_lte',
    'reconnect_storm',
    'tunnel_no_signal',
    'gps_drift',
    'offline_replay_recovery',
    'background_resume_lifecycle',
    'battery_saver_mode',
    'route_replacement_storms',
  ];
  const scenarioTypes = new Set(scenarios.map((scenario) => scenario.type));
  const missingScenarioTypes = requiredScenarioTypes.filter((type) => !scenarioTypes.has(type));

  return {
    requiredScenarioTypes,
    presentScenarioTypes: Array.from(scenarioTypes),
    missingScenarioTypes,
    scenarioCoverage:
      requiredScenarioTypes.length === 0
        ? 1
        : (requiredScenarioTypes.length - missingScenarioTypes.length) / requiredScenarioTypes.length,
    verifiedArtifacts: checkedArtifacts.filter((artifact) => artifact.verified).length,
    checkedArtifacts: checkedArtifacts.length,
  };
}

async function validateEvidenceManifest(manifestPath) {
  if (!manifestPath) {
    return {
      checked: false,
      passed: false,
      issues: [
        issue('critical', 'EVIDENCE_MANIFEST_NOT_CONFIGURED', 'RELEASE_EVIDENCE_MANIFEST_PATH no está configurado.'),
      ],
      scenarios: [],
      checkedArtifacts: [],
      completeness: buildCompleteness([], []),
    };
  }

  const absolutePath = path.resolve(manifestPath);
  const manifestDir = path.dirname(absolutePath);

  try {
    const raw = await fs.readFile(absolutePath, 'utf8');
    const manifest = JSON.parse(raw);
    const manifestHash = crypto.createHash('sha256').update(raw).digest('hex');
    const scenarios = collectScenarios(manifest);
    const issues = [];
    const checkedArtifacts = [];
    const scenarioResults = [];

    if (scenarios.length === 0) {
      issues.push(issue('critical', 'SCENARIOS_MISSING', 'El manifiesto no contiene escenarios de evidencia.'));
    }

    for (const scenario of scenarios) {
      const scenarioIssues = validateScenarioShape(scenario);
      const artifactResult = await validateArtifacts(manifestDir, scenario);
      scenarioIssues.push(...artifactResult.issues);
      checkedArtifacts.push(...artifactResult.checkedArtifacts);
      issues.push(...scenarioIssues);
      scenarioResults.push({
        id: scenario.id,
        type: scenario.type,
        sessionId: scenario.sessionId,
        correlationId: scenario.correlationId,
        signed: Boolean(scenario.signedBy && scenario.signedAt),
        timelineEvents: scenario.timeline.length,
        issues: scenarioIssues,
      });
    }

    const completeness = buildCompleteness(scenarios, checkedArtifacts);
    if (completeness.missingScenarioTypes.length > 0) {
      issues.push(issue('warning', 'EVIDENCE_SCENARIO_COVERAGE_INCOMPLETE', 'Faltan escenarios obligatorios del device-lab.', {
        missingScenarioTypes: completeness.missingScenarioTypes,
      }));
    }

    return {
      checked: true,
      passed: !issues.some((item) => item.severity === 'critical'),
      manifestPath: absolutePath,
      manifestSha256: manifestHash,
      releaseId: manifest.releaseId || manifest.release || null,
      generatedAt: manifest.generatedAt || null,
      scenarios: scenarioResults,
      checkedArtifacts,
      completeness,
      issues,
      artifactTypes: Array.from(new Set(checkedArtifacts.map((artifact) => artifact.type))),
    };
  } catch (error) {
    return {
      checked: false,
      passed: false,
      manifestPath: absolutePath,
      issues: [
        issue('critical', 'EVIDENCE_MANIFEST_INVALID', 'No se pudo leer o parsear el manifiesto de evidencia.', {
          error: error.message,
        }),
      ],
      scenarios: [],
      checkedArtifacts: [],
      completeness: buildCompleteness([], []),
    };
  }
}

module.exports = {
  validateEvidenceManifest,
};

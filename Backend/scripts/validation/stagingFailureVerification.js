const fs = require('fs/promises');
const path = require('path');

const DEFAULT_API_URL = process.env.TRACKNARINO_API_URL || 'http://localhost:4000/api';

function readArgs() {
  const args = process.argv.slice(2);
  const options = {
    apiUrl: DEFAULT_API_URL,
    scenarioFile: process.env.STAGING_FAILURE_SCENARIO_FILE,
    outputDir: process.env.STAGING_FAILURE_OUTPUT_DIR || path.join('docs', 'staging-failure-runs'),
  };

  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === '--api-url') options.apiUrl = args[index + 1];
    if (args[index] === '--scenario') options.scenarioFile = args[index + 1];
    if (args[index] === '--output-dir') options.outputDir = args[index + 1];
  }
  return options;
}

async function timedFetch(url, options = {}) {
  const startedAt = Date.now();
  try {
    const response = await fetch(url, options);
    let body = null;
    try {
      body = await response.json();
    } catch (_) {
      body = null;
    }
    return {
      ok: response.ok,
      status: response.status,
      latencyMs: Date.now() - startedAt,
      body,
    };
  } catch (error) {
    return {
      ok: false,
      status: null,
      latencyMs: Date.now() - startedAt,
      error: error.message,
    };
  }
}

function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

function blocked(name, reason) {
  return { name, state: 'blocked', reason };
}

function explicitResult(name, response, expectation) {
  const expectedStatuses = expectation.expectedStatuses || [200, 503, 500, 408, 429];
  const expectedCodes = expectation.expectedCodes || [];
  const body = response.body || {};
  const code = body.code || body.error?.code || body.readiness?.severity || body.releaseGates?.overallState;
  const statusMatches = expectedStatuses.includes(response.status);
  const gateCodes = (body.releaseGates?.unresolvedBlockers || []).map((item) => item.code);
  const codeMatches = expectedCodes.length === 0 || expectedCodes.includes(code) || expectedCodes.some((expected) => gateCodes.includes(expected));
  const explicitFailure = !response.ok || body.success === false || body.releaseGates?.overallState === 'fail';
  const passed = explicitFailure && statusMatches && codeMatches;

  return {
    name,
    state: passed ? 'pass' : 'fail',
    response: {
      ok: response.ok,
      status: response.status,
      latencyMs: response.latencyMs,
      code,
      error: response.error,
    },
    expectation: {
      expectedStatuses,
      expectedCodes,
      note: 'Controlled failure verification passes only when degradation/failure is explicit. Hidden fallback success fails.',
    },
  };
}

async function verifyProviderTimeout(apiUrl, scenario) {
  const config = scenario.providerTimeout;
  if (!config?.token || !config?.payload) {
    return blocked('provider_timeout_simulation', 'providerTimeout.token and providerTimeout.payload are required.');
  }

  const response = await timedFetch(`${apiUrl}/ors/ruta`, {
    method: 'POST',
    headers: authHeaders(config.token),
    body: JSON.stringify(config.payload),
  });
  return explicitResult('provider_timeout_simulation', response, config);
}

async function verifyReadinessFailure(apiUrl, scenario, name, configKey, expectedCodes) {
  const config = scenario[configKey];
  if (!config?.enabled) {
    return blocked(name, `${configKey}.enabled must be true after the staging dependency has been deliberately degraded.`);
  }
  const response = await timedFetch(`${apiUrl}/operations/release-gates`);
  return explicitResult(name, response, {
    expectedStatuses: config.expectedStatuses || [503],
    expectedCodes: config.expectedCodes || expectedCodes,
  });
}

async function verifyOfflineQueuePressure(apiUrl, scenario) {
  const config = scenario.offlineQueuePressure;
  if (!config?.token || !Array.isArray(config.requests) || config.requests.length === 0) {
    return blocked('offline_queue_pressure_verification', 'offlineQueuePressure.token and real queued requests are required.');
  }

  const responses = [];
  for (const request of config.requests) {
    responses.push(await timedFetch(`${apiUrl}${request.path}`, {
      method: request.method || 'POST',
      headers: authHeaders(config.token),
      body: request.body ? JSON.stringify(request.body) : undefined,
    }));
  }

  const silentSuccesses = responses.filter((response) => response.ok).length;
  return {
    name: 'offline_queue_pressure_verification',
    state: silentSuccesses === 0 ? 'pass' : 'fail',
    silentSuccesses,
    responses: responses.map((response) => ({
      ok: response.ok,
      status: response.status,
      latencyMs: response.latencyMs,
      error: response.error,
    })),
  };
}

async function main() {
  const options = readArgs();
  if (!options.scenarioFile) {
    throw new Error('STAGING_FAILURE_SCENARIO_FILE or --scenario is required. Use explicit staging degradation steps only.');
  }

  const scenario = JSON.parse(await fs.readFile(options.scenarioFile, 'utf8'));
  const results = [];
  results.push(await verifyProviderTimeout(options.apiUrl, scenario));
  results.push(await verifyReadinessFailure(options.apiUrl, scenario, 'redis_unavailable_verification', 'redisUnavailable', ['SOCKET_REDIS_ADAPTER_NOT_READY']));
  results.push(await verifyReadinessFailure(options.apiUrl, scenario, 'mongo_degraded_response_verification', 'mongoDegraded', ['MONGO_NOT_READY', 'MONGO_NOT_CONNECTED']));
  results.push(await verifyReadinessFailure(options.apiUrl, scenario, 'socket_reconnect_storm_verification', 'socketReconnectStorm', ['RECONNECT_STORM_DETECTED']));
  results.push(await verifyOfflineQueuePressure(options.apiUrl, scenario));
  results.push(await verifyReadinessFailure(options.apiUrl, scenario, 'route_invalidation_burst_verification', 'routeInvalidationBurst', ['COUNTER_REGRESSION', 'ROUTE_PERSISTENCE_EVIDENCE_MISSING']));
  results.push(await verifyReadinessFailure(options.apiUrl, scenario, 'fleet_overload_verification', 'fleetOverload', ['LATENCY_REGRESSION', 'REGRESSION_SIGNAL_MISSING']));

  const report = {
    generatedAt: new Date().toISOString(),
    apiUrl: options.apiUrl,
    scenarioName: scenario.name || 'staging_failure_verification',
    operationalTruthPolicy: 'Blocked and failed checks are preserved. This tool does not convert missing controls into success.',
    results,
  };

  await fs.mkdir(options.outputDir, { recursive: true });
  const outputPath = path.join(options.outputDir, `staging-failure-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  await fs.writeFile(outputPath, JSON.stringify(report, null, 2));
  console.log(`Staging failure verification report written: ${outputPath}`);

  if (results.some((result) => result.state === 'fail')) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(`Staging failure verification failed: ${error.message}`);
  process.exit(1);
});

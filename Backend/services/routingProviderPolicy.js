const axios = require('axios');

const operationalLogger = require('../utils/operationalLogger');
const { recordRouteTelemetry } = require('./routeTelemetryService');
const { recordCounter, recordLatency } = require('./operationalMetricsService');

const PROVIDER_POLICY = Object.freeze({
  public_osrm: {
    name: 'public_osrm',
    baseUrl: process.env.OSRM_BASE_URL || 'https://router.project-osrm.org/route/v1/driving',
    timeoutMs: Number(process.env.OSRM_TIMEOUT_MS || 12000),
    retryCount: Number(process.env.OSRM_RETRY_COUNT || 1),
  },
});

const providerHealth = new Map();

function getProviderPolicy(provider = process.env.ROUTING_PROVIDER || 'public_osrm') {
  return PROVIDER_POLICY[provider] || PROVIDER_POLICY.public_osrm;
}

function getProviderHealth(provider) {
  const state = providerHealth.get(provider) || {
    provider,
    status: 'unknown',
    successes: 0,
    failures: 0,
    lastLatencyMs: null,
    lastSuccessAt: null,
    lastFailureAt: null,
    lastFailureCode: null,
  };

  const total = state.successes + state.failures;
  const recentFailureRate = total > 0 ? state.failures / total : 0;

  return {
    ...state,
    status: state.failures > 0 && recentFailureRate >= 0.5 ? 'degraded' : state.status,
    recentFailureRate,
  };
}

function updateProviderHealth(provider, result) {
  const current = getProviderHealth(provider);
  const next = {
    ...current,
    status: result.ok ? 'healthy' : 'degraded',
    successes: current.successes + (result.ok ? 1 : 0),
    failures: current.failures + (result.ok ? 0 : 1),
    lastLatencyMs: result.latencyMs ?? current.lastLatencyMs,
    lastSuccessAt: result.ok ? new Date() : current.lastSuccessAt,
    lastFailureAt: result.ok ? current.lastFailureAt : new Date(),
    lastFailureCode: result.ok ? current.lastFailureCode : result.failureCode,
  };

  providerHealth.set(provider, next);
  return next;
}

function buildOsrmUrl(policy, origen, destino) {
  const coordinates = `${origen[0]},${origen[1]};${destino[0]},${destino[1]}`;
  return `${policy.baseUrl}/${coordinates}`;
}

async function requestRouteFromProvider({ origen, destino, correlationId }) {
  const policy = getProviderPolicy();
  let lastError = null;

  for (let attempt = 1; attempt <= policy.retryCount + 1; attempt += 1) {
    const startedAt = Date.now();
    try {
      operationalLogger.info('routing', 'provider_request_started', {
        provider: policy.name,
        attempt,
        correlationId,
      });

      const response = await axios.get(buildOsrmUrl(policy, origen, destino), {
        params: {
          overview: 'full',
          geometries: 'polyline',
          steps: true,
        },
        timeout: policy.timeoutMs,
      });

      const latencyMs = Date.now() - startedAt;
      recordLatency('provider.route.latency_ms', latencyMs, { provider: policy.name });
      recordCounter('provider.route.success', 1, { provider: policy.name });
      updateProviderHealth(policy.name, { ok: true, latencyMs });
      await recordRouteTelemetry('provider.latency', {
        provider: policy.name,
        metrics: { latencyMs },
        correlationId,
      });

      return {
        provider: policy.name,
        response,
        diagnostics: {
          providerLatencyMs: latencyMs,
          attempt,
          providerHealth: getProviderHealth(policy.name),
          correlationId,
        },
      };
    } catch (error) {
      lastError = error;
      const latencyMs = Date.now() - startedAt;
      const failureCode = error.response?.data?.code || error.code || 'PROVIDER_REQUEST_FAILED';
      recordLatency('provider.route.latency_ms', latencyMs, { provider: policy.name, outcome: 'failure' });
      recordCounter('provider.route.failure', 1, { provider: policy.name, failureCode });
      updateProviderHealth(policy.name, { ok: false, latencyMs, failureCode });
      await recordRouteTelemetry('provider.failure', {
        provider: policy.name,
        reason: failureCode,
        metrics: { latencyMs },
        correlationId,
      });
      operationalLogger.warning('routing', 'provider_request_failed', {
        provider: policy.name,
        attempt,
        failureCode,
        correlationId,
      });
    }
  }

  const error = new Error('No se pudo obtener una ruta real desde el proveedor configurado');
  error.statusCode = 502;
  error.provider = policy.name;
  error.providerHealth = getProviderHealth(policy.name);
  error.cause = lastError;
  throw error;
}

module.exports = {
  getProviderPolicy,
  getProviderHealth,
  requestRouteFromProvider,
};

const mongoose = require('mongoose');

const AlertaSeguridad = require('../models/AlertaSeguridad');
const OperationalRoute = require('../models/OperationalRoute');
const RouteAuditRecord = require('../models/RouteAuditRecord');
const RouteTelemetryEvent = require('../models/RouteTelemetryEvent');
const UbicacionActual = require('../models/UbicacionActual');
const { validateOperationalEnvironment } = require('../config/operationalConfig');
const { getRealtimeDiagnostics } = require('./realtimeService');
const { getProviderHealth } = require('./routingProviderPolicy');

const REQUIRED_INDEXES = [
  { model: UbicacionActual, collection: 'ubicacionactuals', key: { coordinates: '2dsphere' }, severity: 'critical' },
  { model: UbicacionActual, collection: 'ubicacionactuals', key: { camionero: 1, serverReceivedAt: -1 }, severity: 'warning' },
  { model: AlertaSeguridad, collection: 'alertaseguridads', key: { coordinates: '2dsphere' }, severity: 'critical' },
  { model: AlertaSeguridad, collection: 'alertaseguridads', key: { coordinates: '2dsphere', tipo: 1, timestamp: -1 }, severity: 'warning' },
  { model: OperationalRoute, collection: 'operationalroutes', key: { tripId: 1, state: 1, routeVersion: -1 }, severity: 'critical' },
  { model: RouteAuditRecord, collection: 'routeauditrecords', key: { contractorId: 1, eventType: 1, occurredAt: -1 }, severity: 'warning' },
  { model: RouteTelemetryEvent, collection: 'routetelemetryevents', key: { provider: 1, eventType: 1, occurredAt: -1 }, severity: 'warning' },
];

function sameIndexKey(actual, expected) {
  const actualKeys = Object.keys(actual || {});
  const expectedKeys = Object.keys(expected || {});
  if (actualKeys.length !== expectedKeys.length) return false;
  return expectedKeys.every((key) => actual[key] === expected[key]);
}

function issue(severity, code, message, details = {}) {
  return { severity, code, message, details };
}

async function verifyIndexes() {
  if (mongoose.connection.readyState !== 1) {
    return {
      ready: false,
      checked: false,
      issues: [issue('critical', 'MONGO_NOT_CONNECTED', 'Mongo no está conectado; no se pueden verificar índices.')],
    };
  }

  const issues = [];
  const checks = [];
  for (const required of REQUIRED_INDEXES) {
    try {
      const indexes = await required.model.collection.indexes();
      const present = indexes.some((index) => sameIndexKey(index.key, required.key));
      checks.push({
        collection: required.collection,
        key: required.key,
        present,
        severity: required.severity,
      });
      if (!present) {
        issues.push(issue(
          required.severity,
          'INDEX_MISSING',
          `Índice requerido ausente en ${required.collection}.`,
          { collection: required.collection, key: required.key },
        ));
      }
    } catch (error) {
      issues.push(issue('critical', 'INDEX_CHECK_FAILED', `No se pudo verificar ${required.collection}.`, {
        collection: required.collection,
        error: error.message,
      }));
    }
  }

  return {
    ready: !issues.some((item) => item.severity === 'critical'),
    checked: true,
    checks,
    issues,
  };
}

function buildEnvironmentIssues(environment) {
  const issues = [];
  for (const envName of environment.missing) {
    issues.push(issue('critical', 'ENV_MISSING', `Variable obligatoria faltante: ${envName}.`, { envName }));
  }
  if (!environment.providers.providerReady) {
    issues.push(issue('critical', 'ROUTING_PROVIDER_NOT_READY', 'El proveedor de rutas configurado no está listo.'));
  }
  if (environment.environment !== 'production' && environment.environment !== 'staging') {
    issues.push(issue('warning', 'NON_STAGING_ENVIRONMENT', 'El ambiente actual no representa staging/producción.'));
  }
  return issues;
}

function buildRealtimeIssues(environment, realtime) {
  const issues = [];
  if (environment.realtime.redisConfigured && realtime.adapter.status !== 'ready') {
    issues.push(issue('critical', 'SOCKET_REDIS_ADAPTER_NOT_READY', 'Redis está configurado pero el adapter Socket.IO no está listo.', {
      adapter: realtime.adapter,
    }));
  }
  if (!environment.realtime.redisConfigured) {
    issues.push(issue('warning', 'SOCKET_REDIS_NOT_CONFIGURED', 'Socket.IO está en adapter local; staging multi-nodo requiere Redis.'));
  }
  if (environment.realtime.redisConfigured) {
    issues.push(issue('warning', 'STICKY_SESSIONS_REQUIRED', 'Socket.IO con Redis adapter todavía requiere sticky sessions en el balanceador.'));
  }
  if (realtime.reconnectStorm.state === 'degraded') {
    issues.push(issue('warning', 'RECONNECT_STORM_DETECTED', 'Se detectó presión de reconexión en la ventana runtime.', realtime.reconnectStorm));
  }
  return issues;
}

async function getOperationsReadiness() {
  const environment = validateOperationalEnvironment();
  const realtime = getRealtimeDiagnostics();
  const provider = getProviderHealth(process.env.ROUTING_PROVIDER || 'public_osrm');
  const indexVerification = await verifyIndexes();
  const mongoReady = mongoose.connection.readyState === 1;

  const issues = [
    ...buildEnvironmentIssues(environment),
    ...buildRealtimeIssues(environment, realtime),
    ...indexVerification.issues,
  ];

  if (!mongoReady) {
    issues.push(issue('critical', 'MONGO_NOT_READY', 'Mongo no está conectado.'));
  }
  if (provider.status === 'degraded') {
    issues.push(issue('warning', 'ROUTING_PROVIDER_DEGRADED', 'El proveedor de rutas presenta fallos observados.', provider));
  }

  const criticalCount = issues.filter((item) => item.severity === 'critical').length;
  const warningCount = issues.filter((item) => item.severity === 'warning').length;

  return {
    generatedAt: new Date().toISOString(),
    ready: criticalCount === 0,
    severity: criticalCount > 0 ? 'critical' : warningCount > 0 ? 'warning' : 'ok',
    mongo: {
      ready: mongoReady,
      state: mongoose.connection.readyState,
    },
    redis: {
      configured: environment.realtime.redisConfigured,
      adapter: realtime.adapter,
      stickySessionsRequired: environment.realtime.stickySessionsRequired,
    },
    providers: {
      routing: provider,
      firebase: {
        configured: Boolean(process.env.FIREBASE_SERVICE_ACCOUNT || process.env.GOOGLE_APPLICATION_CREDENTIALS),
        severity: process.env.FIREBASE_SERVICE_ACCOUNT || process.env.GOOGLE_APPLICATION_CREDENTIALS ? 'ok' : 'warning',
      },
    },
    socket: {
      nodeId: realtime.nodeId,
      connectedSockets: realtime.connectedSockets,
      knownRooms: realtime.knownRooms,
      reconnectStorm: realtime.reconnectStorm,
      roomStrategy: realtime.roomStrategy,
      scaling: realtime.scaling,
    },
    indexes: indexVerification,
    routePersistence: {
      modelReady: true,
      auditTrailReady: true,
      telemetryReady: true,
    },
    environment: {
      name: environment.environment,
      features: environment.features,
      realtime: environment.realtime,
    },
    issues,
  };
}

module.exports = {
  getOperationsReadiness,
};

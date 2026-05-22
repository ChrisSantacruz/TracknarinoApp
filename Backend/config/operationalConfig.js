const REQUIRED_ENV = ['JWT_SECRET'];
const PRODUCTION_REQUIRED_ENV = ['MONGO_URI'];

function isEnabled(value) {
  return ['1', 'true', 'yes', 'on'].includes(String(value || '').toLowerCase());
}

function validateOperationalEnvironment(env = process.env) {
  const missing = REQUIRED_ENV.filter((key) => !env[key]);
  if (env.NODE_ENV === 'production' || env.NODE_ENV === 'staging') {
    missing.push(...PRODUCTION_REQUIRED_ENV.filter((key) => !env[key]));
  }

  const redisConfigured = Boolean(env.SOCKET_IO_REDIS_URL || env.REDIS_URL);
  const routingProvider = env.ROUTING_PROVIDER || 'public_osrm';
  const providerReady =
    routingProvider === 'public_osrm' ||
    (routingProvider === 'self_hosted_osrm' && Boolean(env.OSRM_BASE_URL));

  return {
    ok: missing.length === 0 && providerReady,
    environment: env.NODE_ENV || 'development',
    missing,
    features: {
      redisSocketAdapter: redisConfigured,
      deviceLabTools: isEnabled(env.OPERATIONAL_VALIDATION_TOOLS),
      routeDiagnostics: true,
      operationalReplay: true,
    },
    providers: {
      routingProvider,
      providerReady,
      publicOsrm: routingProvider === 'public_osrm',
      selfHostedOsrmConfigured: Boolean(env.OSRM_BASE_URL),
    },
    realtime: {
      socketRecoveryMs: Number(env.SOCKET_RECOVERY_MS || 120000),
      redisConfigured,
      stickySessionsRequired: redisConfigured,
      adapterKey: env.SOCKET_IO_REDIS_KEY || 'tracknarino:socket.io',
    },
  };
}

function assertOperationalEnvironment() {
  const diagnostics = validateOperationalEnvironment();
  if (diagnostics.missing.length > 0) {
    throw new Error(`Variables de entorno obligatorias faltantes: ${diagnostics.missing.join(', ')}`);
  }
  if (!diagnostics.providers.providerReady) {
    throw new Error('El proveedor de rutas configurado no está listo para iniciar.');
  }
  return diagnostics;
}

module.exports = {
  assertOperationalEnvironment,
  validateOperationalEnvironment,
};

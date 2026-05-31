const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();
const { notFound, errorHandler } = require('./middleware/errorMiddleware');
const { initializeRealtime, shutdownRealtime } = require('./services/realtimeService');
const operationalLogger = require('./utils/operationalLogger');
const {
  assertOperationalEnvironment,
  validateOperationalEnvironment,
} = require('./config/operationalConfig');

const startupReadiness = assertOperationalEnvironment();

// 📦 Rutas principales
const authRoutes = require('./routes/authRoutes');
const oportunidadRoutes = require('./routes/oportunidadRoutes');
const orsRoutes = require('./routes/orsRoutes');
const ubicacionRoutes = require('./routes/ubicacionRoutes');
const notificacionesRoutes = require('./routes/notificacionesRoutes');
const historialRoutes = require('./routes/historialRoutes');
const adminRoutes = require('./routes/adminRoutes');
const alertaRoutes = require('./routes/alertaRoutes'); 
const calificacionRoutes = require('./routes/calificacionRoutes'); // Rutas de calificaciones
const vehiculoRoutes = require('./routes/vehiculoRoutes');
const contratistaRoutes = require('./routes/contratistaRoutes');
const userRoutes = require('./routes/userRoutes');
const operationalRouteRoutes = require('./routes/operationalRouteRoutes');
const operationalDiagnosticsRoutes = require('./routes/operationalDiagnosticsRoutes');
const chatRoutes = require('./routes/chatRoutes');
const tripExtrasRoutes = require('./routes/tripExtrasRoutes');

// Inicializar app
const app = express();

// 🛡️ Middlewares globales
app.use(helmet());

// Configuración mejorada de CORS
const corsOptions = {
  origin: function(origin, callback) {
    const allowedOrigins = [
      'http://localhost:3000',
      'http://localhost:4000',
      'http://localhost:8000',
      'http://localhost',
      'http://10.0.2.2:4000',
      'https://trackarino.com'
    ];

    // Permitir solicitudes sin origen (como aplicaciones móviles o herramientas como curl)
    if (!origin) {
      return callback(null, true);
    }

    // Aceptar cualquier puerto en localhost o 127.0.0.1 para desarrollo
    const localhostRegex = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

    if (allowedOrigins.indexOf(origin) !== -1 || localhostRegex.test(origin)) {
      return callback(null, true);
    }

    // Bloquear y registrar el origen no permitido
    console.warn(`CORS bloqueó solicitud desde origen: ${origin}`);
    return callback(new Error('Origen no permitido por CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};

app.use(cors(corsOptions));

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    mensaje: 'Demasiados intentos. Intenta nuevamente más tarde.',
    error: 'Demasiados intentos. Intenta nuevamente más tarde.',
    code: 'RATE_LIMITED',
  },
});

const sensitiveRouteLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    mensaje: 'Demasiadas solicitudes. Intenta nuevamente más tarde.',
    error: 'Demasiadas solicitudes. Intenta nuevamente más tarde.',
    code: 'RATE_LIMITED',
  },
});

app.use('/api', generalLimiter);
app.use(['/api/auth/login', '/api/auth/register', '/api/auth/registro', '/api/auth/google'], authLimiter);
app.use(['/api/ors/ruta', '/api/alertas', '/api/ubicacion', '/api/contratistas/tracking', '/api/routing', '/api/operations'], sensitiveRouteLimiter);

// Mantener los payloads acotados; las imágenes deben subirse por un flujo dedicado.
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Logger middleware para desarrollo
if (process.env.NODE_ENV === 'development') {
  app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.originalUrl}`);
    next();
  });
}

// 🔗 Montar rutas
app.use('/api/auth', authRoutes);
app.use('/api/oportunidades', oportunidadRoutes);
app.use('/api/ors', orsRoutes);
app.use('/api/ubicacion', ubicacionRoutes);
app.use('/api/notificaciones', notificacionesRoutes);
app.use('/api/historial', historialRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/alertas', alertaRoutes); 
app.use('/api/calificaciones', calificacionRoutes); // Rutas de calificaciones
app.use('/api/vehiculos', vehiculoRoutes);
app.use('/api/contratistas', contratistaRoutes);
app.use('/api/users', userRoutes);
app.use('/api/routing', operationalRouteRoutes);
app.use('/api/operations', operationalDiagnosticsRoutes);
app.use('/api', chatRoutes);
app.use('/api', tripExtrasRoutes);

app.get('/api/health', (req, res) => {
  const mongoReady = mongoose.connection.readyState === 1;
  const readiness = validateOperationalEnvironment();
  res.status(mongoReady && readiness.ok ? 200 : 503).json({
    success: mongoReady && readiness.ok,
    service: 'tracknarino-backend',
    environment: readiness.environment,
    mongo: {
      ready: mongoReady,
      state: mongoose.connection.readyState,
    },
    realtime: readiness.realtime,
    features: readiness.features,
    providers: readiness.providers,
  });
});

// Ruta raíz de prueba
app.get('/', (req, res) => {
  res.send('Bienvenido al backend de Tracknariño');
});

app.get('/api', (req, res) => {
  res.json({
    success: true,
    service: 'tracknarino-backend',
    message: 'API operativa',
  });
});

app.use('/api', notFound);
app.use(errorHandler);

// 🔌 Conexión a MongoDB
const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/trackarino';
mongoose.connect(mongoUri, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
}).then(() => {
  operationalLogger.info('database', 'mongo_connected', {
    environment: process.env.NODE_ENV || 'development',
  });
}).catch((err) => {
  operationalLogger.error('database', 'mongo_connection_failed', {
    error: err.message,
  });
  if (process.env.NODE_ENV === 'production' || process.env.NODE_ENV === 'staging') {
    process.exit(1);
  }
});

// 🚀 Iniciar servidor
const PORT = process.env.PORT || 4000;
const server = http.createServer(app);
initializeRealtime(server, corsOptions);

server.listen(PORT, () => {
  operationalLogger.info('app', 'server_started', {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    readiness: startupReadiness,
  });
});

async function shutdown(signal) {
  operationalLogger.info('app', 'shutdown_started', { signal });
  server.close(async () => {
    await shutdownRealtime();
    await mongoose.connection.close(false);
    operationalLogger.info('app', 'shutdown_complete', { signal });
    process.exit(0);
  });

  setTimeout(() => {
    operationalLogger.error('app', 'shutdown_forced_timeout', { signal });
    process.exit(1);
  }, Number(process.env.SHUTDOWN_TIMEOUT_MS || 10000)).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

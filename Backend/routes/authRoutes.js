const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Vehiculo = require('../models/Vehiculo');
const bcrypt = require('bcrypt');
const verificarToken = require('../middleware/authMiddleware');
const asyncHandler = require('../middleware/asyncHandler');
const { sendError } = require('../middleware/errorMiddleware');
const { buildAuthToken, sanitizeUser } = require('../utils/auth');
const { verifyGoogleIdToken } = require('../services/googleAuthService');

const VEHICLE_TYPES = new Set([
  'camion_liviano_npr_nqr',
  'camion_mediano_frr',
  'camion_grande_ftr_fvr_gh',
  'tractocamion',
  'camion_refrigerado',
  'camion_plataforma',
  'volqueta',
  'camioneta_carga',
]);

const CAPACITY_UNITS = new Set(['kg', 'toneladas']);
const OPERATIONAL_ROLES = new Set(['camionero', 'contratista', 'cliente']);

function normalizeText(value) {
  return String(value || '')
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function normalizeCamionPayload(camion) {
  if (!camion || typeof camion !== 'object') return null;

  return {
    ...camion,
    tipoVehiculo: normalizeText(camion.tipoVehiculo),
    unidadCapacidad: normalizeText(camion.unidadCapacidad || 'kg'),
    placa: String(camion.placa || '').trim().toUpperCase(),
    marca: String(camion.marca || '').trim(),
    modelo: String(camion.modelo || '').trim(),
  };
}

function isValidDate(value) {
  return value && !Number.isNaN(new Date(value).getTime());
}

function normalizeOptionalText(value) {
  const text = String(value || '').trim();
  return text || undefined;
}

function sendAuthResponse(res, status, mensaje, usuario) {
  return res.status(status).json({
    mensaje,
    token: buildAuthToken(usuario),
    usuario: sanitizeUser(usuario),
  });
}

function buildSimulationUser() {
  return {
    _id: process.env.SIMULATION_DRIVER_ID || '65f13d000000000000000013',
    nombre: 'Camionero Simulación TrackNariño',
    correo: 'simulation.driver@tracknarino.local',
    tipoUsuario: 'camionero',
    rolConfigurado: true,
    sessionType: 'SIMULATION_DRIVER',
    isSimulation: true,
    camion: {
      tipoVehiculo: 'camion_mediano_frr',
      marca: 'TrackNariño',
      modelo: 'SimOps',
      placa: 'SIM-013',
      capacidadCarga: 12000,
      unidadCapacidad: 'kg',
      papelesAlDia: true,
    },
  };
}

// Handler de registro reutilizable (acepta '/registro' y '/register')
const handleRegistro = asyncHandler(async (req, res) => {
  const {
    nombre,
    correo,
    contraseña,
    tipoUsuario,
    telefono,
    empresa,
    empresaAfiliada,
    licenciaExpedicion,
    licenciaVencimiento,
    numeroCedula,
    camion,
    metodoPago,
    disponibleParaSolicitarCamioneros,
  } = req.body;

  if (!correo || !contraseña || !tipoUsuario) {
    return sendError(res, 400, 'Correo, contraseña y tipoUsuario son obligatorios', 'VALIDATION_ERROR');
  }

  const camionNormalizado = normalizeCamionPayload(camion);
  const fechaLicencia = licenciaVencimiento || licenciaExpedicion;
  const empresaAfiliadaNormalizada = normalizeOptionalText(empresaAfiliada);

  // Validación de campos según tipo de usuario
  if (tipoUsuario === 'camionero' && (!camionNormalizado || !numeroCedula || !fechaLicencia)) {
    return sendError(res, 400, 'Faltan datos de camionero', 'VALIDATION_ERROR');
  }
  if (tipoUsuario === 'camionero') {
    if (!VEHICLE_TYPES.has(camionNormalizado.tipoVehiculo)) {
      return sendError(res, 400, 'Tipo de vehículo inválido', 'VALIDATION_ERROR');
    }
    if (!camionNormalizado.marca || !camionNormalizado.modelo || !camionNormalizado.placa) {
      return sendError(res, 400, 'Faltan datos del vehículo', 'VALIDATION_ERROR');
    }
    if (!Number.isFinite(Number(camionNormalizado.capacidadCarga)) || Number(camionNormalizado.capacidadCarga) <= 0) {
      return sendError(res, 400, 'La capacidad de carga debe ser mayor a cero', 'VALIDATION_ERROR');
    }
    if (!CAPACITY_UNITS.has(camionNormalizado.unidadCapacidad)) {
      return sendError(res, 400, 'Unidad de capacidad inválida', 'VALIDATION_ERROR');
    }
    if (!isValidDate(fechaLicencia)) {
      return sendError(res, 400, 'Fecha de licencia inválida', 'VALIDATION_ERROR');
    }
  }
  if (tipoUsuario === 'contratista' && (!empresa || disponibleParaSolicitarCamioneros === undefined)) {
    return sendError(res, 400, 'Faltan datos de contratista', 'VALIDATION_ERROR');
  }

  if (!contraseña) {
    return sendError(res, 400, 'La contraseña es obligatoria', 'VALIDATION_ERROR');
  }

  const usuarioExistente = await User.findOne({ correo });
  if (usuarioExistente) {
    return sendError(res, 409, 'El correo ya está registrado', 'USER_ALREADY_EXISTS');
  }

  const hash = await bcrypt.hash(contraseña, 10);

  const nuevoUsuario = await User.create({
    nombre,
    correo,
    contraseña: hash,
    tipoUsuario,
    telefono,
    empresa,
    empresaAfiliada: empresaAfiliadaNormalizada,
    licenciaExpedicion: fechaLicencia,
    licenciaVencimiento: fechaLicencia,
    numeroCedula,
    camion: camionNormalizado || camion,
    metodoPago,
    disponibleParaSolicitarCamioneros
  });

  if (tipoUsuario === 'camionero' && camionNormalizado) {
    await Vehiculo.findOneAndUpdate(
      { camioneroId: nuevoUsuario._id },
      {
        camioneroId: nuevoUsuario._id,
        tipoVehiculo: camionNormalizado.tipoVehiculo,
        capacidadCarga: Number(camionNormalizado.capacidadCarga),
        unidadCapacidad: camionNormalizado.unidadCapacidad,
        marca: camionNormalizado.marca,
        modelo: camionNormalizado.modelo,
        placa: camionNormalizado.placa,
        papelesAlDia: camionNormalizado.papelesAlDia ?? true,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
  }

  return sendAuthResponse(res, 201, 'Usuario registrado correctamente', nuevoUsuario);
  
});

// Registro de un nuevo usuario (rutas en español e inglés)
router.post('/registro', handleRegistro);
router.post('/register', handleRegistro);

router.post('/google', asyncHandler(async (req, res) => {
  const idToken = String(req.body.idToken || '').trim();
  if (!idToken) {
    return sendError(res, 400, 'idToken de Google es obligatorio', 'VALIDATION_ERROR');
  }

  let googleProfile;
  try {
    googleProfile = await verifyGoogleIdToken(idToken);
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 401,
      error.statusCode === 503 ? error.message : 'No se pudo validar la cuenta de Google',
      error.code || 'GOOGLE_TOKEN_INVALID'
    );
  }

  let usuario = await User.findOne({
    $or: [
      { googleSub: googleProfile.googleSub },
      { correo: googleProfile.correo },
    ],
  });

  if (!usuario) {
    usuario = await User.create({
      nombre: googleProfile.nombre,
      correo: googleProfile.correo,
      authProvider: 'google',
      googleSub: googleProfile.googleSub,
      fotoPerfil: googleProfile.fotoPerfil,
      tipoUsuario: 'usuario',
      rolConfigurado: false,
      estadoAprobacion: 'aprobado',
    });
  } else {
    usuario.authProvider = usuario.authProvider || 'google';
    usuario.googleSub = usuario.googleSub || googleProfile.googleSub;
    usuario.fotoPerfil = googleProfile.fotoPerfil || usuario.fotoPerfil;
    usuario.nombre = usuario.nombre || googleProfile.nombre;
    if (usuario.tipoUsuario !== 'usuario') {
      usuario.rolConfigurado = true;
    }
    await usuario.save();
  }

  return sendAuthResponse(res, 200, 'Inicio de sesion con Google correcto', usuario);
}));

router.post('/simulation', asyncHandler(async (req, res) => {
  return sendAuthResponse(
    res,
    200,
    'Sesión de simulación creada localmente',
    buildSimulationUser()
  );
}));

router.put('/role', verificarToken, asyncHandler(async (req, res) => {
  const tipoUsuario = normalizeText(req.body.tipoUsuario || req.body.rol);
  if (!OPERATIONAL_ROLES.has(tipoUsuario)) {
    return sendError(res, 400, 'Rol operativo invalido', 'VALIDATION_ERROR');
  }

  const usuario = await User.findById(req.usuario.id);
  if (!usuario) {
    return sendError(res, 404, 'Usuario no encontrado', 'USER_NOT_FOUND');
  }

  if (usuario.rolConfigurado && usuario.tipoUsuario !== 'usuario' && usuario.tipoUsuario !== tipoUsuario) {
    return sendError(res, 409, 'El rol ya fue configurado para esta cuenta', 'ROLE_ALREADY_CONFIGURED');
  }

  usuario.tipoUsuario = tipoUsuario;
  usuario.rolConfigurado = true;
  if (tipoUsuario === 'cliente') {
    usuario.estadoAprobacion = 'aprobado';
  }
  await usuario.save();

  return sendAuthResponse(res, 200, 'Rol configurado correctamente', usuario);
}));

// Login de un usuario
router.post('/login', asyncHandler(async (req, res) => {
  const { correo, contraseña } = req.body;

  if (!correo || !contraseña) {
    return sendError(res, 400, 'Correo y contraseña son obligatorios', 'VALIDATION_ERROR');
  }

  const usuario = await User.findOne({ correo });
  if (!usuario) {
    return sendError(res, 401, 'Credenciales inválidas', 'INVALID_CREDENTIALS');
  }

  if (!usuario.contraseña) {
    return sendError(res, 401, 'Esta cuenta debe ingresar con Google', 'GOOGLE_ACCOUNT_REQUIRED');
  }

  const coincide = await bcrypt.compare(contraseña, usuario.contraseña);
  if (!coincide) {
    return sendError(res, 401, 'Credenciales inválidas', 'INVALID_CREDENTIALS');
  }

  return sendAuthResponse(res, 200, 'Inicio de sesión correcto', usuario);
}));

// Obtener perfil del usuario autenticado
router.get('/perfil', verificarToken, asyncHandler(async (req, res) => {
  if (req.usuario.isSimulation) {
    return res.json({ usuario: sanitizeUser(buildSimulationUser()) });
  }

  const usuario = await User.findById(req.usuario.id).select('-contraseña');
  if (!usuario) {
    return sendError(res, 404, 'Usuario no encontrado', 'USER_NOT_FOUND');
  }

  return res.json({ usuario: sanitizeUser(usuario) });
}));

router.put('/perfil', verificarToken, asyncHandler(async (req, res) => {
  const usuario = await User.findById(req.usuario.id);
  if (!usuario) {
    return sendError(res, 404, 'Usuario no encontrado', 'USER_NOT_FOUND');
  }

  const allowedFields = [
    'nombre',
    'telefono',
    'empresa',
    'fotoPerfil',
    'descripcionOperacion',
    'anioFundacion',
    'ubicacionEmpresa',
    'sitioWeb',
    'metodosPago',
  ];

  for (const field of allowedFields) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      usuario[field] = req.body[field];
    }
  }

  await usuario.save();
  return res.json({ mensaje: 'Perfil actualizado', usuario: sanitizeUser(usuario) });
}));

// Actualizar el método de pago del usuario
router.put('/actualizar-pago', verificarToken, asyncHandler(async (req, res) => {
  const { metodoPago } = req.body;

  // Validar el método de pago
  if (!['Visa', 'Nequi', 'Efectivo', 'Transferencia bancaria', 'Daviplata'].includes(metodoPago)) {
    return sendError(res, 400, 'Método de pago inválido', 'VALIDATION_ERROR');
  }

  const usuario = await User.findById(req.usuario.id);
  if (!usuario) {
    return sendError(res, 404, 'Usuario no encontrado', 'USER_NOT_FOUND');
  }

  usuario.metodoPago = metodoPago;
  await usuario.save();

  return res.json({ mensaje: 'Método de pago actualizado', usuario: sanitizeUser(usuario) });
}));

router.use((err, req, res, next) => {
  if (res.headersSent) return next(err);

  if (err?.name === 'ValidationError') {
    const mensaje = Object.values(err.errors || {})
      .map((error) => error.message)
      .filter(Boolean)
      .join('. ') || 'Datos inválidos';
    return sendError(res, 400, mensaje, 'VALIDATION_ERROR');
  }

  if (err?.code === 11000) {
    return sendError(res, 409, 'El correo ya está registrado', 'USER_ALREADY_EXISTS');
  }

  return next(err);
});

module.exports = router;

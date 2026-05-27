const express = require('express');
const router = express.Router();
const User = require('../models/User');
const bcrypt = require('bcrypt');
const verificarToken = require('../middleware/authMiddleware');
const asyncHandler = require('../middleware/asyncHandler');
const { sendError } = require('../middleware/errorMiddleware');
const { buildAuthToken, sanitizeUser } = require('../utils/auth');

const VEHICLE_TYPES = new Set([
  'bus',
  'buseta',
  'piaggio',
  'camion de carga',
  'volqueta',
  'camion piaggio',
]);

const CAPACITY_UNITS = new Set(['kg', 'pasajeros']);

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

  return sendAuthResponse(res, 201, 'Usuario registrado correctamente', nuevoUsuario);
});

// Registro de un nuevo usuario (rutas en español e inglés)
router.post('/registro', handleRegistro);
router.post('/register', handleRegistro);

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

  const coincide = await bcrypt.compare(contraseña, usuario.contraseña);
  if (!coincide) {
    return sendError(res, 401, 'Credenciales inválidas', 'INVALID_CREDENTIALS');
  }

  return sendAuthResponse(res, 200, 'Inicio de sesión correcto', usuario);
}));

// Obtener perfil del usuario autenticado
router.get('/perfil', verificarToken, asyncHandler(async (req, res) => {
  const usuario = await User.findById(req.usuario.id).select('-contraseña');
  if (!usuario) {
    return sendError(res, 404, 'Usuario no encontrado', 'USER_NOT_FOUND');
  }

  return res.json({ usuario: sanitizeUser(usuario) });
}));

// Actualizar el método de pago del usuario
router.put('/actualizar-pago', verificarToken, asyncHandler(async (req, res) => {
  const { metodoPago } = req.body;

  // Validar el método de pago
  if (!['Visa', 'Nequi', 'Efectivo'].includes(metodoPago)) {
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

module.exports = router;

const express = require('express');
const router = express.Router();
const {
  crearOportunidad,
  listarOportunidades,
  asignarCamionero,
  finalizarCarga,
  enviarOfertaPrecio,
  cancelarOfertaPrecio,
  enviarContraofertaPrecio,
  aceptarContraofertaPrecio,
} = require('../controllers/oportunidadController');
const verificarToken = require('../middleware/authMiddleware');
const soloRol = require('../middleware/rolMiddleware');

// Crear oportunidad (contratistas)
router.post('/crear', verificarToken, soloRol(['contratista', 'camionero']), crearOportunidad);

// Listar todas las oportunidades (ruta principal)
router.get('/', verificarToken, listarOportunidades);

// Listar oportunidades disponibles (pueden verlas todos los autenticados)
router.get('/disponibles', verificarToken, listarOportunidades);

// Asignar camionero a oportunidad (cualquier camionero puede aceptar)
router.post('/asignar/:id', verificarToken, soloRol('camionero'), asignarCamionero);

// Aceptar oportunidad (nuevo endpoint con validaciones)
router.put('/:id/aceptar', verificarToken, soloRol('camionero'), require('../controllers/oportunidadController').aceptarOportunidad);

// Negociación de precio
router.post('/:id/oferta', verificarToken, soloRol('camionero'), enviarOfertaPrecio);
router.delete('/:id/oferta', verificarToken, soloRol(['camionero', 'contratista']), cancelarOfertaPrecio);
router.post('/:id/contraoferta', verificarToken, soloRol('contratista'), enviarContraofertaPrecio);
router.put('/:id/contraoferta/aceptar', verificarToken, soloRol('camionero'), aceptarContraofertaPrecio);

// Obtener viaje activo del camionero
router.get('/viaje-activo', verificarToken, soloRol('camionero'), require('../controllers/oportunidadController').obtenerViajeActivo);

// Iniciar viaje (cambiar estado a en_ruta)
router.put('/:id/iniciar', verificarToken, soloRol('camionero'), require('../controllers/oportunidadController').iniciarViaje);

// Finalizar una carga (solo contratista)
router.post('/finalizar/:id', verificarToken, soloRol('contratista'), finalizarCarga);

module.exports = router;

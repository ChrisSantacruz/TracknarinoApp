const Oportunidad = require('../models/Oportunidad');
const User = require('../models/User');
const { enviarNotificacionFCM } = require('../services/fcmService');
const { getOriginDestinationPayload } = require('../utils/geoValidation');
const { publishTripStateChanged } = require('../services/tripEventService');
const Offer = require('../models/Offer');
const {
  buildOpportunityListFilter,
  getOwnerId,
  isOpportunityOwner,
  roleToOwnerType,
} = require('../services/opportunityAccessService');
const {
  createOffer,
  listOffersForOpportunity,
  acceptOffer,
  rejectOffer,
} = require('../services/offerService');

const ACTIVE_TRIP_STATES = ['asignada', 'aceptada', 'en_ruta'];
const TERMINAL_TRIP_STATES = ['entregada', 'cancelada'];
const ALLOWED_TRANSITIONS = {
  disponible: ['asignada', 'aceptada', 'cancelada'],
  asignada: ['aceptada', 'en_ruta', 'cancelada'],
  aceptada: ['en_ruta', 'cancelada'],
  en_ruta: ['entregada', 'cancelada'],
  entregada: [],
  cancelada: [],
};

function setTripState(oportunidad, nextState) {
  const currentState = oportunidad.estado === 'finalizada' ? 'entregada' : oportunidad.estado;
  const previousState = currentState;

  if (currentState === nextState) {
    return;
  }

  if (TERMINAL_TRIP_STATES.includes(currentState)) {
    const error = new Error(`No se puede modificar una carga en estado ${currentState}`);
    error.statusCode = 400;
    throw error;
  }

  const allowed = ALLOWED_TRANSITIONS[currentState] || [];
  if (!allowed.includes(nextState)) {
    const error = new Error(`Transición inválida: ${currentState} -> ${nextState}`);
    error.statusCode = 400;
    throw error;
  }

  oportunidad.estado = nextState;
  oportunidad.estadoTimestamps = oportunidad.estadoTimestamps || {};
  oportunidad.estadoTimestamps[nextState] = new Date();

  if (nextState === 'entregada') {
    oportunidad.finalizada = true;
  }

  return previousState;
}

function routeLabel(oportunidad) {
  const origen = oportunidad.origin?.name || oportunidad.origen || 'origen sin nombre';
  const destino = oportunidad.destination?.name || oportunidad.destino || 'destino sin nombre';
  return `${origen} a ${destino}`;
}

function parsePositiveMoney(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

async function populateOpportunityDetails(oportunidad) {
  await oportunidad.populate('camioneroAsignado', 'nombre correo telefono camion');
  await oportunidad.populate('contratista', 'nombre correo telefono empresa');
  await oportunidad.populate('ownerId', 'nombre correo telefono empresa fotoPerfil tipoUsuario');
  await oportunidad.populate('negociacion.camionero', 'nombre correo telefono camion');
  return oportunidad;
}

// Crear oportunidad (contratista o camionero)
const crearOportunidad = async (req, res) => {
  try {
    const geoPayload = getOriginDestinationPayload(req.body);
    if (geoPayload.error) {
      return res.status(400).json({ error: geoPayload.error, mensaje: geoPayload.error });
    }

    const datosOportunidad = {
      titulo: req.body.titulo,
      descripcion: req.body.descripcion,
      origin: geoPayload.origin,
      destination: geoPayload.destination,
      origen: geoPayload.origin.name,
      destino: geoPayload.destination.name,
      direccionCargue: geoPayload.origin.address,
      direccionDescargue: geoPayload.destination.address,
      fecha: req.body.fecha,
      precio: req.body.precio,
      pesoCarga: req.body.pesoCarga,
      tipoCarga: req.body.tipoCarga,
      requisitosEspeciales: req.body.requisitosEspeciales,
      ownerType: roleToOwnerType(req.usuario.tipoUsuario),
      ownerId: req.usuario.id,
      createdBy: req.usuario.id,
      createdByRole: req.usuario.tipoUsuario,
      contratista: req.usuario.tipoUsuario === 'contratista' ? req.usuario.id : undefined,
      estado: 'disponible',
      finalizada: false,
      geoMigration: {
        status: 'resolved',
        source: 'api',
        routable: true,
        missingFields: [],
        reviewedAt: new Date(),
      },
      estadoTimestamps: {
        disponible: new Date(),
      },
    };
    
    const oportunidad = new Oportunidad(datosOportunidad);
    await oportunidad.save();
    
    // Opcionalmente, enviar notificaciones a camioneros disponibles
    try {
      if (req.usuario.tipoUsuario === 'contratista' || req.usuario.tipoUsuario === 'cliente') {
        const camioneros = await User.find({ 
          tipoUsuario: 'camionero', 
          deviceToken: { $exists: true, $ne: '' },
          disponible: true 
        });
        const contratista = await User.findById(req.usuario.id).select('nombre');
        
        // Enviar notificación a cada camionero
        for (const camionero of camioneros) {
          if (camionero.deviceToken) {
            await enviarNotificacionFCM(
              camionero.deviceToken, 
              'Nueva oportunidad disponible', 
              `${contratista?.nombre || 'Un usuario'} ha publicado una nueva carga de ${routeLabel(oportunidad)}`
            );
          }
        }
      }
    } catch (notifError) {
      console.error('Error al enviar notificaciones:', notifError.message);
      // Continuamos aunque falle el envío de notificaciones
    }
    
    res.status(201).json({ 
      mensaje: 'Oportunidad creada', 
      oportunidad 
    });
  } catch (error) {
    console.error('Error al crear oportunidad:', error.message);
    res.status(500).json({
      mensaje: 'Error al crear oportunidad',
      error: 'Error al crear oportunidad',
    });
  }
};

// Listar oportunidades disponibles (pueden verlas todos los autenticados)
const listarOportunidades = async (req, res) => {
  try {
    const filter = buildOpportunityListFilter(req.usuario, req.query.ownerType);

    const oportunidades = await Oportunidad.find(filter)
      .sort({ createdAt: -1 })
      .populate('contratista', 'nombre correo telefono empresa')
      .populate('ownerId', 'nombre correo telefono empresa fotoPerfil tipoUsuario')
      .populate('camioneroAsignado', 'nombre correo telefono camion')
      .populate('negociacion.camionero', 'nombre correo telefono camion');
    res.json(oportunidades);
  } catch (error) {
    res.status(500).json({ error: 'Error al listar oportunidades' });
  }
};

const aceptarOfertaCamionero = async (req, res) => {
  try {
    const oportunidad = await Oportunidad.findById(req.params.id);
    if (!oportunidad) {
      return res.status(404).json({ error: 'Oportunidad no encontrada' });
    }
    if (!isOpportunityOwner(oportunidad, req.usuario)) {
      return res.status(403).json({ error: 'Solo el propietario puede aceptar esta oferta' });
    }
    if (oportunidad.estado !== 'disponible') {
      return res.status(400).json({ error: 'Esta carga ya no está disponible para negociación' });
    }
    const pendingOffer = await Offer.findOne({
      oportunidad: oportunidad._id,
      estado: 'pendiente',
    }).sort({ precio: 1, createdAt: 1 });
    if (pendingOffer) {
      const result = await acceptOffer({ offerId: pendingOffer._id, user: req.usuario });
      await populateOpportunityDetails(result.oportunidad);
      return res.json({
        mensaje: 'Oferta aceptada. Viaje asignado al camionero.',
        oportunidad: result.oportunidad,
        offer: result.offer,
      });
    }
    if (oportunidad.negociacion?.estado !== 'oferta_camionero') {
      return res.status(400).json({ error: 'No hay oferta de camionero pendiente por aceptar' });
    }

    const camioneroId = oportunidad.negociacion.camionero?.toString();
    if (!camioneroId) {
      return res.status(400).json({ error: 'La oferta no tiene camionero asociado' });
    }

    const viajeActivo = await Oportunidad.findOne({
      camioneroAsignado: camioneroId,
      estado: { $in: ACTIVE_TRIP_STATES }
    });
    if (viajeActivo) {
      return res.status(400).json({ error: 'El camionero ya tiene un viaje activo' });
    }

    oportunidad.precio = oportunidad.negociacion.precioOfertado || oportunidad.precio;
    oportunidad.camioneroAsignado = camioneroId;
    oportunidad.negociacion.estado = 'aceptada';
    oportunidad.negociacion.ultimaAccionPor = req.usuario.id;
    oportunidad.negociacion.ultimaAccionRol = req.usuario.tipoUsuario;
    oportunidad.negociacion.updatedAt = new Date();
    const previousState = setTripState(oportunidad, 'aceptada');

    await oportunidad.save();
    await publishTripStateChanged(oportunidad, previousState);
    await populateOpportunityDetails(oportunidad);
    return res.json({ mensaje: 'Oferta aceptada. Viaje asignado al camionero.', oportunidad });
  } catch (error) {
    console.error('Error al aceptar oferta de camionero:', error);
    return res.status(error.statusCode || 500).json({
      error: error.statusCode ? error.message : 'Error al aceptar oferta de camionero',
    });
  }
};

const enviarOfertaPrecio = async (req, res) => {
  try {
    const { oportunidad, offer } = await createOffer({
      oportunidadId: req.params.id,
      camioneroId: req.usuario.id,
      precio: req.body.precioOfertado ?? req.body.precio,
      comentario: req.body.mensaje ?? req.body.comentario,
    });
    await populateOpportunityDetails(oportunidad);
    return res.json({ mensaje: 'Oferta enviada', oportunidad, offer });
  } catch (error) {
    console.error('Error al enviar oferta:', error);
    return res.status(error.statusCode || 500).json({ error: error.statusCode ? error.message : 'Error al enviar oferta' });
  }
};

const listarOfertas = async (req, res) => {
  try {
    const { offers } = await listOffersForOpportunity({
      oportunidadId: req.params.id,
      user: req.usuario,
    });
    return res.json({ offers });
  } catch (error) {
    return res.status(error.statusCode || 500).json({
      error: error.statusCode ? error.message : 'Error al listar ofertas',
    });
  }
};

const aceptarOferta = async (req, res) => {
  try {
    const { oportunidad, offer } = await acceptOffer({
      offerId: req.params.offerId,
      user: req.usuario,
    });
    await populateOpportunityDetails(oportunidad);
    return res.json({ mensaje: 'Oferta aceptada. Viaje asignado.', oportunidad, offer });
  } catch (error) {
    return res.status(error.statusCode || 500).json({
      error: error.statusCode ? error.message : 'Error al aceptar oferta',
    });
  }
};

const rechazarOferta = async (req, res) => {
  try {
    const { oportunidad, offer } = await rejectOffer({
      offerId: req.params.offerId,
      user: req.usuario,
    });
    return res.json({ mensaje: 'Oferta rechazada', oportunidad, offer });
  } catch (error) {
    return res.status(error.statusCode || 500).json({
      error: error.statusCode ? error.message : 'Error al rechazar oferta',
    });
  }
};

const cancelarOfertaPrecio = async (req, res) => {
  try {
    const oportunidad = await Oportunidad.findById(req.params.id);
    if (!oportunidad) {
      return res.status(404).json({ error: 'Oportunidad no encontrada' });
    }

    const esCamioneroOferta = oportunidad.negociacion?.camionero?.toString() === req.usuario.id;
    const esContratista = oportunidad.contratista.toString() === req.usuario.id;
    if (!esCamioneroOferta && !esContratista) {
      return res.status(403).json({ error: 'No tienes permisos para cancelar esta negociación' });
    }

    oportunidad.negociacion = {
      ...(oportunidad.negociacion?.toObject?.() || oportunidad.negociacion || {}),
      estado: 'cancelada',
      ultimaAccionPor: req.usuario.id,
      ultimaAccionRol: req.usuario.tipoUsuario,
      updatedAt: new Date(),
    };

    await oportunidad.save();
    await populateOpportunityDetails(oportunidad);
    return res.json({ mensaje: 'Oferta cancelada', oportunidad });
  } catch (error) {
    console.error('Error al cancelar oferta:', error);
    return res.status(500).json({ error: 'Error al cancelar oferta' });
  }
};

const enviarContraofertaPrecio = async (req, res) => {
  try {
    const precioContraoferta = parsePositiveMoney(req.body.precioContraoferta);
    if (!precioContraoferta) {
      return res.status(400).json({ error: 'La contraoferta debe ser mayor a cero' });
    }

    const oportunidad = await Oportunidad.findById(req.params.id);
    if (!oportunidad) {
      return res.status(404).json({ error: 'Oportunidad no encontrada' });
    }
    if (oportunidad.contratista.toString() !== req.usuario.id) {
      return res.status(403).json({ error: 'Solo el contratista puede contraofertar' });
    }
    if (!oportunidad.negociacion?.camionero) {
      return res.status(400).json({ error: 'No hay oferta de camionero para responder' });
    }

    oportunidad.negociacion = {
      ...(oportunidad.negociacion?.toObject?.() || oportunidad.negociacion || {}),
      estado: 'contraoferta_contratista',
      precioContraoferta,
      ultimaAccionPor: req.usuario.id,
      ultimaAccionRol: 'contratista',
      mensaje: req.body.mensaje,
      updatedAt: new Date(),
    };

    await oportunidad.save();
    await populateOpportunityDetails(oportunidad);
    return res.json({ mensaje: 'Contraoferta enviada', oportunidad });
  } catch (error) {
    console.error('Error al enviar contraoferta:', error);
    return res.status(500).json({ error: 'Error al enviar contraoferta' });
  }
};

const aceptarContraofertaPrecio = async (req, res) => {
  try {
    const oportunidad = await Oportunidad.findById(req.params.id);
    if (!oportunidad) {
      return res.status(404).json({ error: 'Oportunidad no encontrada' });
    }
    if (oportunidad.estado !== 'disponible') {
      return res.status(400).json({ error: 'Esta carga ya no está disponible' });
    }
    if (oportunidad.negociacion?.estado !== 'contraoferta_contratista') {
      return res.status(400).json({ error: 'No hay contraoferta pendiente' });
    }
    if (oportunidad.negociacion.camionero?.toString() !== req.usuario.id) {
      return res.status(403).json({ error: 'Solo el camionero ofertante puede aceptar la contraoferta' });
    }

    const viajeActivo = await Oportunidad.findOne({
      camioneroAsignado: req.usuario.id,
      estado: { $in: ACTIVE_TRIP_STATES }
    });
    if (viajeActivo) {
      return res.status(400).json({ error: 'Ya tienes un viaje activo. Finaliza tu viaje actual antes de aceptar otra carga.' });
    }

    oportunidad.precio = oportunidad.negociacion.precioContraoferta;
    oportunidad.camioneroAsignado = req.usuario.id;
    oportunidad.negociacion.estado = 'aceptada';
    oportunidad.negociacion.ultimaAccionPor = req.usuario.id;
    oportunidad.negociacion.ultimaAccionRol = 'camionero';
    oportunidad.negociacion.updatedAt = new Date();
    const previousState = setTripState(oportunidad, 'aceptada');
    await oportunidad.save();
    await publishTripStateChanged(oportunidad, previousState);
    await populateOpportunityDetails(oportunidad);
    return res.json({ mensaje: 'Contraoferta aceptada', oportunidad });
  } catch (error) {
    console.error('Error al aceptar contraoferta:', error);
    return res.status(error.statusCode || 500).json({ error: error.statusCode ? error.message : 'Error al aceptar contraoferta' });
  }
};

// Asignar camionero a oportunidad (cualquier camionero puede aceptar)
const asignarCamionero = async (req, res) => {
  try {
    const { id } = req.params;
    const camioneroId = req.usuario.id; // Obtener el ID del camionero desde el token de autenticación

    const oportunidad = await Oportunidad.findById(id);

    if (!oportunidad || oportunidad.estado !== 'disponible') {
      return res.status(400).json({ error: 'Oportunidad no disponible para asignación' });
    }

    oportunidad.camioneroAsignado = camioneroId;
    const previousState = setTripState(oportunidad, 'aceptada');
    await oportunidad.save();
    await publishTripStateChanged(oportunidad, previousState);

    // Enviar notificación al camionero si tiene token FCM
    const camionero = await User.findById(camioneroId);
    if (camionero?.deviceToken) {
      await enviarNotificacionFCM(
        camionero.deviceToken,
        '📦 Nueva carga aceptada',
        `Has aceptado una carga de ${routeLabel(oportunidad)}.`
      );
    }

    res.json({ mensaje: 'Carga aceptada', oportunidad });
  } catch (error) {
    res.status(500).json({ error: 'Error al aceptar la carga' });
  }
};

// Finalizar carga (solo contratista)
const finalizarCarga = async (req, res) => {
  try {
    const carga = await Oportunidad.findById(req.params.id);

    if (!carga || carga.contratista.toString() !== req.usuario.id) {
      return res.status(403).json({ error: 'No tienes permisos para finalizar esta carga' });
    }

    const previousState = setTripState(carga, 'entregada');
    await carga.save();
    await publishTripStateChanged(carga, previousState);

    // Notificación al camionero
    const camionero = await User.findById(carga.camioneroAsignado);
    if (camionero?.deviceToken) {
      await enviarNotificacionFCM(
        camionero.deviceToken,
        '✔️ Carga finalizada',
        `La carga de ${routeLabel(carga)} ha sido entregada.`
      );
    }

    res.json({ mensaje: 'Carga entregada correctamente', carga });
  } catch (error) {
    res.status(error.statusCode || 500).json({ error: error.statusCode ? error.message : 'Error al finalizar la carga' });
  }
};

// Aceptar oportunidad (verifica estado del camionero)
const aceptarOportunidad = async (req, res) => {
  try {
    const { id } = req.params;
    const camioneroId = req.usuario.id;

    // Verificar que el camionero no tenga viajes activos
    const viajeActivo = await Oportunidad.findOne({
      camioneroAsignado: camioneroId,
      estado: { $in: ACTIVE_TRIP_STATES }
    });

    if (viajeActivo) {
      return res.status(400).json({ 
        error: 'Ya tienes un viaje activo. Finaliza tu viaje actual antes de aceptar otra carga.',
        viajeActivo 
      });
    }

    const oportunidad = await Oportunidad.findById(id);

    if (!oportunidad) {
      return res.status(404).json({ error: 'Oportunidad no encontrada' });
    }

    if (
      oportunidad.estado !== 'disponible' &&
      oportunidad.camioneroAsignado?.toString() === camioneroId &&
      ACTIVE_TRIP_STATES.includes(oportunidad.estado)
    ) {
      await oportunidad.populate('camioneroAsignado', 'nombre correo telefono');
      await oportunidad.populate('contratista', 'nombre correo');
      return res.json({
        mensaje: 'Carga ya aceptada por este camionero',
        oportunidad,
        duplicate: true,
      });
    }

    if (oportunidad.estado !== 'disponible') {
      return res.status(400).json({ error: 'Esta oportunidad ya fue aceptada por otro camionero' });
    }

    oportunidad.camioneroAsignado = camioneroId;
    const previousState = setTripState(oportunidad, 'aceptada');
    await oportunidad.save();
    await publishTripStateChanged(oportunidad, previousState);

    // Poblar datos del camionero y contratista
    await oportunidad.populate('camioneroAsignado', 'nombre correo telefono');
    await oportunidad.populate('contratista', 'nombre correo');

    // Notificación al contratista
    const contratista = await User.findById(oportunidad.contratista);
    if (contratista?.deviceToken) {
      const camionero = await User.findById(camioneroId);
      await enviarNotificacionFCM(
        contratista.deviceToken,
        '✅ Carga aceptada',
        `${camionero.nombre} ha aceptado tu carga de ${routeLabel(oportunidad)}.`
      );
    }

    res.json({ mensaje: 'Carga aceptada exitosamente', oportunidad });
  } catch (error) {
    console.error('Error al aceptar oportunidad:', error);
    res.status(500).json({ error: 'Error al aceptar la carga' });
  }
};

// Obtener viaje activo del camionero
const obtenerViajeActivo = async (req, res) => {
  try {
    const camioneroId = req.usuario.id;

    const viajeActivo = await Oportunidad.findOne({
      camioneroAsignado: camioneroId,
      estado: { $in: ACTIVE_TRIP_STATES }
    })
    .populate('contratista', 'nombre correo telefono')
    .populate('camioneroAsignado', 'nombre correo');

    if (!viajeActivo) {
      return res.json({ viajeActivo: null });
    }

    res.json({ viajeActivo });
  } catch (error) {
    console.error('Error al obtener viaje activo:', error);
    res.status(500).json({ error: 'Error al obtener viaje activo' });
  }
};

// Iniciar viaje (cambiar estado a en_ruta)
const iniciarViaje = async (req, res) => {
  try {
    const { id } = req.params;
    const camioneroId = req.usuario.id;

    const oportunidad = await Oportunidad.findById(id);

    if (!oportunidad) {
      return res.status(404).json({ error: 'Oportunidad no encontrada' });
    }

    if (oportunidad.camioneroAsignado.toString() !== camioneroId) {
      return res.status(403).json({ error: 'No tienes permisos para iniciar este viaje' });
    }

    // Permitir confirmar si ya está en ruta, pero no saltar estados imposibles.
    if (!['asignada', 'aceptada', 'en_ruta'].includes(oportunidad.estado)) {
      return res.status(400).json({ error: 'Este viaje no está en estado válido para iniciar' });
    }

    if (oportunidad.estado !== 'en_ruta') {
      const previousState = setTripState(oportunidad, 'en_ruta');
      await oportunidad.save();
      await publishTripStateChanged(oportunidad, previousState);
    }

    res.json({ mensaje: 'Viaje iniciado', oportunidad });
  } catch (error) {
    console.error('Error al iniciar viaje:', error);
    res.status(500).json({ error: 'Error al iniciar viaje' });
  }
};

module.exports = {
  crearOportunidad,
  listarOportunidades,
  asignarCamionero,
  finalizarCarga,
  aceptarOportunidad,
  listarOfertas,
  aceptarOferta,
  rechazarOferta,
  enviarOfertaPrecio,
  cancelarOfertaPrecio,
  enviarContraofertaPrecio,
  aceptarOfertaCamionero,
  aceptarContraofertaPrecio,
  obtenerViajeActivo,
  iniciarViaje
};

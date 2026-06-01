const User = require('../models/User');

const Oportunidad = require('../models/Oportunidad');

const UbicacionActual = require('../models/UbicacionActual');

const { getTrackingStatusFromLocation } = require('../services/trackingService');

const { isValidCoordinatePair } = require('../utils/geoValidation');

const { ACTIVE_TRIP_STATES } = require('../config/trackingPolicy');

const { parseBboxQuery, bboxMongoFilter } = require('../services/routeGeospatialService');



// Afiliar camionero a contratista (canonical: camionero id en lista del contratista)

const afiliarCamionero = async (req, res) => {

  try {

    const camioneroId = req.params.id;

    const contratistaId = req.usuario.id;



    const [camionero, contratista] = await Promise.all([

      User.findById(camioneroId),

      User.findById(contratistaId),

    ]);



    if (!camionero || camionero.tipoUsuario !== 'camionero') {

      return res.status(404).json({ error: 'Camionero no encontrado' });

    }



    if (!contratista) {

      return res.status(404).json({ error: 'Contratista no encontrado' });

    }



    const yaAfiliado = contratista.camionerosAfiliados.some(

      (id) => id.toString() === camioneroId,

    );



    if (yaAfiliado) {

      return res.status(400).json({ error: 'El camionero ya está afiliado a este contratista' });

    }



    contratista.camionerosAfiliados.push(camioneroId);

    await contratista.save();



    res.json({ mensaje: 'Camionero afiliado correctamente', camionero });

  } catch (error) {

    res.status(500).json({ error: 'Error al afiliar al camionero' });

  }

};



const rechazarAfiliacion = async (req, res) => {

  try {

    const camioneroId = req.params.id;

    const contratistaId = req.usuario.id;



    const contratista = await User.findById(contratistaId);

    if (!contratista) {

      return res.status(404).json({ error: 'Contratista no encontrado' });

    }



    const index = contratista.camionerosAfiliados.findIndex(

      (id) => id.toString() === camioneroId,

    );

    if (index > -1) {

      contratista.camionerosAfiliados.splice(index, 1);

      await contratista.save();

    }



    res.json({ mensaje: 'Afiliación rechazada' });

  } catch (error) {

    res.status(500).json({ error: 'Error al rechazar la afiliación' });

  }

};



const obtenerFlotaTracking = async (req, res) => {

  try {

    const actorId = req.usuario.id;
    const isCliente = req.usuario.tipoUsuario === 'cliente';
    const bbox = parseBboxQuery(req.query);
    const limit = Math.min(Number(req.query.limit) || 250, 500);
    const page = Math.max(Number(req.query.page) || 1, 1);
    const activeOnly = req.query.activeOnly === 'true' || req.query.status === 'active';
    const staleOnly = req.query.staleOnly === 'true' || req.query.status === 'stale';
    const offlineOnly = req.query.offlineOnly === 'true' || req.query.status === 'offline';
    const activeTripOnly = req.query.activeTripOnly === 'true';

    const contratista = isCliente ? null : await User.findById(actorId)

      .select('camionerosAfiliados');



    const camionerosPorAfiliacionDirecta = contratista?.camionerosAfiliados || [];

    const camionerosPorAfiliacionLegada = isCliente ? [] : await User.find({

      tipoUsuario: 'camionero',

      camionerosAfiliados: actorId,

    }).select('_id nombre correo telefono camion');



    const activeTrips = await Oportunidad.find({
      estado: { $in: ACTIVE_TRIP_STATES },
      ...(isCliente
        ? { ownerId: actorId, ownerType: 'CLIENTE' }
        : {
          $or: [
            { contratista: actorId },
            { ownerId: actorId },
          ],
        }),
    }).sort({ updatedAt: -1 });

    const assignedDriverId = (trip) => {
      const assigned = trip.camioneroAsignado;
      return assigned?._id?.toString?.() || assigned?.toString?.() || null;
    };



    const camioneroIds = new Set([

      ...camionerosPorAfiliacionDirecta.map((id) => id.toString()),

      ...camionerosPorAfiliacionLegada.map((camionero) => camionero._id.toString()),

      ...activeTrips

        .map(assignedDriverId)

        .filter(Boolean),

    ]);



    const [camionerosDirectos, latestLocations] = await Promise.all([

      User.find({

        _id: { $in: Array.from(camioneroIds) },

        tipoUsuario: 'camionero',

      }).select('nombre correo telefono camion'),

      UbicacionActual.find({

        camionero: { $in: Array.from(camioneroIds) },

        ...(bbox ? bboxMongoFilter(bbox) : {}),

      }),

    ]);



    const camionerosById = new Map(camionerosDirectos.map((camionero) => [

      camionero._id.toString(),

      camionero,

    ]));

    const locationsByCamionero = new Map(latestLocations.map((location) => [

      location.camionero.toString(),

      location,

    ]));



    const activeTripByCamionero = new Map();

    for (const trip of activeTrips) {

      const camioneroAsignadoId = assignedDriverId(trip);

      if (camioneroAsignadoId) {

        activeTripByCamionero.set(camioneroAsignadoId, trip);

      }

    }



    const fleet = Array.from(camioneroIds).map((camioneroId) => {

      const camionero = camionerosById.get(camioneroId);

      const activeTrip = activeTripByCamionero.get(camioneroId);

      const latestLocation = locationsByCamionero.get(camioneroId);

      const tracking = getTrackingStatusFromLocation(latestLocation);

      const coordinatesValid = latestLocation

        ? isValidCoordinatePair(latestLocation.coordinates)

        : false;



      return {

        camionero: camionero ? {

          id: camionero._id,

          nombre: camionero.nombre,

          correo: camionero.correo,

          telefono: camionero.telefono,

          camion: camionero.camion,

        } : {

          id: camioneroId,

        },

        activeTrip,

        latestLocation: latestLocation || null,

        trackingStatus: tracking.trackingStatus,

        lastUpdateAt: tracking.lastSeenAt,

        lastSeenAt: tracking.lastSeenAt,

        serverReceivedAt: tracking.serverReceivedAt,

        ageMs: tracking.ageMs,

        isStale: tracking.isStale,

        isOffline: tracking.isOffline,

        coordinatesValid,

        hasLocation: Boolean(latestLocation),

      };

    }).filter((item) => {
      if (bbox && !item.hasLocation) return false;
      if (activeTripOnly && !item.activeTrip) return false;
      if (activeOnly && item.trackingStatus !== 'active') return false;
      if (staleOnly && item.trackingStatus !== 'stale') return false;
      if (offlineOnly && item.trackingStatus !== 'offline' && item.trackingStatus !== 'no_location') return false;
      return true;
    });

    const paginatedFleet = fleet.slice((page - 1) * limit, page * limit);



    res.json({

      fleet: paginatedFleet,

      polledAt: new Date().toISOString(),

      realtimeTransport: 'polling',

      viewport: bbox,

      clusteringReady: true,

      pagination: {
        page,
        limit,
        returned: paginatedFleet.length,
        total: fleet.length,
        hasMore: page * limit < fleet.length,
      },

    });

  } catch (error) {

    console.error('Error al obtener tracking de flota:', error.message);

    res.status(500).json({ error: 'Error al obtener tracking de flota' });

  }

};



module.exports = {

  afiliarCamionero,

  rechazarAfiliacion,

  obtenerFlotaTracking,

};


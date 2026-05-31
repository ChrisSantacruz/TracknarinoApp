const express = require('express');

const router = express.Router();

const mongoose = require('mongoose');

const UbicacionActual = require('../models/UbicacionActual');

const Oportunidad = require('../models/Oportunidad');

const User = require('../models/User');

const verificarToken = require('../middleware/authMiddleware');

const soloRol = require('../middleware/rolMiddleware');

const asyncHandler = require('../middleware/asyncHandler');

const { sendError } = require('../middleware/errorMiddleware');

const {

  persistLocationUpdate,

  getLocationHistory,

  getTrackingStatusFromLocation,

} = require('../services/trackingService');

const { isValidCoordinatePair } = require('../utils/geoValidation');

const { ACTIVE_TRIP_STATES, PREPARED_HISTORY_TTL_DAYS } = require('../config/trackingPolicy');



async function canContractorViewCamionero(contratistaId, camioneroId) {

  const activeTrip = await Oportunidad.exists({

    contratista: contratistaId,

    camioneroAsignado: camioneroId,

    estado: { $in: ACTIVE_TRIP_STATES },

  });



  if (activeTrip) return true;



  const camionero = await User.exists({

    _id: camioneroId,

    tipoUsuario: 'camionero',

    camionerosAfiliados: contratistaId,

  });



  if (camionero) return true;



  const contratista = await User.exists({

    _id: contratistaId,

    camionerosAfiliados: camioneroId,

  });



  return Boolean(contratista);

}



router.post('/actualizar', verificarToken, soloRol('camionero'), asyncHandler(async (req, res) => {

  try {

    const result = await persistLocationUpdate(req.usuario.id, req.body, {
      simulation: req.usuario.isSimulation === true,
    });



    if (result.skipped) {

      return res.json({

        mensaje: 'Ubicación sin cambios relevantes',

        skipped: true,

        reason: result.reason,

        ubicacionActual: result.ubicacionActual,

        tracking: result.meta,

      });

    }



    res.json({

      mensaje: 'Ubicación actualizada',

      ubicacion: result.ubicacion,

      ubicacionActual: result.ubicacionActual,

      tracking: result.meta,

    });

  } catch (error) {

    if (error.statusCode) {

      return sendError(res, error.statusCode, error.message, 'VALIDATION_ERROR');

    }

    console.error('Error al guardar ubicación:', error.message);

    return sendError(res, 500, 'Error al guardar ubicación');

  }

}));



router.get('/ultima/:idCamionero', verificarToken, soloRol('contratista'), asyncHandler(async (req, res) => {

  const { idCamionero } = req.params;



  if (!mongoose.Types.ObjectId.isValid(idCamionero)) {

    return sendError(res, 400, 'idCamionero inválido', 'VALIDATION_ERROR');

  }



  const autorizado = await canContractorViewCamionero(req.usuario.id, idCamionero);

  if (!autorizado) {

    return sendError(res, 403, 'No tienes permisos para ver este camionero');

  }



  const ultima = await UbicacionActual.findOne({ camionero: idCamionero });



  if (!ultima) {

    return sendError(res, 404, 'No hay ubicación registrada para este camionero', 'NOT_FOUND');

  }



  const tracking = getTrackingStatusFromLocation(ultima);

  const coordinatesValid = isValidCoordinatePair(ultima.coordinates);



  res.json({

    ...ultima.toJSON(),

    tracking,

    coordinatesValid,

  });

}));



router.get('/historial/:idCamionero', verificarToken, soloRol(['contratista', 'camionero']), asyncHandler(async (req, res) => {

  const { idCamionero } = req.params;



  if (!mongoose.Types.ObjectId.isValid(idCamionero)) {

    return sendError(res, 400, 'idCamionero inválido', 'VALIDATION_ERROR');

  }



  if (req.usuario.tipoUsuario === 'camionero' && req.usuario.id !== idCamionero) {

    return sendError(res, 403, 'No tienes permisos para ver este historial');

  }



  if (req.usuario.tipoUsuario === 'contratista') {

    const autorizado = await canContractorViewCamionero(req.usuario.id, idCamionero);

    if (!autorizado) {

      return sendError(res, 403, 'No tienes permisos para ver este historial');

    }

  }



  const historial = await getLocationHistory(idCamionero, {

    since: req.query.since,

    limit: req.query.limit,

  });



  res.json({

    historial,

    retentionPolicy: {

      preparedTtlDays: PREPARED_HISTORY_TTL_DAYS,

      cleanupEnabled: false,

    },

  });

}));



module.exports = router;


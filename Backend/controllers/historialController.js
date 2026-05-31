const Oportunidad = require('../models/Oportunidad');

// Historial de cargas de un camionero
const historialCamionero = async (req, res) => {
  try {
    const cargas = await Oportunidad.find({
      camioneroAsignado: req.usuario.id
    })
      .populate('contratista', 'nombre correo')
      .populate('ownerId', 'nombre correo empresa tipoUsuario');
    res.json(cargas);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener historial de cargas del camionero' });
  }
};

// Historial de asignaciones de un contratista
const historialContratista = async (req, res) => {
  try {
    const asignaciones = await Oportunidad.find({
      $or: [
        { contratista: req.usuario.id },
        { ownerId: req.usuario.id },
      ],
    })
      .populate('camioneroAsignado', 'nombre correo')
      .populate('ownerId', 'nombre correo empresa tipoUsuario');
    res.json(asignaciones);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener historial del contratista' });
  }
};

const historialCliente = async (req, res) => {
  try {
    const cargas = await Oportunidad.find({
      ownerType: 'CLIENTE',
      ownerId: req.usuario.id,
    })
      .populate('camioneroAsignado', 'nombre correo telefono camion')
      .sort({ updatedAt: -1 });
    res.json(cargas);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener historial del cliente' });
  }
};

module.exports = {
  historialCamionero,
  historialContratista,
  historialCliente
};

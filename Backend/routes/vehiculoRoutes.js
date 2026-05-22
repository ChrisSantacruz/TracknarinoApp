const express = require('express');
const router = express.Router();
const Vehiculo = require('../models/Vehiculo');
const verificarToken = require('../middleware/authMiddleware');
const soloRol = require('../middleware/rolMiddleware');

// Registrar vehículo del camionero
router.post('/registrar', verificarToken, soloRol('camionero'), async (req, res) => {
  try {
    const { tipoVehiculo, capacidadCarga, marca, modelo, placa, papelesAlDia } = req.body;

    const vehiculo = new Vehiculo({
      camioneroId: req.usuario.id,
      tipoVehiculo,
      capacidadCarga,
      marca,
      modelo,
      placa,
      papelesAlDia
    });

    await vehiculo.save();

    res.status(201).json({ mensaje: 'Vehículo registrado correctamente', vehiculo });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar el vehículo' });
  }
});

// Obtener vehículo del camionero
router.get('/ver', verificarToken, async (req, res) => {
  try {
    const vehiculo = await Vehiculo.findOne({ camioneroId: req.usuario.id });

    if (!vehiculo) {
      return res.status(404).json({ error: 'No se encontró el vehículo' });
    }

    res.json(vehiculo);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener los datos del vehículo' });
  }
});

module.exports = router;

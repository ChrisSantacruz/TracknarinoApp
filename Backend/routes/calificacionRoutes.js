const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Calificacion = require('../models/Calificacion');
const User = require('../models/User');
const verificarToken = require('../middleware/authMiddleware');

const SIMULATION_DRIVER_ID = process.env.SIMULATION_DRIVER_ID || '65f13d000000000000000013';

// Crear una calificación
router.post('/crear', verificarToken, async (req, res) => {
  try {
    const { usuarioId, tipoServicio, calificacion, comentario } = req.body;

    const score = Number(calificacion);
    if (!usuarioId || !tipoServicio || !Number.isFinite(score)) {
      return res.status(400).json({ error: 'usuarioId, tipoServicio y calificación son obligatorios' });
    }

    if (score < 1 || score > 5) {
      return res.status(400).json({ error: 'La calificación debe estar entre 1 y 5' });
    }

    if (!mongoose.Types.ObjectId.isValid(usuarioId)) {
      return res.status(400).json({ error: 'usuarioId inválido' });
    }

    if (req.usuario?.id?.toString() === usuarioId.toString()) {
      return res.status(400).json({ error: 'No puedes calificarte a ti mismo' });
    }

    const isSimulationTarget = usuarioId.toString() === SIMULATION_DRIVER_ID;
    const usuarioObjetivo = isSimulationTarget
      ? null
      : await User.findById(usuarioId).select('_id tipoUsuario');
    if (!usuarioObjetivo && !isSimulationTarget) {
      return res.status(404).json({ error: 'Usuario a calificar no encontrado' });
    }

    const nuevaCalificacion = new Calificacion({
      usuario: usuarioId,
      tipoServicio,
      calificacion: score,
      comentario
    });

    await nuevaCalificacion.save();

    if (!isSimulationTarget) {
      const [stats] = await Calificacion.aggregate([
        { $match: { usuario: new mongoose.Types.ObjectId(usuarioId) } },
        { $group: { _id: null, promedio: { $avg: '$calificacion' } } },
      ]);

      await User.findByIdAndUpdate(usuarioId, {
        calificacion: stats?.promedio ?? null,
      });
    }

    res.status(201).json({ mensaje: 'Calificación registrada correctamente', nuevaCalificacion });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar la calificación' });
  }
});

// Listar calificaciones de un usuario
router.get('/listar/:id', verificarToken, async (req, res) => {
  try {
    const calificaciones = await Calificacion.find({ usuario: req.params.id })
      .populate('usuario', 'nombre correo');

    res.json(calificaciones);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener las calificaciones' });
  }
});

module.exports = router;

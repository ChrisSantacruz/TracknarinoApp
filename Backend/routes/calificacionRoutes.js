const express = require('express');
const router = express.Router();
const Calificacion = require('../models/Calificacion');
const verificarToken = require('../middleware/authMiddleware');

// Crear una calificación
router.post('/crear', verificarToken, async (req, res) => {
  try {
    const { tipoServicio, calificacion, comentario } = req.body;

    if (!tipoServicio || !calificacion) {
      return res.status(400).json({ error: 'Tipo de servicio y calificación son obligatorios' });
    }

    const nuevaCalificacion = new Calificacion({
      usuario: req.usuario.id,
      tipoServicio,
      calificacion,
      comentario
    });

    await nuevaCalificacion.save();

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

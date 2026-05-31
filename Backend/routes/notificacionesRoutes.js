const express = require('express');
const router = express.Router();
const User = require('../models/User');
const verificarToken = require('../middleware/authMiddleware');

// Guardar o actualizar el deviceToken del usuario
router.post('/registrar-token', verificarToken, async (req, res) => {
  const { token } = req.body;
  const platform = ['android', 'ios', 'web'].includes(req.body.platform)
    ? req.body.platform
    : 'unknown';

  if (!token) return res.status(400).json({ error: 'Token de dispositivo requerido' });

  try {
    const usuario = await User.findById(req.usuario.id);
    if (!usuario) return res.status(404).json({ error: 'Usuario no encontrado' });

    usuario.deviceToken = token;
    const existing = usuario.fcmTokens.find((entry) => entry.token === token);
    if (existing) {
      existing.platform = platform;
      existing.lastSeenAt = new Date();
      existing.invalidatedAt = null;
    } else {
      usuario.fcmTokens.push({ token, platform, lastSeenAt: new Date() });
    }
    await usuario.save();

    res.json({ mensaje: 'Token actualizado correctamente', usuario });
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar token' });
  }
});

router.delete('/token', verificarToken, async (req, res) => {
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'Token de dispositivo requerido' });

  try {
    await User.updateOne(
      { _id: req.usuario.id },
      {
        $pull: { fcmTokens: { token } },
        $set: { deviceToken: '' },
      }
    );
    res.json({ mensaje: 'Token eliminado correctamente' });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar token' });
  }
});

module.exports = router;

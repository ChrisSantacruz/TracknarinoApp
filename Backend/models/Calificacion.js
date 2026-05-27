const mongoose = require('mongoose');

const calificacionSchema = new mongoose.Schema({
  usuario: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  tipoServicio: {
    type: String,
    enum: ['camionero', 'contratista'],
    required: true
  },
  calificacion: {
    type: Number,
    min: 1,
    max: 5,
    required: true
  },
  comentario: {
    type: String,
    required: false
  },
  fecha: {
    type: Date,
    default: Date.now
  }
}, {
  collection: 'calificaciones'
});

module.exports = mongoose.model('Calificacion', calificacionSchema);

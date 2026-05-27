const mongoose = require('mongoose');

const vehiculoSchema = new mongoose.Schema({
  camioneroId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',  // Relaciona con el usuario (camionero)
    required: true
  },
  tipoVehiculo: {
    type: String,
    enum: ['bus', 'buseta', 'piaggio', 'camion de carga', 'volqueta', 'camion piaggio'],
    required: true
  },
  capacidadCarga: {
    type: Number,
    required: true
  },
  unidadCapacidad: {
    type: String,
    enum: ['kg', 'pasajeros'],
    default: 'kg'
  },
  marca: {
    type: String,
    required: true
  },
  modelo: {
    type: String,
    required: true
  },
  placa: {
    type: String,
    required: true
  },
  papelesAlDia: {
    type: Boolean,
    default: true,
    required: true
  },
  fechaRegistro: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Vehiculo', vehiculoSchema);

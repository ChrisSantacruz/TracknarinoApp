const mongoose = require('mongoose');

const vehiculoSchema = new mongoose.Schema({
  camioneroId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',  // Relaciona con el usuario (camionero)
    required: true
  },
  tipoVehiculo: {
    type: String,
    enum: [
      'camion_liviano_npr_nqr',
      'camion_mediano_frr',
      'camion_grande_ftr_fvr_gh',
      'tractocamion',
      'camion_refrigerado',
      'camion_plataforma',
      'volqueta',
      'camioneta_carga',
    ],
    required: true
  },
  capacidadCarga: {
    type: Number,
    required: true
  },
  unidadCapacidad: {
    type: String,
    enum: ['kg', 'toneladas'],
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
}, {
  collection: 'vehiculos'
});

module.exports = mongoose.model('Vehiculo', vehiculoSchema);

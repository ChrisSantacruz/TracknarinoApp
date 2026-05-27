const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  nombre: {
    type: String, 
    required: function() { return this.tipoUsuario === 'contratista'; }
  },
  correo: {
    type: String, 
    required: true, 
    unique: true
  },
  contraseña: {
    type: String, 
    required: true
  },
  tipoUsuario: {
    type: String, 
    enum: ['usuario', 'camionero', 'contratista'], 
    required: true
  },
  telefono: {
    type: String,
    required: function() { return this.tipoUsuario === 'camionero'; }
  },
  empresa: {
    type: String,
    required: function() { return this.tipoUsuario === 'contratista'; }
  },
  estadoAprobacion: {
    type: String,
    enum: ['pendiente', 'aprobado', 'rechazado'],
    default: 'pendiente'
  },
  camionerosAfiliados: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',  // Referencia a los camioneros afiliados
    default: []
  }],
  disponibleParaSolicitarCamioneros: {
    type: Boolean,
    default: true,
    required: function() { return this.tipoUsuario === 'contratista'; }
  },
  metodoPago: {
    type: String,
    enum: ['Visa', 'Nequi', 'Efectivo'],
    required: false
  },
  calificacion: {
    type: Number,
    min: 0,
    max: 5,
    default: null,
  },
  deviceToken: {
    type: String,
    default: ''
  },
  camion: {
    tipoVehiculo: {
      type: String,
      enum: ['bus', 'buseta', 'piaggio', 'camion de carga', 'volqueta', 'camion piaggio'],
      required: function() { return this.tipoUsuario === 'camionero'; }
    },
    capacidadCarga: {
      type: Number,
      required: function() { return this.tipoUsuario === 'camionero'; }
    },
    unidadCapacidad: {
      type: String,
      enum: ['kg', 'pasajeros'],
      default: 'kg'
    },
    marca: {
      type: String,
      required: function() { return this.tipoUsuario === 'camionero'; }
    },
    modelo: {
      type: String,
      required: function() { return this.tipoUsuario === 'camionero'; }
    },
    placa: {
      type: String,
      required: function() { return this.tipoUsuario === 'camionero'; }
    },
    papelesAlDia: {
      type: Boolean,
      required: function() { return this.tipoUsuario === 'camionero'; }
    }
  },
  empresaAfiliada: {
    type: String,
    default: ''
  },
  licenciaExpedicion: {
    type: Date,
    required: function() { return this.tipoUsuario === 'camionero' && !this.licenciaVencimiento; }
  },
  licenciaVencimiento: {
    type: Date,
    required: function() { return this.tipoUsuario === 'camionero' && !this.licenciaExpedicion; }
  },
  numeroCedula: {
    type: String,
    required: function() { return this.tipoUsuario === 'camionero'; }
  },
  camioneroAfiliado: {
    type: Boolean,
    default: false,
    required: function() { return this.tipoUsuario === 'contratista'; }
  },
  created_at: {
    type: Date,
    default: Date.now
  },
  updated_at: {
    type: Date,
    default: Date.now
  }
}, {
  toJSON: {
    transform: (doc, ret) => {
      delete ret.contraseña;
      delete ret.__v;
      return ret;
    }
  },
  toObject: {
    transform: (doc, ret) => {
      delete ret.contraseña;
      delete ret.__v;
      return ret;
    }
  }
});

userSchema.index({ tipoUsuario: 1, estadoAprobacion: 1 });
userSchema.index({ camionerosAfiliados: 1 });
userSchema.index({ 'camion.placa': 1 }, { sparse: true });

module.exports = mongoose.model('User', userSchema);

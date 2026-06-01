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
    required: function() { return this.authProvider !== 'google'; }
  },
  authProvider: {
    type: String,
    enum: ['password', 'google'],
    default: 'password'
  },
  googleSub: {
    type: String
  },
  fotoPerfil: {
    type: String,
    default: ''
  },
  rolConfigurado: {
    type: Boolean,
    default: function() { return this.tipoUsuario !== 'usuario'; }
  },
  tipoUsuario: {
    type: String, 
    enum: ['usuario', 'camionero', 'contratista', 'cliente'], 
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
    enum: ['Visa', 'Nequi', 'Efectivo', 'Transferencia bancaria', 'Daviplata'],
    required: false
  },
  metodosPago: [{
    type: String,
    enum: ['Nequi', 'Transferencia bancaria', 'Efectivo', 'Daviplata']
  }],
  descripcionOperacion: {
    type: String,
    trim: true,
    default: ''
  },
  anioFundacion: {
    type: Number,
    min: 1800,
    max: 2200
  },
  ubicacionEmpresa: {
    type: String,
    trim: true,
    default: ''
  },
  sitioWeb: {
    type: String,
    trim: true,
    default: ''
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
  fcmTokens: [{
    token: { type: String, required: true },
    platform: {
      type: String,
      enum: ['android', 'ios', 'web', 'unknown'],
      default: 'unknown'
    },
    lastSeenAt: { type: Date, default: Date.now },
    invalidatedAt: { type: Date, default: null }
  }],
  reputation: {
    promedio: { type: Number, min: 0, max: 5, default: 0 },
    total: { type: Number, default: 0 },
    totalViajes: { type: Number, default: 0 },
    totalContrataciones: { type: Number, default: 0 },
    totalOperaciones: { type: Number, default: 0 }
  },
  camion: {
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
      required: function() { return this.tipoUsuario === 'camionero'; }
    },
    capacidadCarga: {
      type: Number,
      required: function() { return this.tipoUsuario === 'camionero'; }
    },
    unidadCapacidad: {
      type: String,
      enum: ['kg', 'toneladas'],
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
userSchema.index({ googleSub: 1 }, { unique: true, sparse: true });
userSchema.index({ 'fcmTokens.token': 1 }, { sparse: true });
userSchema.index({ camionerosAfiliados: 1 });
userSchema.index({ 'camion.placa': 1 }, { sparse: true });

module.exports = mongoose.model('User', userSchema);

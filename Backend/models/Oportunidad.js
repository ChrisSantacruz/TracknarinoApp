const mongoose = require('mongoose');

const {

  isValidCoordinatePair,

  buildGeoMigrationSubdocument,

  evaluateOpportunityGeo,

} = require('../utils/geoValidation');



const TRIP_STATES = ['disponible', 'asignada', 'aceptada', 'en_ruta', 'entregada', 'cancelada'];

const ACTIVE_TRIP_STATES = ['asignada', 'aceptada', 'en_ruta'];

const NEGOTIATION_STATES = ['sin_oferta', 'oferta_camionero', 'contraoferta_contratista', 'aceptada', 'cancelada'];

const OWNER_TYPES = ['CLIENTE', 'CONTRATISTA'];



const geoPointSchema = new mongoose.Schema({

  name: { type: String, trim: true },

  address: { type: String, trim: true },

  coordinates: {

    type: [Number],

    validate: {

      validator: (value) => value === undefined || isValidCoordinatePair(value),

      message: 'coordinates debe ser [lng, lat] con rangos válidos',

    },

  },

}, { _id: false });



const oportunidadSchema = new mongoose.Schema({

  titulo: { type: String, required: true },

  descripcion: { type: String },

  origin: geoPointSchema,

  destination: geoPointSchema,

  origen: { type: String, trim: true },

  destino: { type: String, trim: true },

  direccionCargue: { type: String, trim: true },

  direccionDescargue: { type: String, trim: true },

  fecha: { type: Date, required: true },

  precio: { type: Number, required: true },

  pesoCarga: { type: Number },

  tipoCarga: { type: String, trim: true },

  vehiculoPreferido: {
    type: String,
    trim: true,
    enum: [
      'camion_liviano_npr_nqr',
      'camion_mediano_frr',
      'camion_grande_ftr_fvr_gh',
      'tractocamion',
      'camion_refrigerado',
      'camion_plataforma',
      'volqueta',
      'camioneta_carga',
      'otro',
    ],
  },

  capacidadRequerida: { type: Number },

  unidadCapacidad: {
    type: String,
    enum: ['toneladas', 'kg'],
    default: 'toneladas',
  },

  metodoPagoCarga: {
    type: String,
    trim: true,
    enum: ['transferencia', 'efectivo', 'nequi', 'daviplata', 'mixto'],
  },

  prioridad: {
    type: String,
    enum: ['baja', 'media', 'alta'],
    default: 'baja',
  },

  incentivoPrioridad: {
    type: Number,
    default: 0,
    min: 0,
  },

  requisitosEspeciales: { type: String, trim: true },

  estado: {

    type: String,

    enum: TRIP_STATES,

    default: 'disponible'

  },

  finalizada: {

    type: Boolean,

    default: false

  },

  estadoTimestamps: {

    disponible: { type: Date },

    asignada: { type: Date },

    aceptada: { type: Date },

    en_ruta: { type: Date },

    entregada: { type: Date },

    cancelada: { type: Date },

  },

  geoMigration: buildGeoMigrationSubdocument(),

  ownerType: { type: String, enum: OWNER_TYPES },

  ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

  createdByRole: { type: String, enum: ['cliente', 'contratista', 'camionero'] },

  contratista: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

  camioneroAsignado: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

  trackingId: { type: String, unique: true, sparse: true, trim: true },

  sharedTrackingEnabled: { type: Boolean, default: false },

  deliveryEvidence: {
    photos: [{ type: String, trim: true }],
    observations: { type: String, trim: true },
    deliveredAt: { type: Date },
    location: {
      lat: { type: Number },
      lng: { type: Number },
    },
    signatureName: { type: String, trim: true },
  },

  negociacion: {
    estado: { type: String, enum: NEGOTIATION_STATES, default: 'sin_oferta' },
    precioOfertado: { type: Number },
    precioContraoferta: { type: Number },
    camionero: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    ultimaAccionPor: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    ultimaAccionRol: { type: String, enum: ['camionero', 'contratista', 'cliente'] },
    mensaje: { type: String, trim: true },
    updatedAt: { type: Date },
  }

}, {

  timestamps: true

});



oportunidadSchema.index({ estado: 1, fecha: 1 });

oportunidadSchema.index({ contratista: 1, estado: 1, fecha: -1 });

oportunidadSchema.index({ ownerType: 1, ownerId: 1, estado: 1, fecha: -1 });

oportunidadSchema.index({ camioneroAsignado: 1, estado: 1, fecha: -1 });

oportunidadSchema.index({ contratista: 1, camioneroAsignado: 1, estado: 1, updatedAt: -1 });

oportunidadSchema.index({ 'origin.coordinates': '2dsphere' });

oportunidadSchema.index({ 'destination.coordinates': '2dsphere' });

oportunidadSchema.index({ 'geoMigration.status': 1 });



oportunidadSchema.pre('validate', function setCompatibilityFields(next) {

  if (!this.ownerType && this.contratista) {
    this.ownerType = 'CONTRATISTA';
  }

  if (!this.ownerId && this.contratista) {
    this.ownerId = this.contratista;
  }

  if (!this.createdBy && this.ownerId) {
    this.createdBy = this.ownerId;
  }

  if (!this.createdByRole && this.ownerType) {
    this.createdByRole = this.ownerType.toLowerCase();
  }

  if (this.origin) {

    this.origen = this.origin.name || this.origen;

    this.direccionCargue = this.origin.address || this.direccionCargue;

  }



  if (this.destination) {

    this.destino = this.destination.name || this.destino;

    this.direccionDescargue = this.destination.address || this.direccionDescargue;

  }

  if (this.capacidadRequerida == null && this.pesoCarga != null) {
    this.capacidadRequerida = this.pesoCarga;
  }

  if (this.incentivoPrioridad > 0 && (!this.prioridad || this.prioridad === 'baja')) {
    this.prioridad = this.incentivoPrioridad >= 20000 ? 'alta' : 'media';
  }

  if (!this.incentivoPrioridad || this.incentivoPrioridad <= 0) {
    this.incentivoPrioridad = 0;
    this.prioridad = 'baja';
  }



  if (!this.estadoTimestamps) {

    this.estadoTimestamps = {};

  }



  if (this.isNew && this.estado && !this.estadoTimestamps[this.estado]) {

    this.estadoTimestamps[this.estado] = new Date();

  }



  if (this.estado === 'entregada') {

    this.finalizada = true;

  }



  const geoEval = evaluateOpportunityGeo(this);

  if (!this.geoMigration) this.geoMigration = {};

  this.geoMigration.status = geoEval.status;

  this.geoMigration.missingFields = geoEval.missingFields;

  this.geoMigration.routable = geoEval.routable;

  if (this.isNew && !this.geoMigration.source) {

    this.geoMigration.source = geoEval.routable ? 'api' : 'legacy';

  }



  next();

});



oportunidadSchema.statics.TRIP_STATES = TRIP_STATES;

oportunidadSchema.statics.ACTIVE_TRIP_STATES = ACTIVE_TRIP_STATES;

oportunidadSchema.statics.OWNER_TYPES = OWNER_TYPES;



module.exports = mongoose.model('Oportunidad', oportunidadSchema);


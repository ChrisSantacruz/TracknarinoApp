const mongoose = require('mongoose');

const {

  isValidCoordinatePair,

  buildGeoMigrationSubdocument,

  evaluateOpportunityGeo,

} = require('../utils/geoValidation');



const TRIP_STATES = ['disponible', 'asignada', 'aceptada', 'en_ruta', 'entregada', 'cancelada'];

const ACTIVE_TRIP_STATES = ['asignada', 'aceptada', 'en_ruta'];

const NEGOTIATION_STATES = ['sin_oferta', 'oferta_camionero', 'contraoferta_contratista', 'aceptada', 'cancelada'];



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

  contratista: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },

  camioneroAsignado: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

  negociacion: {
    estado: { type: String, enum: NEGOTIATION_STATES, default: 'sin_oferta' },
    precioOfertado: { type: Number },
    precioContraoferta: { type: Number },
    camionero: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    ultimaAccionPor: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    ultimaAccionRol: { type: String, enum: ['camionero', 'contratista'] },
    mensaje: { type: String, trim: true },
    updatedAt: { type: Date },
  }

}, {

  timestamps: true

});



oportunidadSchema.index({ estado: 1, fecha: 1 });

oportunidadSchema.index({ contratista: 1, estado: 1, fecha: -1 });

oportunidadSchema.index({ camioneroAsignado: 1, estado: 1, fecha: -1 });

oportunidadSchema.index({ contratista: 1, camioneroAsignado: 1, estado: 1, updatedAt: -1 });

oportunidadSchema.index({ 'origin.coordinates': '2dsphere' });

oportunidadSchema.index({ 'destination.coordinates': '2dsphere' });

oportunidadSchema.index({ 'geoMigration.status': 1 });



oportunidadSchema.pre('validate', function setCompatibilityFields(next) {

  if (this.origin) {

    this.origen = this.origin.name || this.origen;

    this.direccionCargue = this.origin.address || this.direccionCargue;

  }



  if (this.destination) {

    this.destino = this.destination.name || this.destino;

    this.direccionDescargue = this.destination.address || this.direccionDescargue;

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



module.exports = mongoose.model('Oportunidad', oportunidadSchema);


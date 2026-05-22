const mongoose = require('mongoose');

const {

  isValidCoordinatePair,

  buildGeoMigrationSubdocument,

  evaluateAlertGeo,

} = require('../utils/geoValidation');



const alertaSeguridadSchema = new mongoose.Schema({

  tipo: {

    type: String,

    enum: ['trancon', 'sospecha', 'intento_robo', 'robo', 'obstaculo', 'clima', 'accidente', 'policia', 'otro'],

    required: true

  },

  descripcion: {

    type: String

  },

  usuario: {

    type: mongoose.Schema.Types.ObjectId,

    ref: 'User',

    required: true

  },

  coords: {

    lat: Number,

    lng: Number

  },

  coordinates: {

    type: [Number],

    validate: {

      validator: (value) => value === undefined || isValidCoordinatePair(value),

      message: 'coordinates debe ser [lng, lat] con rangos válidos',

    },

  },

  timestamp: {

    type: Date,

    default: Date.now

  },

  clientEventId: { type: String, trim: true },

  geoMigration: buildGeoMigrationSubdocument(),

}, {

  timestamps: true

});



alertaSeguridadSchema.index({ timestamp: -1 });

alertaSeguridadSchema.index({ coordinates: '2dsphere' });

alertaSeguridadSchema.index({ tipo: 1, timestamp: -1 });

alertaSeguridadSchema.index({ tipo: 1, createdAt: -1 });

alertaSeguridadSchema.index({ coordinates: '2dsphere', tipo: 1, timestamp: -1 });

alertaSeguridadSchema.index({ 'geoMigration.status': 1 });

alertaSeguridadSchema.index(

  { usuario: 1, clientEventId: 1 },

  { unique: true, sparse: true },

);



alertaSeguridadSchema.pre('validate', function syncAlertGeoMigration(next) {

  const geoEval = evaluateAlertGeo(this);

  if (!this.geoMigration) this.geoMigration = {};

  this.geoMigration.status = geoEval.status;

  this.geoMigration.missingFields = geoEval.missingFields;

  this.geoMigration.routable = geoEval.routable;

  if (this.isNew && !this.geoMigration.source) {

    this.geoMigration.source = geoEval.routable ? 'api' : 'legacy';

  }

  next();

});



module.exports = mongoose.model('AlertaSeguridad', alertaSeguridadSchema);


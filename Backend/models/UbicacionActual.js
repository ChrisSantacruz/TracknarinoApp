const mongoose = require('mongoose');

const { isValidCoordinatePair } = require('../utils/geoValidation');



const ubicacionActualSchema = new mongoose.Schema({

  camionero: {

    type: mongoose.Schema.Types.ObjectId,

    ref: 'User',

    required: true,

  },

  oportunidad: { type: mongoose.Schema.Types.ObjectId, ref: 'Oportunidad' },

  coordinates: {

    type: [Number],

    required: true,

    validate: {

      validator: isValidCoordinatePair,

      message: 'coordinates debe ser [lng, lat] con rangos válidos',

    },

  },

  coords: {

    lat: { type: Number },

    lng: { type: Number },

  },

  timestamp: { type: Date, required: true },

  serverReceivedAt: { type: Date, default: Date.now },

  speed: { type: Number },

  heading: { type: Number },

  accuracy: { type: Number },

  signal: {

    provider: { type: String },

    isMocked: { type: Boolean },

    batteryLevel: { type: Number },

  },

  source: {

    type: String,

    enum: ['gps', 'network', 'offline_sync'],

    default: 'gps',

  },

  trackingStatusOverride: {
    type: String,
    enum: ['active', 'stopped', 'offline'],
  },

  operationalEvent: {
    type: {
      type: String,
      enum: ['movement', 'stopped', 'signal_lost', 'signal_recovered'],
    },
    reason: { type: String, trim: true },
    reportedAt: { type: Date },
  },

  clientEventId: { type: String, trim: true },

  sequence: { type: Number },

}, {

  timestamps: true,

  toJSON: {

    transform: (doc, ret) => {

      if (!ret.coords && Array.isArray(ret.coordinates)) {

        ret.coords = { lng: ret.coordinates[0], lat: ret.coordinates[1] };

      }

      return ret;

    },

  },

});



ubicacionActualSchema.index({ camionero: 1 }, { unique: true });

ubicacionActualSchema.index({ timestamp: -1 });

ubicacionActualSchema.index({ serverReceivedAt: -1 });

ubicacionActualSchema.index({ coordinates: '2dsphere' });

ubicacionActualSchema.index({ oportunidad: 1, serverReceivedAt: -1 });

ubicacionActualSchema.index({ camionero: 1, serverReceivedAt: -1 });

ubicacionActualSchema.index({ source: 1, serverReceivedAt: -1 });



module.exports = mongoose.model('UbicacionActual', ubicacionActualSchema);


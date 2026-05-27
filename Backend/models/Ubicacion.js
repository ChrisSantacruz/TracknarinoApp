const mongoose = require('mongoose');

const { isValidCoordinatePair } = require('../utils/geoValidation');



const ubicacionSchema = new mongoose.Schema({

  camionero: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },

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

    lng: { type: Number }

  },

  timestamp: { type: Date, default: Date.now },

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

  clientEventId: { type: String, trim: true },

  sequence: { type: Number },

  /** Prepared for TTL/archival — not enabled in Phase 1.5 */

  retention: {

    policy: { type: String, default: 'active_trip' },

    archiveAfter: { type: Date },

  },

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



ubicacionSchema.index({ camionero: 1, timestamp: -1 });

ubicacionSchema.index({ oportunidad: 1, timestamp: 1 });

ubicacionSchema.index({ coordinates: '2dsphere' });

ubicacionSchema.index(

  { camionero: 1, clientEventId: 1 },

  { unique: true, sparse: true },

);

// Prepared TTL — do NOT enable expireAfterSeconds until policy is approved:

// ubicacionSchema.index({ timestamp: 1 }, { expireAfterSeconds: 90 * 24 * 60 * 60 });



module.exports = mongoose.model('Ubicacion', ubicacionSchema);


const mongoose = require('mongoose');

const ROUTE_STATES = ['active', 'inactive'];
const ROUTE_PROVIDERS = ['public_osrm', 'self_hosted_osrm', 'valhalla', 'unknown'];

const operationalRouteSchema = new mongoose.Schema({
  routeId: {
    type: String,
    required: true,
    unique: true,
    trim: true,
  },
  tripId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Oportunidad',
    required: true,
  },
  camioneroId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  contractorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  geometryHash: {
    type: String,
    required: true,
    trim: true,
  },
  geometry: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'RouteGeometry',
    required: true,
  },
  provider: {
    type: String,
    enum: ROUTE_PROVIDERS,
    required: true,
  },
  routeVersion: {
    type: Number,
    required: true,
    min: 1,
  },
  state: {
    type: String,
    enum: ROUTE_STATES,
    default: 'active',
  },
  rerouteReason: {
    type: String,
    trim: true,
  },
  replacedByRouteId: {
    type: String,
    trim: true,
  },
  parentRouteId: {
    type: String,
    trim: true,
  },
  clientEventId: {
    type: String,
    trim: true,
  },
  summary: {
    distanceKm: { type: Number },
    durationMinutes: { type: Number },
    pointCount: { type: Number },
    bbox: {
      minLng: Number,
      minLat: Number,
      maxLng: Number,
      maxLat: Number,
    },
  },
  diagnostics: {
    providerLatencyMs: { type: Number },
    correlationId: { type: String, trim: true },
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  replacedAt: {
    type: Date,
  },
}, {
  timestamps: true,
});

operationalRouteSchema.index({ tripId: 1, state: 1, routeVersion: -1 });
operationalRouteSchema.index({ contractorId: 1, state: 1, updatedAt: -1 });
operationalRouteSchema.index({ camioneroId: 1, state: 1, updatedAt: -1 });
operationalRouteSchema.index({ geometryHash: 1, provider: 1 });
operationalRouteSchema.index(
  { tripId: 1, state: 1 },
  { unique: true, partialFilterExpression: { state: 'active' } },
);
operationalRouteSchema.index(
  { tripId: 1, clientEventId: 1 },
  { unique: true, sparse: true },
);

operationalRouteSchema.statics.ROUTE_STATES = ROUTE_STATES;
operationalRouteSchema.statics.ROUTE_PROVIDERS = ROUTE_PROVIDERS;

module.exports = mongoose.model('OperationalRoute', operationalRouteSchema);

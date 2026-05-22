const mongoose = require('mongoose');

const ROUTE_TELEMETRY_TYPES = [
  'provider.latency',
  'provider.failure',
  'route.replacement',
  'route.invalidation',
  'route.degradation',
  'route.stale',
  'corridor.alert_intersection',
  'reroute.request',
];

const routeTelemetryEventSchema = new mongoose.Schema({
  eventType: {
    type: String,
    enum: ROUTE_TELEMETRY_TYPES,
    required: true,
  },
  routeId: { type: String, trim: true },
  tripId: { type: mongoose.Schema.Types.ObjectId, ref: 'Oportunidad' },
  camioneroId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  contractorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  provider: { type: String, trim: true },
  metrics: {
    latencyMs: Number,
    rerouteCount: Number,
    alertIntersectionCount: Number,
    routeVersion: Number,
  },
  reason: { type: String, trim: true },
  correlationId: { type: String, trim: true },
  occurredAt: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

routeTelemetryEventSchema.index({ eventType: 1, occurredAt: -1 });
routeTelemetryEventSchema.index({ contractorId: 1, eventType: 1, occurredAt: -1 });
routeTelemetryEventSchema.index({ routeId: 1, occurredAt: -1 });
routeTelemetryEventSchema.index({ provider: 1, eventType: 1, occurredAt: -1 });

// Prepared TTL hook for future hot telemetry retention after dashboard requirements are approved.
// routeTelemetryEventSchema.index({ occurredAt: 1 }, { expireAfterSeconds: 180 * 24 * 60 * 60 });

routeTelemetryEventSchema.statics.ROUTE_TELEMETRY_TYPES = ROUTE_TELEMETRY_TYPES;

module.exports = mongoose.model('RouteTelemetryEvent', routeTelemetryEventSchema);

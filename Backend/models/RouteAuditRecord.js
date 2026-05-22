const mongoose = require('mongoose');

const ROUTE_AUDIT_EVENTS = [
  'route.created',
  'route.replaced',
  'route.invalidated',
  'route.degraded',
  'route.stale',
  'reroute.requested',
  'reroute.completed',
  'provider.failure',
  'corridor.alert_intersection',
];

const routeAuditRecordSchema = new mongoose.Schema({
  routeId: { type: String, trim: true },
  tripId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Oportunidad',
    required: true,
  },
  camioneroId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  },
  contractorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  eventType: {
    type: String,
    enum: ROUTE_AUDIT_EVENTS,
    required: true,
  },
  reason: {
    type: String,
    trim: true,
  },
  severity: {
    type: String,
    enum: ['info', 'warning', 'critical'],
    default: 'info',
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
  },
  correlationId: {
    type: String,
    trim: true,
  },
  clientEventId: {
    type: String,
    trim: true,
  },
  occurredAt: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

routeAuditRecordSchema.index({ tripId: 1, occurredAt: -1 });
routeAuditRecordSchema.index({ routeId: 1, occurredAt: -1 });
routeAuditRecordSchema.index({ contractorId: 1, eventType: 1, occurredAt: -1 });
routeAuditRecordSchema.index({ eventType: 1, occurredAt: -1 });
routeAuditRecordSchema.index(
  { tripId: 1, clientEventId: 1, eventType: 1 },
  { unique: true, sparse: true },
);

// Prepared TTL hook for future audit retention policy; keep disabled until operations approves archival.
// routeAuditRecordSchema.index({ occurredAt: 1 }, { expireAfterSeconds: 365 * 24 * 60 * 60 });

routeAuditRecordSchema.statics.ROUTE_AUDIT_EVENTS = ROUTE_AUDIT_EVENTS;

module.exports = mongoose.model('RouteAuditRecord', routeAuditRecordSchema);

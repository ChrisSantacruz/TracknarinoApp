const mongoose = require('mongoose');

const routeGeometrySchema = new mongoose.Schema({
  geometryHash: {
    type: String,
    required: true,
    unique: true,
    trim: true,
  },
  provider: {
    type: String,
    required: true,
    trim: true,
  },
  encodedPolyline: {
    type: String,
    required: true,
  },
  pointCount: {
    type: Number,
    required: true,
    min: 2,
  },
  bbox: {
    minLng: { type: Number, required: true },
    minLat: { type: Number, required: true },
    maxLng: { type: Number, required: true },
    maxLat: { type: Number, required: true },
  },
  compression: {
    type: String,
    enum: ['polyline'],
    default: 'polyline',
  },
}, {
  timestamps: true,
});

routeGeometrySchema.index({ provider: 1, createdAt: -1 });
routeGeometrySchema.index({ 'bbox.minLng': 1, 'bbox.maxLng': 1, 'bbox.minLat': 1, 'bbox.maxLat': 1 });

module.exports = mongoose.model('RouteGeometry', routeGeometrySchema);

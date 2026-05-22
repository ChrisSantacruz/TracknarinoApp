const crypto = require('crypto');
const polyline = require('@mapbox/polyline');

const RouteGeometry = require('../models/RouteGeometry');
const { isValidCoordinatePair } = require('../utils/geoValidation');

function normalizeRouteCoordinates(coordinates) {
  if (!Array.isArray(coordinates) || coordinates.length < 2) return null;

  const normalized = coordinates.map((point) => {
    if (!Array.isArray(point) || point.length < 2) return null;
    const pair = [Number(point[0]), Number(point[1])];
    return isValidCoordinatePair(pair) ? pair : null;
  });

  return normalized.every(Boolean) ? normalized : null;
}

function calculateRouteBbox(coordinates) {
  return coordinates.reduce((bbox, [lng, lat]) => ({
    minLng: Math.min(bbox.minLng, lng),
    minLat: Math.min(bbox.minLat, lat),
    maxLng: Math.max(bbox.maxLng, lng),
    maxLat: Math.max(bbox.maxLat, lat),
  }), {
    minLng: Infinity,
    minLat: Infinity,
    maxLng: -Infinity,
    maxLat: -Infinity,
  });
}

function calculateGeometryHash(coordinates) {
  const canonical = coordinates
    .map(([lng, lat]) => `${Number(lng).toFixed(6)},${Number(lat).toFixed(6)}`)
    .join(';');

  return crypto.createHash('sha256').update(canonical).digest('hex');
}

function encodeRoutePolyline(coordinates) {
  return polyline.encode(coordinates.map(([lng, lat]) => [lat, lng]));
}

function decodeRoutePolyline(encodedPolyline) {
  return polyline.decode(encodedPolyline).map(([lat, lng]) => [lng, lat]);
}

async function getOrCreateRouteGeometry({ coordinates, provider }) {
  const normalized = normalizeRouteCoordinates(coordinates);
  if (!normalized) {
    const error = new Error('coordinates debe contener al menos dos puntos [lng, lat] válidos');
    error.statusCode = 400;
    throw error;
  }

  const geometryHash = calculateGeometryHash(normalized);
  const existing = await RouteGeometry.findOne({ geometryHash });
  if (existing) {
    return { geometry: existing, geometryHash, deduplicated: true };
  }

  const geometry = await RouteGeometry.create({
    geometryHash,
    provider,
    encodedPolyline: encodeRoutePolyline(normalized),
    pointCount: normalized.length,
    bbox: calculateRouteBbox(normalized),
  });

  return { geometry, geometryHash, deduplicated: false };
}

module.exports = {
  normalizeRouteCoordinates,
  calculateRouteBbox,
  calculateGeometryHash,
  encodeRoutePolyline,
  decodeRoutePolyline,
  getOrCreateRouteGeometry,
};

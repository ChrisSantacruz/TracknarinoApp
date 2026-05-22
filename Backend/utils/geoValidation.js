/**
 * Centralized geolocation validation for TrackNariño.
 * Used by models, controllers, routes, migration scripts, and tracking services.
 */

const MIGRATION_STATUSES = ['pending', 'resolved', 'unresolved', 'manual_review'];

/** Max straight-line distance (km) considered plausible for a single logistics trip in Colombia. */
const MAX_PLAUSIBLE_ROUTE_KM = 2500;

/** Min distance (m) between consecutive GPS points to count as movement. */
const MIN_MOVEMENT_METERS = 3;

/** Reject GPS readings worse than this accuracy (meters). */
const MAX_ACCEPTABLE_ACCURACY_METERS = 500;

function normalizeNumber(value) {
  if (value === undefined || value === null || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function isValidCoordinatePair(value) {
  if (!Array.isArray(value) || value.length !== 2) return false;

  const [lng, lat] = value.map(Number);
  return Number.isFinite(lng)
    && Number.isFinite(lat)
    && lng >= -180
    && lng <= 180
    && lat >= -90
    && lat <= 90
    && !(lng === 0 && lat === 0);
}

function normalizeCoordinatePair(value) {
  if (!isValidCoordinatePair(value)) return null;
  const [lng, lat] = value.map(Number);
  return { lng, lat, coordinates: [lng, lat] };
}

function normalizeLatLngInput(input) {
  if (!input || typeof input !== 'object') return null;

  const lat = normalizeNumber(input.lat ?? input.latitude ?? input.latitud);
  const lng = normalizeNumber(input.lng ?? input.longitude ?? input.longitud);

  if (lat === null || lng === null) return null;
  return normalizeCoordinatePair([lng, lat]);
}

function haversineDistanceKm(from, to) {
  const fromLat = from.lat ?? from[1];
  const fromLng = from.lng ?? from[0];
  const toLat = to.lat ?? to[1];
  const toLng = to.lng ?? to[0];

  const R = 6371;
  const dLat = ((toLat - fromLat) * Math.PI) / 180;
  const dLng = ((toLng - fromLng) * Math.PI) / 180;
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos((fromLat * Math.PI) / 180)
    * Math.cos((toLat * Math.PI) / 180)
    * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function isDuplicateCoordinatePair(a, b, epsilonMeters = 5) {
  if (!a || !b) return false;
  const distanceKm = haversineDistanceKm(
    { lat: a.lat, lng: a.lng },
    { lat: b.lat, lng: b.lng },
  );
  return distanceKm * 1000 <= epsilonMeters;
}

function normalizeGeoPoint(value, fallbackName, fallbackAddress) {
  if (!value || typeof value !== 'object') return null;

  const name = typeof value.name === 'string' ? value.name.trim() : fallbackName?.trim();
  const address = typeof value.address === 'string' ? value.address.trim() : fallbackAddress?.trim();
  const normalized = normalizeCoordinatePair(
    Array.isArray(value.coordinates) ? value.coordinates : null,
  );

  if (!name || !address || !normalized) return null;

  return {
    name,
    address,
    coordinates: normalized.coordinates,
  };
}

function getOriginDestinationPayload(body) {
  const origin = normalizeGeoPoint(body.origin, body.origen, body.direccionCargue);
  const destination = normalizeGeoPoint(body.destination, body.destino, body.direccionDescargue);

  if (!origin || !destination) {
    return {
      error: 'origin y destination son obligatorios y deben incluir name, address y coordinates [lng, lat] válidas',
    };
  }

  const routeCheck = evaluateRoutePlausibility(origin.coordinates, destination.coordinates);
  if (!routeCheck.valid) {
    return { error: routeCheck.reason };
  }

  return { origin, destination };
}

function evaluateRoutePlausibility(originCoordinates, destinationCoordinates) {
  if (!isValidCoordinatePair(originCoordinates) || !isValidCoordinatePair(destinationCoordinates)) {
    return { valid: false, reason: 'Coordenadas de origen o destino inválidas' };
  }

  const origin = normalizeCoordinatePair(originCoordinates);
  const destination = normalizeCoordinatePair(destinationCoordinates);

  if (isDuplicateCoordinatePair(origin, destination, 50)) {
    return { valid: false, reason: 'Origen y destino no pueden ser el mismo punto' };
  }

  const distanceKm = haversineDistanceKm(
    { lat: origin.lat, lng: origin.lng },
    { lat: destination.lat, lng: destination.lng },
  );

  if (distanceKm > MAX_PLAUSIBLE_ROUTE_KM) {
    return {
      valid: false,
      reason: `Ruta improbable: distancia ${distanceKm.toFixed(0)} km excede el máximo permitido`,
    };
  }

  return { valid: true, distanceKm };
}

function evaluateGeoPoint(point, label = 'point') {
  const missingFields = [];
  if (!point?.name) missingFields.push(`${label}.name`);
  if (!point?.address) missingFields.push(`${label}.address`);
  if (!isValidCoordinatePair(point?.coordinates)) missingFields.push(`${label}.coordinates`);

  if (missingFields.length === 0) {
    return { status: 'resolved', missingFields: [], routable: true };
  }

  return {
    status: missingFields.includes(`${label}.coordinates`) ? 'unresolved' : 'pending',
    missingFields,
    routable: false,
  };
}

function evaluateOpportunityGeo(oportunidad) {
  const originStatus = evaluateGeoPoint(oportunidad?.origin, 'origin');
  const destinationStatus = evaluateGeoPoint(oportunidad?.destination, 'destination');
  const missingFields = [...originStatus.missingFields, ...destinationStatus.missingFields];

  let status = 'resolved';
  if (missingFields.length > 0) {
    status = missingFields.some((field) => field.endsWith('.coordinates')) ? 'unresolved' : 'pending';
  }

  let routable = originStatus.routable && destinationStatus.routable;
  if (routable) {
    const routeCheck = evaluateRoutePlausibility(
      oportunidad.origin.coordinates,
      oportunidad.destination.coordinates,
    );
    routable = routeCheck.valid;
    if (!routeCheck.valid) status = 'unresolved';
  }

  return { status, missingFields, routable };
}

function evaluateAlertGeo(alerta) {
  const hasCoordsObject = normalizeLatLngInput(alerta?.coords);
  const hasCoordinatesArray = normalizeCoordinatePair(alerta?.coordinates);

  if (hasCoordsObject && hasCoordinatesArray) {
    if (!isDuplicateCoordinatePair(hasCoordsObject, hasCoordinatesArray, 1)) {
      return {
        status: 'unresolved',
        missingFields: ['coords_mismatch'],
        routable: false,
      };
    }
    return { status: 'resolved', missingFields: [], routable: true };
  }

  if (hasCoordsObject || hasCoordinatesArray) {
    return { status: 'resolved', missingFields: [], routable: true };
  }

  return { status: 'unresolved', missingFields: ['coordinates'], routable: false };
}

function parseTimestamp(value, fallback = new Date()) {
  if (!value) return fallback;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function buildGeoMigrationSubdocument() {
  return {
    status: {
      type: String,
      enum: MIGRATION_STATUSES,
      default: 'pending',
    },
    missingFields: [{ type: String }],
    source: {
      type: String,
      enum: ['legacy', 'manual', 'import', 'api', 'script'],
      default: 'legacy',
    },
    notes: { type: String, trim: true },
    reviewedAt: { type: Date },
    routable: { type: Boolean, default: false },
  };
}

module.exports = {
  MIGRATION_STATUSES,
  MAX_PLAUSIBLE_ROUTE_KM,
  MIN_MOVEMENT_METERS,
  MAX_ACCEPTABLE_ACCURACY_METERS,
  normalizeNumber,
  isValidCoordinatePair,
  normalizeCoordinatePair,
  normalizeLatLngInput,
  normalizeGeoPoint,
  getOriginDestinationPayload,
  haversineDistanceKm,
  isDuplicateCoordinatePair,
  evaluateRoutePlausibility,
  evaluateGeoPoint,
  evaluateOpportunityGeo,
  evaluateAlertGeo,
  parseTimestamp,
  buildGeoMigrationSubdocument,
};

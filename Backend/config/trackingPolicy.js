/**
 * Tracking and GPS history policy constants.
 * TTL/archival cleanup is NOT enabled in Phase 1.5 — preparation only.
 */

/** Client timestamp older than this vs server is considered skewed. */
const MAX_CLIENT_CLOCK_SKEW_MS = 10 * 60 * 1000;

/** Future client timestamps beyond this are rejected. */
const MAX_FUTURE_TIMESTAMP_MS = 2 * 60 * 1000;

/** Stale if last update older than 5 minutes (uses serverReceivedAt when available). */
const STALE_LOCATION_MS = 5 * 60 * 1000;

/** Offline if last update older than 30 minutes. */
const OFFLINE_LOCATION_MS = 30 * 60 * 1000;

/** Prepared TTL for inactive GPS history (NOT applied to indexes yet). */
const PREPARED_HISTORY_TTL_DAYS = 90;

/** Prepared archival batch size for future jobs. */
const PREPARED_ARCHIVE_BATCH_SIZE = 5000;

/** Active trip states — history for these trips should be preserved longer. */
const ACTIVE_TRIP_STATES = ['asignada', 'aceptada', 'en_ruta'];

module.exports = {
  MAX_CLIENT_CLOCK_SKEW_MS,
  MAX_FUTURE_TIMESTAMP_MS,
  STALE_LOCATION_MS,
  OFFLINE_LOCATION_MS,
  PREPARED_HISTORY_TTL_DAYS,
  PREPARED_ARCHIVE_BATCH_SIZE,
  ACTIVE_TRIP_STATES,
};

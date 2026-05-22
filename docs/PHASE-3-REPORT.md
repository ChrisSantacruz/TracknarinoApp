# TrackNariño — Phase 3 Report: Offline-First & Sync Engine

**Date:** 2026-05-22  
**Status:** Complete  
**Scope:** Restart-safe local outbound persistence, GPS/alert/trip action queueing, bounded retry, connectivity awareness, ACK reconciliation, and honest offline UI states. No UI redesign, rerouting, background service, ETA engine, geofencing, Kafka/event bus, or distributed replay system was introduced.

---

## 1. Local Persistence Architecture

Phase 3 adds a Drift/SQLite local database in `trackarino_app/lib/offline/app_database.dart`.

Persisted tables:
- `outbound_queue_items`: pending outbound GPS updates, alerts, trip actions, retry state, ACK state, client timestamps, sequence, `clientEventId`, attempts, and server ACK JSON.
- `sync_metadata`: small key/value metadata table prepared for future sync cursors, replay windows, and policy metadata.

Drift was chosen over Hive because this phase needs ordered queue queries, deduplication by unique `clientEventId`, retry filtering by `nextRetryAt`, transactional inserts, and future schema migrations.

---

## 2. Queue Architecture

Outbound flow:

`Action -> local queue -> local UI state -> SyncEngine -> REST API -> ACK -> mark synced`

Implemented in:
- `offline/outbound_sync_repository.dart`
- `offline/sync_engine.dart`
- `offline/sync_types.dart`

The queue stores method, endpoint, payload JSON, operation type, timestamps, priority, FIFO flag, attempts, retry delay, failure reason, and ACK payload. Duplicate prevention is done locally through a unique `clientEventId`.

---

## 3. Sync Engine Behavior

`SyncEngine` initializes on app startup, resets interrupted `syncing` rows back to `pending`, listens for connectivity recovery, and processes due queue rows in priority/order.

Priority:
- Alerts: highest priority.
- Trip actions: high priority, FIFO prepared.
- GPS: lower priority, FIFO by creation/sequence.

The engine avoids overlapping sync runs and spaces sync attempts to prevent reconnect storms.

---

## 4. Retry Strategy

Retry state is persisted per item:
- `attempts`
- `nextRetryAt`
- `lastError`
- `status`

Retryable failures use bounded exponential backoff with jitter, capped at 30 minutes. Non-retryable API errors are kept visible as failed rows with a long retry delay so they do not spin forever.

---

## 5. GPS Offline Improvements

`LocationService` no longer drops failed GPS sends. It now queues GPS points through `SyncEngine.enqueueGps`.

Protections:
- Existing 10s send throttle remains.
- Existing movement threshold remains.
- Existing accuracy threshold remains.
- Timestamps and sequence are preserved.
- `clientEventId` is stable per point.
- Offline replay uses `source: offline_sync`.
- Unsent GPS queue is capped at 1000 rows to prevent storage/battery damage.
- Synced GPS queue rows are trimmed, keeping the latest 250 synced rows for audit/debug visibility.

No interpolation or fake movement was added.

---

## 6. Alert Reliability Improvements

Alerts are now write-first locally. `AlertaService.crearAlerta` queues the alert before returning local confirmation to the UI.

Preserved metadata:
- `clientEventId`
- client timestamp
- coordinates
- alert type
- description
- sharing flag

Backend alert persistence now stores `clientEventId` and handles duplicate alert replay by returning the existing alert instead of creating another one. Flutter alert success messages were changed to honest pending-sync wording.

---

## 7. Connectivity Architecture

`ConnectivityService` uses `connectivity_plus` for network interface changes and performs a backend reachability probe before triggering sync.

States:
- `offline`: no network interface.
- `networkOnly`: Wi-Fi/mobile exists but backend is not reachable.
- `internetReachable`: backend probe responds, sync may run.

This separates socket failure/realtime fallback from actual outbound sync readiness and avoids storming the API during captive portal or dead LTE states.

---

## 8. Reconciliation Strategy

Client reconciliation:
- Local queue row is the durable source until ACK.
- ACK marks row `synced`.
- Failed rows remain visible and retryable.
- Interrupted syncs are reset on startup.

Server reconciliation:
- GPS already uses `(camionero, clientEventId)` idempotency and monotonic latest-location updates.
- Alerts now use `(usuario, clientEventId)` idempotency.
- Trip acceptance now treats replay by the same assigned driver as a successful duplicate ACK.
- Trip start was already idempotent when already `en_ruta`.

Server truth remains authoritative. Offline trip actions are not shown as fully confirmed until the server accepts them.

---

## 9. Offline UI States

Without redesigning screens, Phase 3 adds a global `SyncStatusBanner`:
- Offline state.
- Backend unreachable state.
- Pending/syncing count.
- Failed sync count.

Alert and trip action snackbars were updated so the app does not fake synced success while an item is only queued.

---

## 10. Battery & Performance Protections

Protections added or preserved:
- Connectivity debounce.
- Minimum sync spacing.
- No background service yet.
- No isolates.
- Bounded batch processing.
- GPS queue cap.
- Synced GPS trimming.
- Existing GPS accuracy, interval, and movement throttles.
- No duplicate socket/listener changes.

---

## 11. Remaining Rerouting Blockers

Rerouting is still intentionally blocked:
- No route deviation detector.
- No ETA engine.
- No geofence/corridor engine.
- No alert-aware routing algorithm.
- No local route cache/replay model.
- No production routing provider/self-hosted OSRM policy.

---

## 12. Remaining Scalability Blockers

Phase 3 is mobile offline foundation, not distributed sync infrastructure.

Still needed later:
- Redis Socket.IO adapter for multi-node realtime.
- Sticky-session/load-balancer deployment plan.
- Server-side queue/audit trail for outbound operations.
- Admin sync observability dashboard.
- Compaction/archival policy for historical GPS.
- Integration tests for replay and conflict scenarios.

---

## 13. Remaining Production Blockers

Known blockers:
- Existing Flutter analyzer info/warnings remain in older screens/services.
- Existing dependency audit/version drift remains.
- No automated integration tests for offline replay against backend.
- No background sync/service yet.
- No Sentry/Crashlytics instrumentation.
- No user-facing failed-item detail screen yet, only global failed visibility.
- Alert image upload is still unsupported by the backend.

---

## 14. Recommended Next Phase

Recommended Phase 4: **Offline Observability & Conflict Hardening**.

Focus:
- Add a lightweight sync detail screen for failed/pending items.
- Add integration tests for GPS replay, alert replay, and trip action replay.
- Add server-side conflict metadata for trip actions.
- Add app resume sync policy.
- Add optional background sync only after battery and OS permission policy are reviewed.

Do not start rerouting or premium UI until offline replay has test coverage.

---

*End of Phase 3 report.*

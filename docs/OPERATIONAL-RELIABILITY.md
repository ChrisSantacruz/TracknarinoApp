# TrackNariño Operational Reliability

## Replay Guarantees

- Every outbound GPS point, alert, and offline trip action is persisted to SQLite before replay.
- `clientEventId` is the replay identity. The local queue enforces uniqueness and the backend preserves idempotency for GPS, alerts, and supported trip transitions.
- SyncEngine does not run overlapping replay loops. Concurrent triggers collapse into a single run or a delayed retry.
- Interrupted `syncing` rows are reset to `pending` on startup so app termination does not strand work.
- Retryable failures remain in the queue with persisted `attempts`, `lastError`, and `nextRetryAt`.
- Non-retryable API failures are retained as failed rows with long retry delay so operators can inspect and retry intentionally.

## Queue Guarantees

- Queue ordering is priority-first, then creation time, then sequence. Alerts replay before trip actions, and GPS replay remains FIFO within its priority.
- Pending actions are never deleted by retry logic.
- Synced GPS rows are trimmed only after ACK and only beyond the audit retention window.
- GPS unsent queue depth is capped to protect device storage and battery under prolonged offline operation.
- Session safety prevents a queued item for one local user from replaying under another authenticated user.

## Reconnect Behavior

- Realtime connects with Socket.IO websocket plus polling transport fallback.
- Socket listeners are registered outside reconnect callbacks and explicitly removed before reattachment.
- Fleet subscription is re-emitted after socket connection to restore contractor map updates.
- App resume triggers a bounded recovery: SyncEngine schedules replay and RealtimeService attempts reconnect.
- Resume recovery is spaced to avoid reconnect storms from rapid lifecycle changes.

## Degraded-State Behavior

- Connectivity is split into `offline`, `networkOnly`, and `internetReachable`.
- Sync replay only runs when backend reachability succeeds, not merely when a network interface exists.
- Socket failure moves UI state to fallback polling instead of pretending realtime is healthy.
- Contractor tracking keeps PollingController as the degraded realtime fallback.
- API and connectivity diagnostics are structured and sanitized.

## Socket Fallback Logic

- Socket.IO server supports websocket and polling transports.
- Server-side connection state recovery is enabled for short disconnect windows.
- Duplicate backend emits are suppressed by `eventId` memory dedupe.
- Client-side duplicate tracking and trip events are ignored by event ID.
- Socket reconnect failure keeps the app in fallback polling state until the next safe reconnect.

## Lifecycle Recovery Flow

1. App starts and initializes SyncEngine.
2. SyncEngine resets interrupted replay rows and subscribes to connectivity recovery.
3. AppLifecycleCoordinator subscribes to Flutter lifecycle events.
4. On resume, the coordinator schedules sync and reconnects realtime with spacing.
5. RealtimeService also observes lifecycle and safely disconnects socket on pause/detach.
6. Polling remains available when the socket is down.

## Observability

- Flutter logs use structured JSON with categories: app, connectivity, lifecycle, realtime, sync, replay, queue, and security.
- Backend logs use structured JSON for server startup, Mongo connectivity, socket lifecycle, event emission, and duplicate suppression.
- Sensitive fields such as tokens, authorization headers, secrets, passwords, and raw payloads are redacted.
- ErrorReporter provides a Sentry-ready hook without hardcoded DSNs or SDK coupling.

## Known Operational Limits

- Background sync is not implemented yet. Replay happens while the app process is active.
- No production Sentry/Crashlytics DSN is configured; only the error-reporting abstraction is ready.
- Socket.IO multi-node scaling still needs Redis adapter and sticky-session deployment policy.
- Admin queue observability is still limited to local sync UI surfaces.
- Alert image upload remains unsupported by backend.
- Full degraded-network validation still requires device/network lab execution beyond local deterministic tests.

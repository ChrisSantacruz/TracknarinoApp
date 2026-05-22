# TrackNariño Staging Failure Playbook

This playbook verifies that controlled failures surface as explicit degraded or failed states. It must never be used to convert missing controls into success.

## Command

```bash
cd Backend
npm run verify:staging-failures -- --api-url https://staging.example.com/api --scenario staging-failure-scenario.json
```

The scenario file must use real staging tokens, real route/fleet inputs, and explicit operator-controlled degradation steps.

## Required Failure Verifications

| Verification | Control Step | Expected Surface | Fail Condition |
|---|---|---|---|
| Provider timeout simulation | Configure route provider timeout or route to a controlled timeout endpoint | `/api/ors/ruta` returns explicit failure/degraded response | Route appears healthy through hidden fallback |
| Redis unavailable | Stop or firewall staging Redis while Socket.IO Redis is configured | Release gates expose `SOCKET_REDIS_ADAPTER_NOT_READY` | Adapter silently reports ready |
| Mongo degraded response | Degrade Mongo connection or use maintenance window | Health/readiness/release gates expose Mongo failure | API returns operational success while DB is unavailable |
| Socket.IO reconnect storm | Drive real reconnect pressure from staging clients | Diagnostics/release gates expose reconnect storm warning | Duplicate listeners or no degraded signal |
| Offline queue pressure | Send real queued requests under failed connectivity/API conditions | Failures remain explicit; no silent success | Critical alert or GPS replay disappears |
| Route invalidation burst | Trigger real route invalidations through staging route lifecycle | Route audit and release/regression surfaces show pressure | Multiple active routes or hidden invalidation pressure |
| Fleet overload | Run bbox/load scenario using real staging data | Latency/regression gates warn or fail honestly | Full-fleet overfetch hidden as successful readiness |

## Scenario File Skeleton

```json
{
  "name": "staging-failure-2026-05-22",
  "providerTimeout": {
    "token": "real-token",
    "payload": { "coordinates": [] },
    "expectedStatuses": [408, 500, 503],
    "expectedCodes": []
  },
  "redisUnavailable": {
    "enabled": true,
    "expectedCodes": ["SOCKET_REDIS_ADAPTER_NOT_READY"]
  },
  "mongoDegraded": {
    "enabled": true,
    "expectedCodes": ["MONGO_NOT_READY", "MONGO_NOT_CONNECTED"]
  },
  "socketReconnectStorm": {
    "enabled": true,
    "expectedCodes": ["RECONNECT_STORM_DETECTED"]
  },
  "offlineQueuePressure": {
    "token": "real-token",
    "requests": [
      { "method": "POST", "path": "/ubicacion", "body": {} }
    ]
  },
  "routeInvalidationBurst": {
    "enabled": true
  },
  "fleetOverload": {
    "enabled": true
  }
}
```

## Evidence Rules

- Every run writes a JSON report under `docs/staging-failure-runs/` unless overridden.
- Blocked checks are valid operational output and must remain blocked until the required control exists.
- Passing requires explicit failure/degraded state, not HTTP success alone.
- Attach the report to the release evidence manifest with SHA-256.
- Run `/api/operations/release-gates` before and after each controlled failure.

## Production Decision Rule

Do not promote to production while any controlled failure produces silent success, hidden fallback success, missing diagnostics, duplicate realtime listeners, or lost replay state.

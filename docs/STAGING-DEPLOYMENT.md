# Staging Deployment

Phase 10 staging must prove operational readiness before production promotion. The backend now exposes `GET /api/operations/readiness` with severity levels, Mongo/index checks, Redis Socket.IO adapter state, provider health, route persistence readiness, and deployment warnings.

## Required Services

- MongoDB with geospatial indexes built before load tests.
- Redis when validating multi-node Socket.IO.
- Routing provider configured through environment variables.
- Firebase credentials only when notification delivery is part of the staging gate.

## Environment Separation

Use environment variables only. Do not commit secrets.

- `NODE_ENV=staging`
- `MONGO_URI`
- `JWT_SECRET`
- `REDIS_URL` or `SOCKET_IO_REDIS_URL`
- `SOCKET_IO_REDIS_KEY`
- `TRACKNARINO_NODE_ID`
- `ROUTING_PROVIDER`
- `OSRM_BASE_URL` for self-hosted routing
- `SHUTDOWN_TIMEOUT_MS`

## Socket.IO Scaling Notes

Socket.IO Redis adapter readiness is exposed in readiness and diagnostics. Sticky sessions are still required when HTTP polling is enabled, even with Redis adapter, because a polling request can otherwise reach a node that does not own the Engine.IO session.

## Healthchecks

- `GET /api/health`: lightweight service health.
- `GET /api/operations/readiness`: deployment gate with critical/warning issues.
- `GET /api/operations/diagnostics`: authenticated operational telemetry for contractor/camionero scopes.

## Graceful Shutdown

The server closes HTTP, Socket.IO, Redis clients, and Mongo before exit. Configure platform termination grace above `SHUTDOWN_TIMEOUT_MS`.

## Production Blockers

- Missing critical readiness checks.
- Redis configured but adapter not ready.
- Missing geospatial indexes for fleet/corridor queries.
- No device-lab evidence bundle for degraded LTE, reconnect storm, lost signal, and GPS drift.
- Load reports showing uninvestigated failures or blocked suites required for the release scope.

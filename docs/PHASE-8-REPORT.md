# TrackNariño — Phase 8 Report: Server-Side Routing Scale, Geointelligence & Operational Route Persistence

**Date:** 2026-05-22  
**Status:** Implemented backend foundations with syntax validation  
**Scope:** Authenticated route persistence, route geometry deduplication, operational route audit trail, provider policy/diagnostics, route telemetry storage, route-specific Socket.IO rooms, corridor alert queries, viewport-aware fleet reads, and geospatial index hardening. Existing SyncEngine, RealtimeService, PollingController, OperationalRoutingController, offline replay/idempotency, route health semantics, clustering/intelligence layers, observability patterns, and current mobile routing contracts were preserved.

## 1. Route Persistence Architecture

- Added `OperationalRoute` as the server-side route lifecycle record.
- Persisted route identity, trip ownership, camionero/contractor ownership, geometry hash, provider, route version, active/inactive state, reroute reason, lineage, creation time, and replacement time.
- Active route reads are optimized by trip/state/version indexes.
- Route replacement is idempotency-ready through `clientEventId` and keeps only one active route per trip using a partial unique index.
- Default route responses are lightweight summaries; full geometry is returned only when explicitly requested.

## 2. Route Audit Trail System

- Added `RouteAuditRecord` for structured route lifecycle events.
- Supported operational events include route creation, replacement, invalidation, degradation, stale-route events, reroute requests/completion, provider failures, and corridor alert intersections.
- Audit metadata is sanitized to avoid storing raw geometry, encoded polylines, tokens, or oversized payloads.
- Audit records are indexed by trip, route, contractor, event type, and time for future analytics.

## 3. Geospatial Index Improvements

- Hardened latest-location reads with additional operational indexes on `UbicacionActual`.
- Added route persistence indexes for active route retrieval, route history, geometry hash lookups, and ownership-scoped reads.
- Added compound alert indexes for type/time and geospatial alert filtering.
- Added TTL planning hooks for audit and telemetry retention, intentionally disabled until archival policy is approved.

## 4. Viewport/Bbox Fleet APIs

- Extended `GET /api/contratistas/tracking/flota` with optional bbox filters: `minLng`, `minLat`, `maxLng`, `maxLat`.
- Added operational filters: `activeOnly`, `staleOnly`, `offlineOnly`, `activeTripOnly`, plus `status=active|stale|offline`.
- Added pagination metadata while preserving the existing `fleet` response shape for current clients.
- Bbox filtering uses Mongo geospatial predicates against latest known positions and avoids returning the full fleet when viewport parameters are provided.

## 5. Corridor Alert Query Engine

- Added `GET /api/alertas/corredor`.
- Supports bbox filtering, route-aware filtering by persisted `routeId`, severity filtering, recency limits, and capped result sizes.
- Prioritization is based only on real alert severity and timestamp.
- No fake risk prediction, ETA, traffic simulation, or ML scoring was introduced.

## 6. Routing Provider Policy Layer

- Added provider policy isolation in `routingProviderPolicy`.
- The current provider remains public OSRM through the existing `/api/ors/ruta` contract.
- Added timeout, retry count, correlation ID, structured provider diagnostics, latency tracking, failure tracking, and provider health semantics.
- Prepared provider naming for public OSRM, self-hosted OSRM, and Valhalla without implementing silent fallback.

## 7. Routing Observability Improvements

- Added `RouteTelemetryEvent` for production-safe route/provider telemetry.
- Captures provider latency, provider failures, route replacements, invalidations, degradation, stale events, reroute requests, and corridor alert intersections.
- Structured logs use the existing `operationalLogger` and avoid raw coordinate history or secrets.
- Correlation IDs are accepted by the routing provider path and route persistence path.

## 8. Socket.IO Routing Scale Preparation

- Added route-specific rooms using `route:<routeId>`.
- Added `route:join`, `route:state_changed`, and `route:audit_event`.
- Authorization is anchored to existing trip ownership checks before joining route rooms.
- Existing fleet, tracking, trip, alert, contractor, and camionero rooms remain unchanged.
- The event/room shape is Redis-adapter-ready without adding Redis prematurely.

## 9. Operational Diagnostics Foundation

- Added authenticated route diagnostics under `/api/routing/diagnostics`.
- Added provider health diagnostics under `/api/routing/provider-health`.
- Diagnostics are analytics-ready counts and health indicators, not dashboards or fake KPIs.
- Audit and telemetry collections provide future inputs for route invalidation hotspots, provider reliability, reroute frequency, and corridor intersection reports.

## 10. Route Geometry Optimization

- Added `RouteGeometry` as the deduplicated geometry store.
- Geometry is hashed using normalized coordinates and stored once by `geometryHash`.
- Route lifecycle records reference geometry by hash/object reference and keep lightweight summaries.
- Geometry is stored as encoded polyline with bbox and point count for compressed storage readiness.

## 11. Device-Lab Validation Readiness

- Route lifecycle records, audit events, correlation IDs, and telemetry events make long-trip testing traceable.
- Degraded LTE, reconnect storms, stale routes, provider failures, reroute bursts, and alert-dense corridors can now be analyzed from backend records.
- No device-lab result is claimed in this phase; physical validation remains required.

## 12. Operational Safety/Data Integrity Improvements

- Route persistence is authenticated and role-scoped.
- Contractors can only access trips they own; camioneros can only persist/read route data for assigned trips.
- Route replacement supports idempotency via `clientEventId`.
- Route audit access validates route ownership before returning history.
- Client route state is not trusted as authorization proof.

## 13. Performance/Scalability Audit

- Latest fleet viewport reads now support bbox and status filters to reduce polling payload size.
- Alert corridor reads are capped, indexed, and recency-bound.
- Route history is indexed by trip/version and active state.
- Geometry duplication is avoided by hash-based deduplication.
- Socket.IO route rooms reduce broad fanout for route-specific lifecycle events.

## 14. Remaining Production Blockers

- Existing MongoDB deployments must build the new indexes before high-load fleet/corridor use.
- Device-lab validation is still required for long Nariño corridors, tunnels, degraded LTE, GPS jitter, reconnect storms, and reroute bursts.
- No Redis Socket.IO adapter is installed yet; the room structure is ready but multi-node deployment still needs adapter and sticky-session policy.
- No self-hosted OSRM/Valhalla deployment is configured yet.
- No admin dashboard is implemented; only backend diagnostics foundations exist.
- Corridor route proximity is bounded and practical, but not a full map-matching engine.

## 15. Future Backend Scalability Readiness

- Provider policy isolates future self-hosted OSRM, Valhalla, and failover decisions.
- Route/audit/telemetry models are ready for Redis geo, Kafka/event streams, server-side clustering, convoy coordination, and enterprise dispatch analytics.
- Geometry summaries and hashes avoid architecture dead ends around route duplication.
- Socket route rooms prepare for event replay and multi-node routing fanout.

## 16. Recommended Next Phase

**Phase 9 — Operational Validation, Admin Diagnostics & Multi-Node Readiness**

Recommended order:
1. Run device-lab route validation for real Nariño corridors under degraded LTE and GPS jitter.
2. Build a read-only operational diagnostics/admin surface from route audit and telemetry records.
3. Add index verification scripts and staging migration checks for geospatial collections.
4. Add Redis Socket.IO adapter and sticky-session deployment policy.
5. Design self-hosted OSRM/Valhalla deployment and provider failover rules without silent route success.

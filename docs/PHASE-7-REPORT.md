# TrackNariño — Phase 7 Report: Smart Routing, Route Deviation & Operational Corridor Intelligence

**Date:** 2026-05-22  
**Status:** Implemented with focused routing-engine validation  
**Scope:** Client-side operational route intelligence around real backend/ORS route geometry, route deviation detection, corridor-aware alert scoring, route health semantics, controlled reroute lifecycle, premium corridor visualization, offline-safe route preservation, and routing diagnostics. SyncEngine, RealtimeService, PollingController, offline replay, lifecycle coordinator, Socket.IO contracts, clustering/intelligence layers, observability patterns, and backend APIs were preserved.

## 1. Route Deviation Architecture

- Added `OperationalRoutingController` as a pure route intelligence layer outside UI widgets.
- Active ORS route geometry is wrapped as an explicit `OperationalRouteCorridor`.
- Live GPS is compared against the active corridor using nearest-segment distance in meters.
- Deviation states now distinguish `onRoute`, `slight`, `significant`, and `invalid`.
- GPS jitter is controlled through consecutive-sample confirmation before route state escalation.
- Route invalidation is separated from small drift and significant deviation to avoid false reroutes.

## 2. Operational Corridor System

- Route corridors now have explicit tolerance width, creation time, route ID, and geometry validity.
- Corridor proximity checks support live GPS and alert intersection analysis.
- Degraded corridor segment windows are derived from real alert proximity to the route geometry.
- The implementation prepares future convoy overlays and safety intelligence without hardcoded danger zones.

## 3. Alert-Aware Routing Improvements

- Real `AlertaSeguridad` records are scored against the active route corridor.
- Scoring uses alert type severity, freshness, and corridor proximity.
- Severe corridor alerts can degrade route health and recommend reroute review.
- Alerts outside the corridor influence buffer are ignored for the active route decision.
- No synthetic danger score, predictive crime model, or fake traffic signal was introduced.

## 4. Intelligent Reroute System

- Reroutes are controlled, not automatic spam loops.
- Reroute triggers include severe deviation, blocked corridor, stale route, major alert cluster, and manual verification.
- Reroute attempts are cooldown-bound except explicit manual verification.
- Offline reroute is deferred and the current route is preserved.
- Route replacement shows a real provider-returned candidate before switching active route context.

## 5. Route Health Model

- Added shared route health states: `healthy`, `caution`, `degraded`, `rerouting`, `stale`, `invalid`, and `offline`.
- Health is calculated from corridor deviation, alert impact, route age, connectivity, and reroute lifecycle.
- Driver-facing copy now states whether the route is trustworthy, stale, offline, degraded, or being recalculated.
- Health transitions are logged through structured diagnostics.

## 6. Routing UX Improvements

- Route screen now shows an operational health chip over the map.
- Bottom route panel includes concise route trust reasoning and distance from corridor.
- Reroute actions use operational language: verify route or recalculate safely.
- Existing premium map controls, truck marker, destination marker, SOS, and alert reporting remain intact.
- Route duration is labeled as provider route duration, not a fake ETA.

## 7. Corridor Visualization Improvements

- Added corridor width visualization beneath the active route.
- Added degraded segment highlighting for real corridor alert impacts.
- Added reroute candidate visualization with restrained dashed styling.
- Visual hierarchy is preserved: corridor context, degraded risk, candidate route, active route, then markers.
- The map avoids neon effects, synthetic heat, and overloaded operational noise.

## 8. Routing Performance Audit

- Route distance checks are bounded by `maxSegmentsPerAssessment`.
- Diagnostics are throttled to avoid log spam during live GPS streams.
- Reroute attempts are cooldown-bound to prevent recalculation storms.
- Existing map rendering/clustering layers remain untouched.
- Corridor checks are pure in-memory operations over the current route geometry and alert list.

## 9. Offline / Degraded Routing Behavior

- Last known route is preserved when connectivity is offline or backend reachability is degraded.
- Offline route health is explicit and user-visible.
- Reroute is not faked offline; the UI explains that recalculation is deferred.
- Active route context, health state, and corridor reasoning remain available while offline.
- Existing SyncEngine/offline replay architecture was not modified.

## 10. Operational Safety Layer

- Danger semantics are normalized from real alert types.
- Corridor risk aggregation combines severity, freshness, and proximity.
- Caution escalates only from real deviation or real corridor alerts.
- Robbery, accident, landslide, blockage, protest, obstacle, traffic, and weather categories are handled without prediction.
- Safety semantics are isolated for future server-side and convoy intelligence.

## 11. Observability / Diagnostic Additions

- Added `OperationalLogCategory.routing`.
- Added structured logs for route replacement, route assessment, reroute start/finish/failure, and provider route requests.
- Route diagnostics avoid raw coordinate logging.
- Health, deviation, corridor alert count, reroute trigger, route point count, distance, and duration are logged in production-safe fields.
- Info logs remain suppressed in release mode by the existing logger policy.

## 12. Remaining Production Blockers

- Physical-device validation is still required for long trips, GPS jitter, tunnel/lost-signal scenarios, degraded LTE, and reconnect bursts.
- Backend route endpoint still needs production routing-provider policy, timeout policy review, and eventual self-hosted OSRM/Valhalla deployment design.
- Alert corridor fetch is still limited by existing nearby/recent alert APIs; a future corridor/bbox alert endpoint would reduce overfetch.
- No server-side route persistence or route audit model exists yet.
- No ETA or traffic engine exists; this phase intentionally did not fake either.

## 13. Future Routing Scalability Readiness

- Route intelligence is isolated from widgets and backend contracts.
- `OperationalRouteCorridor` can be replaced by server-provided route/corridor metadata later.
- Alert impact scoring can move server-side without rewriting route UI.
- Reroute triggers and confidence states prepare for OSRM/Valhalla, convoy routing, danger-zone intelligence, and route learning.
- Existing ORS/backend route contract remains compatible.

## 14. Recommended Next Phase

**Phase 8 — Server-Side Routing Scale & Route Persistence**

Recommended order:
1. Add authenticated server-side route persistence with active route ID, route geometry hash, and recalculation audit trail.
2. Add corridor/bbox alert query endpoint with geospatial indexes.
3. Define production routing-provider policy: timeout, retry, fallback, and self-hosted OSRM/Valhalla path.
4. Add device-lab route deviation validation with real GPS traces from Nariño corridors.
5. Add admin routing diagnostics view for reroute frequency, invalidation causes, and corridor alert intersections.

# Phase 13 - Operational Simulation Mode Report

## Architecture Decisions

- Added a `SIMULATION_DRIVER` session type issued by the backend through `/api/auth/simulation`. The backend returns a signed JWT for a deterministic non-persisted driver identity and does not create a permanent `User` document.
- Preserved marketplace integrity by making simulated acceptance local to the Flutter `TripStore`. The original opportunity remains `disponible` for real users and is not updated through the production accept endpoint.
- Added `SimulationRouteController` as a route progression layer that consumes the same route geometry used by the production route screen. It emits positions into `LocationService`, which keeps using `SyncEngine`, tracking APIs and Socket.IO replay paths.
- Extended `SyncEngine` with a simulation-only offline override. During signal loss, GPS points and alerts continue entering the existing outbound queue but replay is paused until recovery.
- Extended backend tracking validation so simulation JWTs can publish tracking points linked to an existing opportunity without requiring the opportunity to be assigned to a real persisted driver.

## Files Modified

- `Backend/routes/authRoutes.js`
- `Backend/middleware/authMiddleware.js`
- `Backend/utils/auth.js`
- `Backend/routes/ubicacionRoutes.js`
- `Backend/services/trackingService.js`
- `trackarino_app/lib/config/api_config.dart`
- `trackarino_app/lib/models/user_model.dart`
- `trackarino_app/lib/services/auth_service.dart`
- `trackarino_app/lib/services/location_service.dart`
- `trackarino_app/lib/offline/sync_engine.dart`
- `trackarino_app/lib/state/trip_store.dart`
- `trackarino_app/lib/screens/auth/login_screen.dart`
- `trackarino_app/lib/screens/camionero/oportunidades_screen.dart`
- `trackarino_app/lib/screens/camionero/camionero_home_screen.dart`
- `trackarino_app/lib/screens/camionero/ruta_viaje_screen.dart`
- `trackarino_app/lib/simulation/simulation_route_controller.dart`

## Validation Performed

- Session flow keeps using `AuthService`, secure storage, `SessionBootstrap` and `RealtimeService`.
- Simulated opportunity acceptance does not call `PUT /oportunidades/:id/aceptar`.
- Route movement follows route polyline points and emits through `LocationService`.
- Signal loss uses the existing outbound queue and blocks replay through `SyncEngine`.
- Signal recovery reconnects `RealtimeService` and triggers `SyncEngine.syncNow`.
- Alerts created during simulation continue using `AlertaService` and the existing alert queue.

## Limitations

- The current implementation is a thesis-demo operational path, not yet a server-side persisted `simulationTripInstance` collection.
- Stop events, route deviations and completion are logged locally through operational logs/UI state; dedicated persisted audit/telemetry records for these simulation events should be added server-side for production-grade analytics.
- Rating flow is not automatically launched after the completion card in this pass.
- Shared/client/contractor screens receive tracking via the existing tracking event path when subscribed to the opportunity rooms, but a full persisted simulation trip model would make visibility and historical inspection stronger.

## Future Production Migration Path

- Add a `SimulationTripInstance` backend model linked to `opportunityId`, with lifecycle states, stop events, deviations, replay status and completion summary.
- Add dedicated simulation lifecycle endpoints for accept, start, stop, recover, reroute and complete while reusing existing event publishers.
- Persist simulation audit and telemetry events through the existing route audit and route telemetry services.
- Add test coverage for simulation JWT auth, location replay, alert replay and marketplace non-mutation.
- Gate the feature behind an environment flag for demos and training environments.

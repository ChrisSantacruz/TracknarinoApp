# Frontend Stabilization Report

**Project:** TracknarinoApp / `trackarino_app`  
**Date:** 2026-05-22  
**Scope:** Single-phase Flutter frontend stabilization (auth, navigation, realtime alerts, map-first trips, visual cleanup). Backend contracts, SyncEngine semantics, and socket event names were not changed.

---

## Summary

The Flutter client was stabilized around explicit auth/bootstrap phases, role-specific shells with `IndexedStack`, shared `ChangeNotifier` stores for alerts and active trips, session-level realtime bindings, route caching for degraded/offline UX, and removal of diagnostic/sync surfaces from end-user navigation.

`flutter analyze lib` completes with **no errors** (warnings/info only: async `BuildContext`, deprecated APIs, legacy `print` in services).

---

## UX Fixes

| Area | Change |
|------|--------|
| **Auth bootstrap** | `AuthService` validates stored token on startup (`verificarToken`), exposes `AuthBootstrapPhase` (initializing, unauthenticated, authenticated, invalidRole). |
| **401 handling** | `ApiService.onUnauthorized` logs out and runs `SessionBootstrap.teardownSession`. |
| **Login** | Premium theme, `AuthFailure` messages (no raw exceptions), `SessionBootstrap` after login. |
| **Register** | `AuthFailure` handling, session bootstrap, explicit back button, pops register route after success. |
| **Invalid role** | `OperationalErrorState` with logout instead of silent wrong shell. |
| **Alerts** | Consolidated on `camionero/alertas_screen.dart`; removed broken image capture UI; `AlertStore` for list/map. |
| **Active trip / route** | `TripStore` + `RouteCacheService` (SyncMetadata); `RutaViajeScreen` follow mode, gesture disables follow, cached route when ORS fails. |
| **ORS** | `RouteProviderException`, 3 retries, safer geometry/distance parsing. |
| **Fleet map** | Poll merge respects newer realtime timestamps (avoids stale HTTP overwriting socket). |

---

## Flow Stabilization

1. **App entry** — `AuthWrapper` → initializing loader → login or role shell inside `RealtimeBindings`.
2. **Camionero** — Map-first tab 0; alerts, opportunities, profile in `IndexedStack` (state preserved).
3. **Contratista** — Operations, create trip (embedded), fleet map (`SeguimientoScreen` in stack), profile.
4. **Back navigation** — Detail screens use `push`; tab shells avoid `pushReplacement`; register pops on success.
5. **Logout** — `SessionBootstrap.teardownSession` (GPS stop, realtime disconnect) on both role shells.

---

## Removed from User-Facing Flows

| Item | Notes |
|------|--------|
| `OperationalDiagnosticsScreen` tab | Removed from contratista shell; file kept for internal/ops use. |
| `SyncCenterScreen` navigation | Removed from home shells and `SyncStatusBanner` tap targets. |
| `lib/screens/alertas_screen.dart` | Duplicate root alert screen **deleted**. |
| Sync center / diagnostics actions | No longer in AppBar or bottom nav. |
| Alert photo capture | Removed (backend upload unavailable). |
| Placeholder “Mis oportunidades” block | Removed from contratista operations tab. |

Backend files (`operational_diagnostics_service.dart`, `sync_center_screen.dart`, etc.) remain; they are not linked from primary UX.

---

## Navigation Changes

- **Manual `Navigator`** retained (no new router dependency).
- **`IndexedStack`** on `CamioneroHomeScreen` and `ContratistaHomeScreen` for stable tab state and fleet socket subscription while Flota tab is mounted.
- **`MaterialApp` home** remains `AuthWrapper`; role routing via `switch` on `user.tipoUsuario`.
- **Embedded screens** — `AlertasScreen`, `PerfilCamioneroScreen`, `CrearOportunidadScreen` support `embedded: true` to avoid nested scaffolds.

---

## Realtime Fixes

| Component | Behavior |
|-----------|----------|
| `RealtimeService` | `alertUpdates` stream, `alert:created` handler, dedupe reset on connect. |
| `RealtimeBindings` | Session-level listeners → `AlertStore.mergeFromRealtime`, `TripStore.refreshActiveTrip`. |
| `SessionBootstrap` | Connects socket for **camionero** and **contratista**; `subscribeFleet()` for contractors. |
| `AlertStore` | `refreshNearby`, `upsertLocal` after enqueue, realtime merge. |
| **Fleet poll** | Skips overwriting camionero entry when local realtime timestamp is newer. |

---

## Visual / Design System

- Auth screens aligned with `AppTheme`, `AppColors`, `AppSpacing`, operational SVG icons.
- Operational empty/error/skeleton/chips used on shells and fleet map where refactored.
- Graphite / deep-green map-first layout preserved; no fake KPIs, heatmaps, or AI placeholders added.
- `SyncStatusBanner` removed from `MaterialApp` builder (less debug noise at root).

---

## New / Key Files

| Path | Role |
|------|------|
| `lib/state/session_bootstrap.dart` | Post-auth / teardown side effects |
| `lib/state/alert_store.dart` | Shared alert state |
| `lib/state/trip_store.dart` | Active trip + route snapshot |
| `lib/services/route_cache_service.dart` | Route persistence via SyncMetadata |
| `lib/widgets/realtime_bindings.dart` | Socket → store wiring |

---

## Remaining Blockers / Follow-ups

| Item | Severity | Detail |
|------|----------|--------|
| Alert image upload | Medium | Backend endpoint not available; UI removed. |
| `print` in services | Low | `alerta_service`, `oportunidad_service`, `auth_service` still log to console. |
| `use_build_context_synchronously` | Low | Info-level lints on login/register/alerts after `await`. |
| Register UI parity | Low | Register form not fully restyled like login (spacing/theme partial). |
| Contractor alert markers on fleet map | Low | Alerts centralized in camionero flows; fleet map is tracking-focused. |
| Full device lab | Medium | Manual E2E on physical devices recommended before thesis demo. |

---

## Performance Notes

- `IndexedStack` avoids rebuilding/disposing tab subtrees on tab change.
- `context.watch` / stores reduce ad-hoc local alert/trip duplication on camionero home.
- Map follow mode reduces camera jumps when user is not gesturing.
- ORS retry backoff reduces route flicker; `OperationalRoutingController` cooldown unchanged.
- Fleet polling slows to 60s when socket healthy (10s fallback).

---

## Verification

### Analyzer

```bash
cd trackarino_app
flutter analyze lib
```

Result: **0 errors** at time of report.

### Code-path checklist

| Flow | Status |
|------|--------|
| Cold start → token restore / login | Implemented |
| 401 → logout | Implemented |
| Role routing (camionero / contratista) | Implemented |
| Invalid role screen | Implemented |
| Logout teardown | Implemented |
| Alert create → local upsert + sync queue | Implemented |
| Alert realtime → `AlertStore` | Implemented |
| Active trip refresh + route cache | Implemented |
| Route screen follow / degraded cache | Implemented |
| Diagnostics / sync center hidden from UX | Implemented |

### Recommended manual demo script

1. Login as camionero → map home, tabs, logout.  
2. Create alert → appears in list/map without manual refresh; verify offline queue snackbar.  
3. Accept/start trip → route screen, follow mode, airplane mode → cached route if previously loaded.  
4. Login as contratista → operations summary, fleet tab, realtime movement vs poll.  
5. Register new user → lands on correct shell, back from register works.

---

## Thesis Demo Readiness

**Ready for controlled demo** with known limits: no alert photos, diagnostics/sync only via dev builds if screens are opened programmatically, and staging backend/socket must be up for realtime portions.

Recommend demo path: **camionero map + active trip + alert creation**, then **contratista fleet map** with two devices or replayed tracking events.

---

## Constraints Honored

- No backend API or socket contract changes.  
- No new dependencies.  
- SyncEngine queue/idempotency untouched.  
- Operational diagnostics backend services untouched.  
- Plan file not modified.

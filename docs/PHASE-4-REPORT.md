# TrackNariño — Phase 4 Report: Premium Logistics UX & Operational Experience

**Date:** 2026-05-22  
**Status:** Complete  
**Scope:** Flutter presentation-layer upgrade — design system, role-based operational UX, honest offline/realtime surfaces, map ergonomics, loading/error/empty states, accessibility-oriented field usability. No backend, auth, sync engine, or realtime transport rewrites.

---

## 1. Design System Architecture

### Tokens (`trackarino_app/lib/theme/`)

| Module | Purpose |
|--------|---------|
| `app_colors.dart` | Graphite surfaces, deep green brand, operational status (active/stale/offline/sync), alert semantics, map colors |
| `app_spacing.dart` | 4–32px scale, 48dp min touch target, card/sheet radii |
| `app_theme.dart` | Light + dark `ThemeData` (M3), AppBar, cards, buttons, inputs, snackbars |

### Wired in

- [`main.dart`](../trackarino_app/lib/main.dart): `AppTheme.light`, `AppTheme.dark`, `ThemeMode.system`

### Reusable components (`trackarino_app/lib/widgets/operational/`)

- `OperationalStatusChip` — tracking/realtime labels with colorblind-friendly hues + icons
- `OperationalCard` — consistent elevated surfaces
- `OperationalEmptyState` / `OperationalErrorState`
- `OperationalSkeleton` / `OperationalLoadingPanel`
- `MapControlCluster` — zoom/recenter with 48dp targets
- `FleetMapMarker` — fleet truck markers by status
- `RealtimeConnectionChip` / `FleetMapLegend`

**Constraint honored:** presentation only; no new business logic in theme layer.

---

## 2. Navigation Improvements

| Role | Change |
|------|--------|
| Contratista | `BottomNavigationBar` → `NavigationBar` with clearer labels: Operaciones, Crear viaje, Flota, Perfil |
| Camionero | `NavigationBar`: Mapa, Viajes, Alertas, Perfil; dynamic AppBar titles per tab |
| Global | Auth wrapper unchanged; no GoRouter introduced |

**Friction reduction:** contractor FAB “Ver flota en mapa”; camionero AppBar quick access to Alertas; primary “Alertar” action enlarged on map status panel.

---

## 3. Contractor Dashboard Improvements

**File:** `contratista_home_screen.dart`

- Loads **real fleet summary** via `ContratistaTrackingService.fetchFleet()`
- Shows counts only from API truth: activos, señal antigua, sin señal, sin ubicación
- Explicit note: *“Sin métricas estimadas”*
- Pull-to-refresh + retry on fleet load failure
- Honest empty state when no GPS-available trucks
- Opportunities section states backend has no dedicated list endpoint in this view (no fake list)

---

## 4. Camionero UX Improvements

**Files:** `camionero_home_screen.dart`, `viaje_activo_banner.dart`

- Map-first home with shared `MapControlCluster`
- Themed route polyline (`AppColors.routeLine`) and navigation/destination markers
- `ViajeActivoBanner` redesigned with status chip, route hierarchy, larger actions
- Bottom status panel: operational chip, availability switch, **48dp+ Alertar** button
- Alert tab uses `OperationalEmptyState` with direct path to full alert map screen
- Alert marker colors aligned to semantic palette

**Preserved:** `LocationService`, `OportunidadService`, `AlertaService`, `ORSService`, offline queue behavior.

---

## 5. Map UX Improvements

### Contractor fleet (`seguimiento_screen.dart`)

- `FleetMapMarker` per truck with status color + initial
- `FleetMapLegend` (activo / señal antigua / sin señal)
- `RealtimeConnectionChip` in toolbar row
- `MapControlCluster` for zoom + fleet recenter
- Bottom sheet: removed fake “Pendiente” ETA/distance placeholders; shows route, placa, teléfono, carga, last update only
- Selected marker highlight via `AnimatedContainer`
- Embedded layout (no nested Scaffold AppBar) under contractor shell

### Camionero maps

- Shared controls and semantic colors on home + `ruta_viaje_screen.dart`
- Route screen: `OperationalLoadingPanel`, retryable `OperationalErrorState`, trip status chip in info panel

**Not implemented (by design):** animated playback, turn-by-turn, rerouting UI.

---

## 6. Offline / Realtime UX Improvements

### Global sync (`sync_status_banner.dart`)

| State | User-visible copy |
|-------|-------------------|
| Offline | Sin conexión; acciones en cola local |
| Network only | Red OK, servidor no alcanzable |
| Syncing | N acciones sincronizando |
| Pending | N en cola (tap → `SyncEngine.triggerSyncSoon`) |
| Failed | N con error (tap → retry) |

`AnimatedSwitcher` for non-jarring banner transitions.

### Realtime (contractor map)

- `RealtimeConnectionChip`: tiempo real activo / conectando / reconectando / respaldo polling / sin socket
- Polling intervals unchanged: 60s healthy socket, 10s fallback

**Honesty rule:** UI never implies full sync when queue pending; never hides offline/socket fallback.

---

## 7. Loading / Error / Empty State Improvements

| Surface | Before | After |
|---------|--------|-------|
| App startup | Generic spinner | `LoadingWidget` + skeleton line |
| Fleet map | Center spinner | `OperationalLoadingPanel` |
| Fleet errors | Red overlay text | `OperationalErrorState` + retry |
| Fleet empty | Plain text box | `OperationalEmptyState` + retry |
| Route calc | Basic card spinner | `OperationalLoadingPanel` |
| Route errors | Orange banner | Retryable error panel |
| Camionero alerts tab | Generic empty column | `OperationalEmptyState` |

---

## 8. Accessibility Improvements

- Minimum **48dp** touch targets on map controls and primary Alertar action
- High-contrast status colors (green / amber / red) with icon + text (not color-only)
- `ThemeMode.system` dark theme for outdoor/low-light
- Text scaling via theme text styles (no hardcoded-only layouts on new components)
- Reduced emoji noise in operational banners (professional copy)

---

## 9. Performance / Rendering Improvements

- Marker list built in dedicated `_buildMarkers()` (contractor map)
- Realtime updates patch in-place map entries; full reload only when unknown camionero
- `AnimatedSwitcher` / `AnimatedContainer` limited to banners and selection (lightweight)
- No extra map layers or playback isolates
- Const-friendly operational widgets where applicable

**Not done:** micro-optimizations across legacy 1100+ line screens beyond touched paths.

---

## 10. Motion System Improvements

- Banner cross-fade (`AnimatedSwitcher` ~220ms)
- Selected fleet marker border animation (~180ms)
- Contractor home tab body `AnimatedSwitcher` (~200ms)
- No GPU-heavy effects, parallax, or fake GPS interpolation

---

## 11. Remaining Rerouting Blockers

Unchanged from Phase 3 — still blocked:

- No route deviation detector
- No ETA engine tied to live traffic
- No geofence/corridor engine
- No alert-aware rerouting
- No local route cache/replay model
- No production OSRM/ORS deployment policy

Phase 4 only improved **display** of ORS-calculated routes; did not add rerouting.

---

## 12. Remaining Production Blockers

| Blocker | Notes |
|---------|-------|
| Contractor opportunity list API | Dashboard honestly states no dedicated list endpoint |
| Phase 3 replay test gap | Phase 3 recommended tests before large UI; Phase 4 proceeded per product request |
| Legacy analyzer warnings | Pre-existing `print`, `withOpacity`, async context infos in untouched files |
| Duplicate `screens/alertas_screen.dart` | Still unused duplicate; not removed in this phase |
| Background sync / sync detail screen | Still global banner only |
| Sentry/Crashlytics | Not added |
| Alert image upload | Backend still unsupported |

---

## 13. Recommended Next Phase

**Phase 5 — Offline Observability & Integration Hardening** (recommended before routing):

1. Sync detail screen (pending/failed queue rows)
2. Integration tests: GPS/alert/trip replay against backend
3. Remove duplicate alert screen file; consolidate alert UX
4. Contractor opportunities list endpoint + dashboard wiring
5. Optional: contractor map clustering when fleet > 50 trucks

**Phase 6 — Routing & Rerouting** only after replay tests pass.

---

## File Index (Phase 4 Touch Set)

**New**

- `trackarino_app/lib/theme/app_colors.dart`
- `trackarino_app/lib/theme/app_spacing.dart`
- `trackarino_app/lib/theme/app_theme.dart`
- `trackarino_app/lib/widgets/operational/*.dart` (8 files)

**Modified**

- `trackarino_app/lib/main.dart`
- `trackarino_app/lib/widgets/sync_status_banner.dart`
- `trackarino_app/lib/widgets/viaje_activo_banner.dart`
- `trackarino_app/lib/screens/common/loading_widget.dart`
- `trackarino_app/lib/screens/contratista/contratista_home_screen.dart`
- `trackarino_app/lib/screens/contratista/seguimiento_screen.dart`
- `trackarino_app/lib/screens/camionero/camionero_home_screen.dart`
- `trackarino_app/lib/screens/camionero/ruta_viaje_screen.dart`

**Not modified (stable layers)**

- `trackarino_app/lib/offline/*`
- `trackarino_app/lib/services/realtime_service.dart`
- `Backend/**`

---

## Validation

| Check | Result |
|-------|--------|
| `flutter analyze` on Phase 4 touched paths | Pass (0 errors; pre-existing infos in legacy files) |
| Backend/sync/realtime contracts | Unchanged |
| Fake KPIs / mock fleet | Not introduced |

---

*End of Phase 4 report.*

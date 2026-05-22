# Phase 10 Load Testing Guide

TrackNariño load validation must use staging data, scoped JWTs, real route/trip IDs, and captured device-lab artifacts. A blocked test is a valid result when evidence is missing; do not replace it with fake GPS, fake traffic, fake sessions, or synthetic operational success.

## Tooling

- `Backend/scripts/load/operationalLoadRunner.js`
- `Backend/scripts/load/scenario.example.json`
- Output: `Backend/docs/load-testing/load-summary-*.json`

Run:

```bash
cd Backend
npm run load:operations -- --scenario scripts/load/scenario.example.json --api-url https://staging.example.com/api
```

Write tests such as captured GPS bursts require explicit staging approval:

```bash
npm run load:operations -- --scenario scripts/load/staging-real.json --api-url https://staging.example.com/api --allow-writes
```

## Covered Gates

- Fleet bbox query stress through `GET /api/contratistas/tracking/flota`.
- Alert corridor query stress through `GET /api/alertas/corredor`.
- Telemetry/audit growth pressure through `GET /api/operations/diagnostics`.
- GPS burst validation only from real captured artifacts and only with `--allow-writes`.
- Socket room fanout/reconnect diagnostics remain blocked until a backend-approved Socket.IO client dependency is installed or an external load client is used.

## Required Evidence

- Scenario file with staging tokens, real route IDs, real bbox windows, and real corridor windows.
- Device-lab captures for long trip, degraded LTE, reconnect storm, tunnel/lost signal, GPS drift, battery-sensitive tracking, and memory pressure.
- `/api/operations/readiness` snapshot before and after the load window.
- Load report JSON with latency summaries, percentiles, failures, blocked suites, and dropped-event counters.

## Operational Gates

- No critical readiness issue from `/api/operations/readiness`.
- Mongo geospatial indexes present for fleet and alert queries.
- Redis Socket.IO adapter ready for multi-node staging, or the load report must state single-node scope.
- Sticky-session policy documented before multi-node Socket.IO validation.
- No unbounded metric growth; metrics windows are capped by `OPERATIONAL_METRICS_MAX_SAMPLES`.

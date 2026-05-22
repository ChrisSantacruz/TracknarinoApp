# Device-Lab Validation

Device-lab evidence must be captured from real devices and real staging services. The Phase 10 tooling preserves session IDs, correlation IDs, scenario labels, and timeline events without generating fake replay, fake GPS movement, or fake operational states.

## Flutter Capture Format

Flutter capture helpers live in:

- `trackarino_app/lib/device_lab/device_lab_capture_profile.dart`
- `trackarino_app/lib/device_lab/device_lab_bundle.dart`

Each bundle includes:

- `sessionId`
- `correlationId`
- scenario type
- UTC timestamps
- captured timeline events
- diagnostics payloads
- replay policy stating that interpolation is intentionally absent

## Backend Bundle Tool

Backend evidence bundling:

```bash
cd Backend
npm run device-lab:bundle -- --input-dir validation-runs --output-dir docs/load-testing --scenario degraded_lte
```

The bundle tool hashes each capture artifact and stitches route/reconnect/recovery timeline events from real diagnostics captures.

## Required Scenarios

- Long-trip session capture.
- Degraded-network capture.
- Reconnect-storm capture.
- Tunnel/lost-signal capture.
- GPS drift capture.
- Battery-sensitive tracking diagnostics.
- Memory-pressure diagnostics.

## Execution Requirements

- Use staging JWTs scoped to the tested contractor/camionero.
- Record physical device model, OS version, app build, backend build, and network conditions in labels.
- Capture `/api/operations/diagnostics` before and after each run with `npm run capture:diagnostics`.
- Attach generated bundle hashes to the release checklist.

## Non-Goals

- No video replay.
- No map playback interpolation.
- No fabricated route state.
- No generated GPS traces.
- No fake sync success.

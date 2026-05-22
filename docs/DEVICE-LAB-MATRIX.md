# TrackNariño Device-Lab Execution Matrix

Device-lab validation must be executed on real devices against staging services. This matrix defines evidence requirements only; it does not claim execution success.

## Evidence Integrity Requirements

- Every scenario must include `sessionId`, `correlationId`, device model, OS version, app build, backend build, network conditions, operator, signed timestamp, and scenario type.
- Every artifact must include SHA-256 in the release evidence manifest.
- Required artifacts: pre/post `/api/operations/diagnostics`, `/api/operations/release-gates`, Flutter capture bundle, relevant device logs, and a short operator note.
- Required validation: `npm run validate:evidence -- --manifest <manifest.json>`.
- Scenario signing metadata must include `signedBy`, `signedAt`, and an immutable artifact list.
- Replay expectations must list required timeline event types. Missing timeline or broken correlation is a release blocker.

## Scenarios

| Scenario | Required Evidence | Pass Criteria | Fail Criteria | Artifacts & Diagnostics | Replay Expectations | Operational Notes |
|---|---|---|---|---|---|---|
| Long route | Full route session, route audit timeline, GPS upload diagnostics | Route remains traceable; no route persistence gaps | Missing route timeline, stale route hidden as healthy | Flutter bundle, diagnostics before/after, route audit snapshot | `route.created`, location updates, no unexplained route gap | Use Nariño-like corridor duration, not a short demo loop |
| Degraded LTE | Network condition log, reconnect/retry diagnostics | Degraded state visible; offline queue persists unsent work | Silent success, dropped alerts, fake synced state | Device network logs, diagnostics, queue snapshot | Connectivity degradation and recovery events | Use real carrier throttling or lab network control |
| Reconnect storms | Socket diagnostics, reconnect counters | Storm surfaces as warning/degraded without duplicate listeners | Duplicate events, hidden reconnect pressure | Realtime diagnostics, socket room snapshot | reconnect/disconnect events correlated to session | Validate listener cleanup after repeated lifecycle changes |
| Tunnel/no signal | GPS loss period, offline queue state | Offline state is explicit and route is preserved | Route recalculated offline as if provider was available | Device location logs, queue snapshot, route health capture | signal loss, deferred replay, recovery | No generated GPS points inside tunnel/no-signal period |
| GPS drift | Accuracy samples, route deviation diagnostics | Jitter does not trigger false invalidation before thresholds | Aggressive reroute loop or ignored severe deviation | Flutter routing diagnostics, route health snapshot | drift samples and route health transitions | Preserve raw observed accuracy, no smoothing artifact claims |
| Stale sockets | Socket room occupancy and cleanup evidence | Stale sockets are cleaned or surfaced | Orphan subscriptions or duplicate room joins | Realtime diagnostics before/after | disconnect/cleanup events | Validate after app killed or network switched |
| Offline replay recovery | Queue rows, replay ACKs, timeline correlation | FIFO/priority replay succeeds or failures remain visible | Lost critical alert or hidden failed replay | Queue snapshot, server ACKs, diagnostics | queued, replay_started, replay_success/failure | Alerts must replay before lower-priority GPS |
| Reroute bursts | Route audit and provider telemetry | Cooldowns prevent route replacement storm | Excessive route replacements or provider overload hidden | Route audit, provider latency, diagnostics | reroute requested/completed/rejected events | Burst source must be real device or controlled staging input |
| Alert-heavy corridor | Corridor alert query evidence | Severe real alerts degrade route health visibly | Synthetic risk, overloaded map, missing alert intersections | Corridor query snapshot, route health, UI capture | corridor.alert_intersection events | No predictive or AI risk score |
| Dense fleet tracking | Bbox query snapshots, map render diagnostics | Payloads bounded; map stays usable | Full-fleet overfetch or UI rebuild storm | Load report, Flutter diagnostics, bbox response | fleet visibility events where available | Use real staging fleet rows or approved captured artifacts |
| Background/resume lifecycle | Lifecycle logs, replay/reconnect evidence | Resume triggers bounded recovery | Duplicate listeners, sync storms, orphan timers | Flutter lifecycle log, diagnostics, queue snapshot | paused/resumed/recovery events | Must include Android and iOS device coverage before production |
| Battery saver mode | OS battery mode, tracking interval evidence | App surfaces degraded/background constraints honestly | Claims continuous background tracking without OS permission | OS screenshots/logs, Flutter capture, diagnostics | delayed recovery events | Android OEM behavior must be recorded per device |
| Thermal throttling conditions | Device thermal state and memory snapshots | UI remains stable; degraded diagnostics captured | Crash, unbounded memory growth, hidden failure | DevTools/profile trace, memory snapshot, diagnostics | no fabricated performance pass | Run in profile mode where possible |
| App killed/restored | Kill/restore timeline and queue state | Queue persists; realtime reconnects once | Lost queue rows or duplicate replay | Queue DB snapshot, diagnostics before/after | interrupted_sync reset and replay evidence | Do not claim background execution while app is terminated |
| Route replacement storms | Route lineage and active-route checks | One active route per trip; lineage remains intact | Multiple active routes or missing audit chain | Route persistence snapshot, index snapshot, diagnostics | route.replaced with previous route metadata | Requires Mongo index verification before load |

## Release Manifest Shape

```json
{
  "releaseId": "staging-2026-05-22",
  "generatedAt": "2026-05-22T00:00:00.000Z",
  "scenarios": [
    {
      "id": "degraded-lte-01",
      "type": "degraded_lte",
      "sessionId": "real-session-id",
      "correlationId": "real-correlation-id",
      "signedBy": "operator-name",
      "signedAt": "2026-05-22T00:00:00.000Z",
      "artifacts": [
        { "type": "dependency_audit", "path": "audit.json", "sha256": "..." }
      ],
      "timeline": [],
      "replayExpectation": {
        "requiredEventTypes": ["connectivity.degraded", "replay.started"]
      }
    }
  ]
}
```

The validator rejects missing artifacts, missing hashes, hash mismatches, stale evidence, missing timelines, broken correlations, and unmet replay expectations.

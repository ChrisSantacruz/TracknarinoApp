const fs = require('fs/promises');
const path = require('path');

const DEFAULT_API_URL = process.env.TRACKNARINO_API_URL || 'http://localhost:4000/api';

function readArgs() {
  const args = process.argv.slice(2);
  const options = {
    apiUrl: DEFAULT_API_URL,
    scenarioFile: process.env.LOAD_SCENARIO_FILE,
    outputDir: process.env.LOAD_OUTPUT_DIR || path.join('docs', 'load-testing'),
    allowWrites: process.env.LOAD_ALLOW_WRITES === 'true',
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--api-url') options.apiUrl = args[index + 1];
    if (arg === '--scenario') options.scenarioFile = args[index + 1];
    if (arg === '--output-dir') options.outputDir = args[index + 1];
    if (arg === '--allow-writes') options.allowWrites = true;
  }
  return options;
}

function percentile(values, rank) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.ceil((rank / 100) * sorted.length) - 1);
  return sorted[index];
}

function summarize(name, samples, blockedReason = null) {
  const latencies = samples.filter((sample) => sample.ok).map((sample) => sample.latencyMs);
  return {
    name,
    blocked: Boolean(blockedReason),
    blockedReason,
    requests: samples.length,
    failures: samples.filter((sample) => !sample.ok).length,
    droppedEvents: samples.filter((sample) => sample.dropped === true).length,
    latencyMs: {
      min: latencies.length ? Math.min(...latencies) : null,
      avg: latencies.length ? latencies.reduce((sum, value) => sum + value, 0) / latencies.length : null,
      p50: percentile(latencies, 50),
      p95: percentile(latencies, 95),
      p99: percentile(latencies, 99),
      max: latencies.length ? Math.max(...latencies) : null,
    },
  };
}

async function timedFetch(url, options) {
  const startedAt = Date.now();
  try {
    const response = await fetch(url, options);
    return {
      ok: response.ok,
      status: response.status,
      latencyMs: Date.now() - startedAt,
    };
  } catch (error) {
    return {
      ok: false,
      error: error.message,
      latencyMs: Date.now() - startedAt,
    };
  }
}

function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

async function runFleetBboxStress(apiUrl, scenario) {
  const token = scenario.contractorToken;
  const bboxes = scenario.fleetBboxes || [];
  if (!token || bboxes.length === 0) {
    return summarize('fleet_bbox_query_stress', [], 'contractorToken and fleetBboxes are required.');
  }

  const samples = [];
  for (const bbox of bboxes) {
    const query = new URLSearchParams({
      minLng: bbox.minLng,
      minLat: bbox.minLat,
      maxLng: bbox.maxLng,
      maxLat: bbox.maxLat,
      limit: bbox.limit || 100,
    });
    samples.push(await timedFetch(`${apiUrl}/contratistas/tracking/flota?${query}`, {
      headers: authHeaders(token),
    }));
  }
  return summarize('fleet_bbox_query_stress', samples);
}

async function runAlertCorridorStress(apiUrl, scenario) {
  const token = scenario.userToken || scenario.contractorToken;
  const corridorQueries = scenario.corridorQueries || [];
  if (!token || corridorQueries.length === 0) {
    return summarize('alert_corridor_query_stress', [], 'userToken/contractorToken and corridorQueries are required.');
  }

  const samples = [];
  for (const corridor of corridorQueries) {
    const query = new URLSearchParams(corridor);
    samples.push(await timedFetch(`${apiUrl}/alertas/corredor?${query}`, {
      headers: authHeaders(token),
    }));
  }
  return summarize('alert_corridor_query_stress', samples);
}

async function runDiagnosticsGrowthStress(apiUrl, scenario) {
  const token = scenario.userToken || scenario.contractorToken;
  if (!token) {
    return summarize('telemetry_audit_growth_queries', [], 'userToken or contractorToken is required.');
  }

  const windows = scenario.diagnosticWindows || [24, 72, 168];
  const samples = [];
  for (const sinceHours of windows) {
    samples.push(await timedFetch(`${apiUrl}/operations/diagnostics?sinceHours=${sinceHours}&limit=100`, {
      headers: authHeaders(token),
    }));
  }
  return summarize('telemetry_audit_growth_queries', samples);
}

async function runCapturedGpsBurst(apiUrl, scenario, allowWrites) {
  if (!allowWrites) {
    return summarize('gps_update_burst_from_capture', [], 'Writes are disabled. Pass --allow-writes with a staging token and real captured GPS artifacts.');
  }

  const token = scenario.driverToken;
  const updates = scenario.capturedGpsUpdates || [];
  if (!token || updates.length === 0) {
    return summarize('gps_update_burst_from_capture', [], 'driverToken and capturedGpsUpdates are required.');
  }

  const samples = [];
  for (const update of updates) {
    samples.push(await timedFetch(`${apiUrl}/ubicacion`, {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify(update),
    }));
  }
  return summarize('gps_update_burst_from_capture', samples);
}

async function runSocketRoomDiagnostics(scenario) {
  let ioClient = null;
  try {
    ioClient = require('socket.io-client');
  } catch (error) {
    return {
      name: 'socket_room_fanout_and_reconnect',
      blocked: true,
      blockedReason: 'socket.io-client is not installed in Backend dependencies; install only with explicit approval before active socket load.',
    };
  }

  const realtimeUrl = scenario.realtimeUrl;
  const token = scenario.userToken || scenario.contractorToken || scenario.driverToken;
  const rooms = scenario.socketRooms || [];
  if (!realtimeUrl || !token || rooms.length === 0) {
    return {
      name: 'socket_room_fanout_and_reconnect',
      blocked: true,
      blockedReason: 'realtimeUrl, token, and socketRooms are required.',
    };
  }

  const startedAt = Date.now();
  const reconnects = { attempts: 0, connected: 0, errors: 0 };
  const socket = ioClient(realtimeUrl, {
    auth: { token },
    reconnectionAttempts: scenario.reconnectAttempts || 3,
    transports: ['websocket', 'polling'],
  });

  await new Promise((resolve) => {
    const timeout = setTimeout(resolve, scenario.socketWindowMs || 10000);
    socket.on('connect', () => {
      reconnects.connected += 1;
      for (const room of rooms) {
        socket.emit(room.event || 'route:join', room.payload || {});
      }
    });
    socket.io.on('reconnect_attempt', () => { reconnects.attempts += 1; });
    socket.on('connect_error', () => { reconnects.errors += 1; });
    socket.on('disconnect', () => {});
    setTimeout(() => socket.disconnect(), Math.max(1000, (scenario.socketWindowMs || 10000) - 1000));
    socket.on('disconnect', () => {
      clearTimeout(timeout);
      resolve();
    });
  });

  return {
    name: 'socket_room_fanout_and_reconnect',
    blocked: false,
    elapsedMs: Date.now() - startedAt,
    reconnectMetrics: reconnects,
  };
}

async function main() {
  const options = readArgs();
  if (!options.scenarioFile) {
    throw new Error('LOAD_SCENARIO_FILE or --scenario is required. Use real staging IDs/tokens/captured artifacts only.');
  }

  const scenario = JSON.parse(await fs.readFile(options.scenarioFile, 'utf8'));
  const startedAt = new Date();
  const results = [];
  results.push(await runFleetBboxStress(options.apiUrl, scenario));
  results.push(await runAlertCorridorStress(options.apiUrl, scenario));
  results.push(await runDiagnosticsGrowthStress(options.apiUrl, scenario));
  results.push(await runCapturedGpsBurst(options.apiUrl, scenario, options.allowWrites));
  results.push(await runSocketRoomDiagnostics(scenario));

  const readiness = await timedFetch(`${options.apiUrl}/operations/readiness`, {});
  const report = {
    generatedAt: new Date().toISOString(),
    startedAt: startedAt.toISOString(),
    apiUrl: options.apiUrl,
    scenarioName: scenario.name || 'unnamed_staging_scenario',
    allowWrites: options.allowWrites,
    operationalTruthPolicy: 'No fake GPS, fake sessions, fake telemetry, or fake success. Blocked suites remain blocked until real artifacts are provided.',
    readiness,
    results,
  };

  await fs.mkdir(options.outputDir, { recursive: true });
  const outputPath = path.join(options.outputDir, `load-summary-${startedAt.toISOString().replace(/[:.]/g, '-')}.json`);
  await fs.writeFile(outputPath, JSON.stringify(report, null, 2));
  console.log(`Operational load report written: ${outputPath}`);
}

main().catch((error) => {
  console.error(`Operational load runner failed: ${error.message}`);
  process.exit(1);
});

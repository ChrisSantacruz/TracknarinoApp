const fs = require('fs/promises');
const path = require('path');
const axios = require('axios');

const DEFAULT_SCENARIOS = [
  'long_narino_corridor',
  'degraded_lte',
  'tunnel_lost_signal',
  'reconnect_storm',
  'gps_jitter',
  'reroute_burst',
  'dense_alert_corridor',
  'high_density_fleet',
];

function readArgs() {
  const args = process.argv.slice(2);
  const options = {
    apiUrl: process.env.TRACKNARINO_API_URL || 'http://localhost:4000/api',
    token: process.env.TRACKNARINO_VALIDATION_TOKEN,
    sinceHours: Number(process.env.TRACKNARINO_VALIDATION_SINCE_HOURS || 24),
    scenario: process.env.TRACKNARINO_VALIDATION_SCENARIO || 'manual_capture',
    outputDir: process.env.TRACKNARINO_VALIDATION_OUTPUT_DIR || 'validation-runs',
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--api-url') options.apiUrl = args[index + 1];
    if (arg === '--token') options.token = args[index + 1];
    if (arg === '--since-hours') options.sinceHours = Number(args[index + 1]);
    if (arg === '--scenario') options.scenario = args[index + 1];
    if (arg === '--output-dir') options.outputDir = args[index + 1];
  }

  return options;
}

async function main() {
  const options = readArgs();
  if (!options.token) {
    throw new Error('TRACKNARINO_VALIDATION_TOKEN o --token es obligatorio para capturar diagnósticos.');
  }

  const startedAt = new Date();
  const response = await axios.get(`${options.apiUrl}/operations/diagnostics`, {
    params: { sinceHours: options.sinceHours, limit: 100 },
    headers: { Authorization: `Bearer ${options.token}` },
    timeout: 30000,
  });

  const diagnostics = response.data?.diagnostics;
  if (!diagnostics) {
    throw new Error('El backend no retornó diagnostics.');
  }

  const capture = {
    capturedAt: new Date().toISOString(),
    scenario: options.scenario,
    supportedScenarios: DEFAULT_SCENARIOS,
    apiUrl: options.apiUrl.replace(/\/api$/, '/api'),
    windowHours: options.sinceHours,
    elapsedMs: Date.now() - startedAt.getTime(),
    diagnostics,
  };

  await fs.mkdir(options.outputDir, { recursive: true });
  const fileName = `${options.scenario}-${startedAt.toISOString().replace(/[:.]/g, '-')}.json`;
  const outputPath = path.join(options.outputDir, fileName);
  await fs.writeFile(outputPath, JSON.stringify(capture, null, 2));
  console.log(`Operational diagnostics captured: ${outputPath}`);
}

main().catch((error) => {
  console.error(`Operational diagnostics capture failed: ${error.message}`);
  process.exit(1);
});

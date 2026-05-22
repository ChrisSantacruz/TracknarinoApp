const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

function readArgs() {
  const args = process.argv.slice(2);
  const options = {
    inputDir: process.env.DEVICE_LAB_INPUT_DIR || 'validation-runs',
    outputDir: process.env.DEVICE_LAB_OUTPUT_DIR || path.join('docs', 'load-testing'),
    scenario: process.env.DEVICE_LAB_SCENARIO || 'manual_device_lab',
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--input-dir') options.inputDir = args[index + 1];
    if (arg === '--output-dir') options.outputDir = args[index + 1];
    if (arg === '--scenario') options.scenario = args[index + 1];
  }
  return options;
}

async function readJsonFiles(inputDir) {
  const entries = await fs.readdir(inputDir, { withFileTypes: true });
  const files = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.json'))
    .map((entry) => path.join(inputDir, entry.name));

  const captures = [];
  for (const file of files) {
    const raw = await fs.readFile(file, 'utf8');
    const hash = crypto.createHash('sha256').update(raw).digest('hex');
    captures.push({
      file,
      sha256: hash,
      content: JSON.parse(raw),
    });
  }
  return captures;
}

function extractTimeline(captures) {
  return captures.flatMap((capture) => {
    const diagnostics = capture.content.diagnostics || {};
    return (diagnostics.timeline || []).map((event) => ({
      sourceFile: path.basename(capture.file),
      scenario: capture.content.scenario,
      routeId: event.routeId,
      tripId: event.tripId,
      eventType: event.eventType,
      reason: event.reason,
      severity: event.severity,
      correlationId: event.correlationId,
      occurredAt: event.occurredAt,
    }));
  }).sort((a, b) => new Date(a.occurredAt).getTime() - new Date(b.occurredAt).getTime());
}

async function main() {
  const options = readArgs();
  const captures = await readJsonFiles(options.inputDir);
  if (captures.length === 0) {
    throw new Error('No JSON capture artifacts found. Run capture:diagnostics after real device-lab scenarios.');
  }

  const generatedAt = new Date();
  const bundle = {
    generatedAt: generatedAt.toISOString(),
    scenario: options.scenario,
    policy: 'Evidence bundle only. This script does not fabricate sessions, GPS movement, telemetry, or validation success.',
    captures: captures.map((capture) => ({
      file: path.basename(capture.file),
      sha256: capture.sha256,
      capturedAt: capture.content.capturedAt,
      scenario: capture.content.scenario,
      windowHours: capture.content.windowHours,
    })),
    timeline: extractTimeline(captures),
    correlationIds: Array.from(new Set(extractTimeline(captures).map((event) => event.correlationId).filter(Boolean))),
  };

  await fs.mkdir(options.outputDir, { recursive: true });
  const outputPath = path.join(options.outputDir, `device-lab-bundle-${generatedAt.toISOString().replace(/[:.]/g, '-')}.json`);
  await fs.writeFile(outputPath, JSON.stringify(bundle, null, 2));
  console.log(`Device-lab diagnostics bundle written: ${outputPath}`);
}

main().catch((error) => {
  console.error(`Device-lab bundle failed: ${error.message}`);
  process.exit(1);
});

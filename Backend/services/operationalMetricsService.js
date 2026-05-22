const DEFAULT_WINDOW_MS = Number(process.env.OPERATIONAL_METRICS_WINDOW_MS || 5 * 60 * 1000);
const MAX_SAMPLES_PER_METRIC = Number(process.env.OPERATIONAL_METRICS_MAX_SAMPLES || 500);

const counters = new Map();
const samples = new Map();

function now() {
  return Date.now();
}

function pruneEntries(entries, windowMs = DEFAULT_WINDOW_MS) {
  const cutoff = now() - windowMs;
  while (entries.length > 0 && entries[0].at < cutoff) {
    entries.shift();
  }
  while (entries.length > MAX_SAMPLES_PER_METRIC) {
    entries.shift();
  }
}

function metricKey(name, dimensions = {}) {
  const dimensionKey = Object.keys(dimensions)
    .sort()
    .map((key) => `${key}:${dimensions[key]}`)
    .join('|');
  return dimensionKey ? `${name}|${dimensionKey}` : name;
}

function recordCounter(name, amount = 1, dimensions = {}) {
  const key = metricKey(name, dimensions);
  const entries = counters.get(key) || [];
  entries.push({ at: now(), amount: Number(amount) || 0, dimensions });
  pruneEntries(entries);
  counters.set(key, entries);
}

function recordLatency(name, latencyMs, dimensions = {}) {
  const value = Number(latencyMs);
  if (!Number.isFinite(value) || value < 0) return;

  const key = metricKey(name, dimensions);
  const entries = samples.get(key) || [];
  entries.push({ at: now(), value, dimensions });
  pruneEntries(entries);
  samples.set(key, entries);
}

function percentile(values, percentileRank) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.ceil((percentileRank / 100) * sorted.length) - 1);
  return sorted[index];
}

function summarizeCounters(windowMs) {
  return Array.from(counters.entries()).map(([key, entries]) => {
    pruneEntries(entries, windowMs);
    const total = entries.reduce((sum, entry) => sum + entry.amount, 0);
    return {
      key,
      total,
      samples: entries.length,
      dimensions: entries[entries.length - 1]?.dimensions || {},
    };
  }).filter((metric) => metric.samples > 0);
}

function summarizeSamples(windowMs) {
  return Array.from(samples.entries()).map(([key, entries]) => {
    pruneEntries(entries, windowMs);
    const values = entries.map((entry) => entry.value);
    const total = values.reduce((sum, value) => sum + value, 0);
    return {
      key,
      samples: values.length,
      min: values.length ? Math.min(...values) : null,
      max: values.length ? Math.max(...values) : null,
      avg: values.length ? total / values.length : null,
      p50: percentile(values, 50),
      p95: percentile(values, 95),
      p99: percentile(values, 99),
      dimensions: entries[entries.length - 1]?.dimensions || {},
    };
  }).filter((metric) => metric.samples > 0);
}

async function timeAsync(name, dimensions, operation) {
  const startedAt = now();
  try {
    const result = await operation();
    recordLatency(name, now() - startedAt, { ...dimensions, outcome: 'success' });
    return result;
  } catch (error) {
    recordLatency(name, now() - startedAt, { ...dimensions, outcome: 'failure' });
    recordCounter(`${name}.failures`, 1, dimensions);
    throw error;
  }
}

function getOperationalMetricsSnapshot(windowMs = DEFAULT_WINDOW_MS) {
  return {
    generatedAt: new Date().toISOString(),
    windowMs,
    bounds: {
      maxSamplesPerMetric: MAX_SAMPLES_PER_METRIC,
    },
    counters: summarizeCounters(windowMs),
    latency: summarizeSamples(windowMs),
  };
}

module.exports = {
  recordCounter,
  recordLatency,
  timeAsync,
  getOperationalMetricsSnapshot,
};

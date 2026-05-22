const fs = require('fs/promises');
const path = require('path');

function issue(severity, code, message, details = {}) {
  return { severity, code, message, details };
}

function metricByKey(metrics, keyFragment) {
  return (metrics.latency || []).find((metric) => metric.key.includes(keyFragment));
}

function counterByKey(metrics, keyFragment) {
  return (metrics.counters || []).find((metric) => metric.key.includes(keyFragment));
}

function ratioChange(current, baseline) {
  if (!Number.isFinite(current) || !Number.isFinite(baseline) || baseline <= 0) return null;
  return (current - baseline) / baseline;
}

async function readBaseline(baselinePath) {
  if (!baselinePath) return null;
  const raw = await fs.readFile(path.resolve(baselinePath), 'utf8');
  return JSON.parse(raw);
}

function compareLatency({ label, current, baseline, threshold, issues }) {
  if (!current || !baseline) {
    issues.push(issue('warning', 'REGRESSION_SIGNAL_MISSING', `No hay muestras suficientes para ${label}.`, { label }));
    return;
  }

  const change = ratioChange(current.p95, baseline.p95);
  if (change !== null && change > threshold) {
    issues.push(issue('warning', 'LATENCY_REGRESSION', `${label} aumentó p95 sobre el umbral.`, {
      label,
      currentP95: current.p95,
      baselineP95: baseline.p95,
      change,
      threshold,
    }));
  }
}

function compareCounter({ label, current, baseline, threshold, issues }) {
  if (!current || !baseline) {
    issues.push(issue('warning', 'REGRESSION_COUNTER_MISSING', `No hay contadores suficientes para ${label}.`, { label }));
    return;
  }

  const change = ratioChange(current.total, baseline.total);
  if (change !== null && change > threshold) {
    issues.push(issue('warning', 'COUNTER_REGRESSION', `${label} creció sobre el umbral.`, {
      label,
      currentTotal: current.total,
      baselineTotal: baseline.total,
      change,
      threshold,
    }));
  }
}

async function detectOperationalRegressions({ metrics, baselinePath = process.env.RELEASE_REGRESSION_BASELINE_PATH }) {
  const issues = [];
  const baseline = await readBaseline(baselinePath).catch((error) => ({
    __readError: error.message,
  }));

  if (!baselinePath) {
    return {
      checked: false,
      passed: false,
      baselinePath: null,
      issues: [
        issue('warning', 'REGRESSION_BASELINE_NOT_CONFIGURED', 'RELEASE_REGRESSION_BASELINE_PATH no está configurado; no se puede comparar regresión operacional.'),
      ],
      signals: [],
    };
  }

  if (baseline?.__readError) {
    return {
      checked: false,
      passed: false,
      baselinePath,
      issues: [
        issue('critical', 'REGRESSION_BASELINE_UNREADABLE', 'No se pudo leer el baseline de regresión operacional.', {
          error: baseline.__readError,
        }),
      ],
      signals: [],
    };
  }

  const baselineMetrics = baseline.operationalMetrics || baseline.metrics || baseline;
  const threshold = Number(process.env.RELEASE_REGRESSION_THRESHOLD || 0.25);
  const checks = [
    ['route latency', metricByKey(metrics, 'route'), metricByKey(baselineMetrics, 'route')],
    ['provider latency', metricByKey(metrics, 'provider'), metricByKey(baselineMetrics, 'provider')],
    ['bbox query latency', metricByKey(metrics, 'bbox'), metricByKey(baselineMetrics, 'bbox')],
    ['socket reconnect latency', metricByKey(metrics, 'socket'), metricByKey(baselineMetrics, 'socket')],
  ];

  for (const [label, current, base] of checks) {
    compareLatency({ label, current, baseline: base, threshold, issues });
  }

  const counterChecks = [
    ['replay failures', counterByKey(metrics, 'replay'), counterByKey(baselineMetrics, 'replay')],
    ['reroute bursts', counterByKey(metrics, 'reroute'), counterByKey(baselineMetrics, 'reroute')],
    ['offline queue growth', counterByKey(metrics, 'queue'), counterByKey(baselineMetrics, 'queue')],
    ['memory pressure snapshots', counterByKey(metrics, 'memory'), counterByKey(baselineMetrics, 'memory')],
  ];

  for (const [label, current, base] of counterChecks) {
    compareCounter({ label, current, baseline: base, threshold, issues });
  }

  return {
    checked: true,
    passed: !issues.some((item) => item.severity === 'critical'),
    baselinePath: path.resolve(baselinePath),
    threshold,
    signals: checks.map(([label, current, base]) => ({
      label,
      currentP95: current?.p95 ?? null,
      baselineP95: base?.p95 ?? null,
    })),
    issues,
  };
}

module.exports = {
  detectOperationalRegressions,
};

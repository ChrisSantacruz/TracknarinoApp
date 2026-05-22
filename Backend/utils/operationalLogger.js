const SENSITIVE_KEYS = ['token', 'authorization', 'password', 'secret', 'payload'];

function sanitizeValue(value) {
  if (value == null) return value;
  if (typeof value === 'string') {
    return value.length > 500 ? `${value.slice(0, 500)}...` : value;
  }
  if (Array.isArray(value)) return value.map(sanitizeValue);
  if (typeof value === 'object') return sanitizeFields(value);
  return value;
}

function sanitizeFields(fields = {}) {
  return Object.entries(fields).reduce((safe, [key, value]) => {
    const lowerKey = key.toLowerCase();
    safe[key] = SENSITIVE_KEYS.some((sensitiveKey) => lowerKey.includes(sensitiveKey))
      ? '[redacted]'
      : sanitizeValue(value);
    return safe;
  }, {});
}

function write(level, category, event, fields = {}) {
  if (process.env.NODE_ENV === 'production' && level === 'debug') return;

  const entry = {
    ts: new Date().toISOString(),
    level,
    category,
    event,
    ...sanitizeFields(fields),
  };

  const line = JSON.stringify(entry);
  if (level === 'error') console.error(line);
  else if (level === 'warning') console.warn(line);
  else console.info(line);
}

module.exports = {
  info: (category, event, fields) => write('info', category, event, fields),
  warning: (category, event, fields) => write('warning', category, event, fields),
  error: (category, event, fields) => write('error', category, event, fields),
};

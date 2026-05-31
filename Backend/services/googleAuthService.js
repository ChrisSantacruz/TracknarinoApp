const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const path = require('path');

const client = new OAuth2Client();

function readClientIdFromConfigFile() {
  const configPath = String(process.env.GOOGLE_OAUTH_CLIENT_CONFIG || '').trim();
  if (!configPath) return null;

  const resolvedPath = path.isAbsolute(configPath)
    ? configPath
    : path.join(__dirname, '..', configPath);

  if (!fs.existsSync(resolvedPath)) return null;

  const parsed = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
  return parsed.web?.client_id
    || parsed.installed?.client_id
    || parsed.android?.client_id
    || parsed.ios?.client_id
    || null;
}

function getAllowedClientIds() {
  const ids = String(process.env.GOOGLE_CLIENT_IDS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  const configClientId = readClientIdFromConfigFile();
  if (configClientId && !ids.includes(configClientId)) {
    ids.push(configClientId);
  }
  return ids;
}

async function verifyGoogleIdToken(idToken) {
  const allowedAudiences = getAllowedClientIds();
  if (allowedAudiences.length === 0) {
    const error = new Error('GOOGLE_CLIENT_IDS no esta configurado');
    error.statusCode = 503;
    error.code = 'GOOGLE_AUTH_NOT_CONFIGURED';
    throw error;
  }

  const ticket = await client.verifyIdToken({
    idToken,
    audience: allowedAudiences,
  });
  const payload = ticket.getPayload();

  if (!payload?.sub || !payload.email) {
    const error = new Error('Token de Google sin identidad verificable');
    error.statusCode = 401;
    error.code = 'GOOGLE_TOKEN_INVALID';
    throw error;
  }

  if (payload.email_verified !== true) {
    const error = new Error('El correo de Google no esta verificado');
    error.statusCode = 401;
    error.code = 'GOOGLE_EMAIL_NOT_VERIFIED';
    throw error;
  }

  const hostedDomain = String(process.env.GOOGLE_ALLOWED_HOSTED_DOMAIN || '').trim();
  if (hostedDomain && payload.hd !== hostedDomain) {
    const error = new Error('Dominio de Google no permitido');
    error.statusCode = 403;
    error.code = 'GOOGLE_DOMAIN_FORBIDDEN';
    throw error;
  }

  return {
    googleSub: payload.sub,
    correo: payload.email.toLowerCase(),
    nombre: payload.name || payload.email,
    fotoPerfil: payload.picture || '',
    audience: payload.aud,
  };
}

module.exports = {
  verifyGoogleIdToken,
};

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const User = require('../models/User');

const credPath = path.join(__dirname, '../config/firebase-key.json');
let fcmEnabled = false;

function getServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }
  if (fs.existsSync(credPath)) {
    return require(credPath);
  }
  return null;
}

const serviceAccount = getServiceAccount();

if (serviceAccount) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    fcmEnabled = true;
    console.log('✅ Firebase Admin inicializado (FCM habilitado)');
  } catch (err) {
    console.error('⚠️ Error inicializando Firebase Admin:', err.message);
    fcmEnabled = false;
  }
} else {
  console.warn('⚠️ Archivo de credenciales de Firebase no encontrado. FCM deshabilitado en este entorno.');
}

async function enviarNotificacionFCM(deviceToken, titulo, cuerpo, data = {}) {
  if (!fcmEnabled) {
    return { skipped: true, reason: 'FCM_DISABLED' };
  }

  const mensaje = {
    notification: {
      title: titulo,
      body: cuerpo
    },
    data: Object.fromEntries(
      Object.entries(data || {}).map(([key, value]) => [key, String(value)])
    ),
    token: deviceToken
  };

  try {
    const response = await admin.messaging().send(mensaje);
    console.log('✅ Notificación enviada:', response);
    return response;
  } catch (error) {
    console.error('❌ Error al enviar notificación:', error);
    throw error;
  }
}

function isInvalidTokenError(error) {
  return [
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ].includes(error?.code);
}

async function invalidateUserToken(userId, token) {
  await User.updateOne(
    { _id: userId, 'fcmTokens.token': token },
    {
      $set: {
        'fcmTokens.$.invalidatedAt': new Date(),
      },
    }
  );
  await User.updateOne(
    { _id: userId, deviceToken: token },
    { $set: { deviceToken: '' } }
  );
}

async function enviarNotificacionUsuario(userId, titulo, cuerpo, data = {}) {
  const usuario = await User.findById(userId).select('deviceToken fcmTokens');
  if (!usuario) return { sent: 0, skipped: true, reason: 'USER_NOT_FOUND' };

  const tokens = new Set();
  if (usuario.deviceToken) tokens.add(usuario.deviceToken);
  for (const entry of usuario.fcmTokens || []) {
    if (entry.token && !entry.invalidatedAt) tokens.add(entry.token);
  }

  let sent = 0;
  for (const token of tokens) {
    try {
      const response = await enviarNotificacionFCM(token, titulo, cuerpo, data);
      if (!response?.skipped) sent += 1;
    } catch (error) {
      if (isInvalidTokenError(error)) {
        await invalidateUserToken(usuario._id, token);
      } else {
        throw error;
      }
    }
  }

  return { sent };
}

module.exports = { enviarNotificacionFCM, enviarNotificacionUsuario };

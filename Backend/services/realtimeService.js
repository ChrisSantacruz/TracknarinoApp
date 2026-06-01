const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Oportunidad = require('../models/Oportunidad');
const OperationalRoute = require('../models/OperationalRoute');
const ChatMessage = require('../models/ChatMessage');
const { getJwtSecret } = require('../utils/auth');
const operationalLogger = require('../utils/operationalLogger');
const { recordCounter, recordLatency } = require('./operationalMetricsService');

const EVENTS = Object.freeze({
  CONNECTION_STATE: 'connection:state',
  TRACKING_LOCATION_UPDATED: 'tracking:location_updated',
  TRIP_STATE_CHANGED: 'trip:state_changed',
  ALERT_CREATED: 'alert:created',
  FLEET_SUBSCRIBE: 'fleet:subscribe',
  TRIP_JOIN: 'trip:join',
  ROUTE_JOIN: 'route:join',
  ROUTE_STATE_CHANGED: 'route:state_changed',
  ROUTE_AUDIT_EVENT: 'route:audit_event',
  CHAT_JOIN: 'chat:join',
  CHAT_MESSAGE: 'chat:message',
  CHAT_MESSAGE_CREATED: 'chat:message_created',
  CHAT_DELIVERED: 'chat:delivered',
  CHAT_READ: 'chat:read',
  OFFER_CREATED: 'offer:created',
  OFFER_ACCEPTED: 'offer:accepted',
  OFFER_REJECTED: 'offer:rejected',
});

const ROOM_PREFIX = Object.freeze({
  CONTRACTOR: 'contractor',
  CLIENT: 'client',
  CAMIONERO: 'camionero',
  TRIP: 'trip',
  CHAT: 'chat',
  ROUTE: 'route',
  ALERTS: 'alerts',
});

let io = null;
const socketPresence = new Map();
const emittedEventIds = new Map();
const EVENT_DEDUPE_LIMIT = 500;
const SERVER_NODE_ID = process.env.TRACKNARINO_NODE_ID || `node-${process.pid}`;
const RECENT_CONNECTION_WINDOW_MS = 60 * 1000;
const RECONNECT_STORM_THRESHOLD = Number(process.env.SOCKET_RECONNECT_STORM_THRESHOLD || 40);

const realtimeDiagnostics = {
  initializedAt: null,
  adapter: {
    type: 'memory',
    status: 'local',
    configured: false,
    channelPrefix: process.env.SOCKET_IO_REDIS_KEY || 'tracknarino:socket.io',
    lastError: null,
  },
  counters: {
    connectionsAccepted: 0,
    disconnects: 0,
    authFailures: 0,
    forbiddenJoins: 0,
    joinFailures: 0,
    eventsEmitted: 0,
    duplicateEmitsSuppressed: 0,
    roomJoins: 0,
    duplicateSubscriptions: 0,
    staleSocketCleanups: 0,
  },
  recentConnections: [],
};

function room(prefix, id) {
  return `${prefix}:${id}`;
}

function rememberEvent(eventId) {
  if (!eventId) return true;
  if (emittedEventIds.has(eventId)) return false;

  emittedEventIds.set(eventId, Date.now());
  if (emittedEventIds.size > EVENT_DEDUPE_LIMIT) {
    const oldestKey = emittedEventIds.keys().next().value;
    emittedEventIds.delete(oldestKey);
  }
  return true;
}

function trackConnectionEvent(kind, socket) {
  const now = Date.now();
  realtimeDiagnostics.recentConnections.push({
    kind,
    at: now,
    role: socket?.usuario?.tipoUsuario,
  });
  realtimeDiagnostics.recentConnections = realtimeDiagnostics.recentConnections.filter(
    (event) => now - event.at <= RECENT_CONNECTION_WINDOW_MS,
  );
}

function joinRoom(socket, targetRoom) {
  if (!targetRoom) return false;
  if (socket.rooms.has(targetRoom)) {
    realtimeDiagnostics.counters.duplicateSubscriptions += 1;
    recordCounter('socket.duplicate_subscription', 1, { roomType: targetRoom.split(':')[0] || 'unknown' });
    return false;
  }

  socket.join(targetRoom);
  realtimeDiagnostics.counters.roomJoins += 1;
  recordCounter('socket.room_join', 1, { roomType: targetRoom.split(':')[0] || 'unknown' });
  return true;
}

function getBearerToken(socket) {
  const authToken = socket.handshake.auth?.token;
  if (typeof authToken === 'string' && authToken.trim()) {
    return authToken.trim();
  }

  const header = socket.handshake.headers?.authorization;
  if (typeof header === 'string' && header.startsWith('Bearer ')) {
    return header.slice(7).trim();
  }

  return null;
}

function authenticateSocket(socket, next) {
  const token = getBearerToken(socket);
  if (!token) {
    realtimeDiagnostics.counters.authFailures += 1;
    return next(new Error('AUTH_TOKEN_MISSING'));
  }

  try {
    const decoded = jwt.verify(token, getJwtSecret());
    socket.usuario = {
      ...decoded,
      id: decoded.id || decoded._id,
      tipoUsuario: decoded.tipoUsuario || decoded.tipo,
    };

    if (!socket.usuario.id || !socket.usuario.tipoUsuario) {
      return next(new Error('AUTH_TOKEN_INVALID'));
    }

    return next();
  } catch (error) {
    realtimeDiagnostics.counters.authFailures += 1;
    return next(new Error('AUTH_TOKEN_INVALID'));
  }
}

async function canJoinTrip(socket, oportunidadId) {
  if (!mongoose.Types.ObjectId.isValid(oportunidadId)) return false;

  const userId = socket.usuario.id;
  const role = socket.usuario.tipoUsuario;
  const query = { _id: oportunidadId };

  if (role === 'contratista') {
    query.$or = [
      { contratista: userId },
      { ownerId: userId },
    ];
  } else if (role === 'cliente') {
    query.ownerId = userId;
  } else if (role === 'camionero') {
    query.camioneroAsignado = userId;
  } else {
    return false;
  }

  return Boolean(await Oportunidad.exists(query));
}

async function canJoinRoute(socket, { routeId, tripId }) {
  let oportunidadId = tripId;

  if (routeId) {
    const routeDoc = await OperationalRoute.findOne({ routeId }).select('tripId').lean();
    if (!routeDoc) return { allowed: false, oportunidadId: null };
    oportunidadId = routeDoc.tripId?.toString?.();
  }

  const allowed = await canJoinTrip(socket, oportunidadId);
  return { allowed, oportunidadId };
}

function attachBaseRooms(socket) {
  const userId = socket.usuario.id;
  const role = socket.usuario.tipoUsuario;

  if (role === 'contratista') {
    joinRoom(socket, room(ROOM_PREFIX.CONTRACTOR, userId));
    joinRoom(socket, room(ROOM_PREFIX.ALERTS, 'contractors'));
  }

  if (role === 'cliente') {
    joinRoom(socket, room(ROOM_PREFIX.CLIENT, userId));
  }

  if (role === 'camionero') {
    joinRoom(socket, room(ROOM_PREFIX.CAMIONERO, userId));
  }
}

function registerSocketHandlers(socket) {
  attachBaseRooms(socket);

  socketPresence.set(socket.id, {
    userId: socket.usuario.id,
    role: socket.usuario.tipoUsuario,
    connectedAt: new Date(),
  });

  operationalLogger.info('realtime', 'socket_connected', {
    socketId: socket.id,
    userId: socket.usuario.id,
    role: socket.usuario.tipoUsuario,
  });

  socket.emit(EVENTS.CONNECTION_STATE, {
    version: 1,
    status: 'connected',
    socketId: socket.id,
    serverTime: new Date().toISOString(),
  });

  socket.on(EVENTS.FLEET_SUBSCRIBE, (ack) => {
    const role = socket.usuario.tipoUsuario;
    if (role !== 'contratista' && role !== 'cliente') {
      if (typeof ack === 'function') ack({ ok: false, error: 'FORBIDDEN' });
      return;
    }

    const fleetRoom = role === 'cliente'
      ? room(ROOM_PREFIX.CLIENT, socket.usuario.id)
      : room(ROOM_PREFIX.CONTRACTOR, socket.usuario.id);
    joinRoom(socket, fleetRoom);
    if (typeof ack === 'function') ack({ ok: true, room: fleetRoom });
  });

  socket.on(EVENTS.TRIP_JOIN, async (payload, ack) => {
    const oportunidadId = payload?.oportunidadId;
    try {
      const allowed = await canJoinTrip(socket, oportunidadId);
      if (!allowed) {
        realtimeDiagnostics.counters.forbiddenJoins += 1;
        if (typeof ack === 'function') ack({ ok: false, error: 'FORBIDDEN' });
        return;
      }

      joinRoom(socket, room(ROOM_PREFIX.TRIP, oportunidadId));
      if (typeof ack === 'function') ack({ ok: true, room: room(ROOM_PREFIX.TRIP, oportunidadId) });
    } catch (error) {
      realtimeDiagnostics.counters.joinFailures += 1;
      if (typeof ack === 'function') ack({ ok: false, error: 'JOIN_FAILED' });
    }
  });

  socket.on(EVENTS.ROUTE_JOIN, async (payload, ack) => {
    const routeId = typeof payload?.routeId === 'string' ? payload.routeId.trim() : null;
    const tripId = payload?.tripId;

    try {
      const { allowed, oportunidadId } = await canJoinRoute(socket, { routeId, tripId });
      if (!allowed) {
        realtimeDiagnostics.counters.forbiddenJoins += 1;
        if (typeof ack === 'function') ack({ ok: false, error: 'FORBIDDEN' });
        return;
      }

      if (routeId) joinRoom(socket, room(ROOM_PREFIX.ROUTE, routeId));
      if (oportunidadId) joinRoom(socket, room(ROOM_PREFIX.TRIP, oportunidadId));

      if (typeof ack === 'function') {
        ack({
          ok: true,
          room: routeId ? room(ROOM_PREFIX.ROUTE, routeId) : room(ROOM_PREFIX.TRIP, oportunidadId),
        });
      }
    } catch (error) {
      realtimeDiagnostics.counters.joinFailures += 1;
      if (typeof ack === 'function') ack({ ok: false, error: 'JOIN_FAILED' });
    }
  });

  socket.on(EVENTS.CHAT_JOIN, async (payload, ack) => {
    const oportunidadId = payload?.oportunidadId || payload?.tripId;
    try {
      const allowed = await canJoinTrip(socket, oportunidadId);
      if (!allowed) {
        realtimeDiagnostics.counters.forbiddenJoins += 1;
        if (typeof ack === 'function') ack({ ok: false, error: 'FORBIDDEN' });
        return;
      }

      joinRoom(socket, room(ROOM_PREFIX.TRIP, oportunidadId));
      joinRoom(socket, room(ROOM_PREFIX.CHAT, oportunidadId));
      if (typeof ack === 'function') ack({ ok: true, room: room(ROOM_PREFIX.CHAT, oportunidadId) });
    } catch (error) {
      realtimeDiagnostics.counters.joinFailures += 1;
      if (typeof ack === 'function') ack({ ok: false, error: 'JOIN_FAILED' });
    }
  });

  socket.on(EVENTS.CHAT_MESSAGE, async (payload, ack) => {
    const oportunidadId = payload?.oportunidadId || payload?.tripId;
    const message = String(payload?.message || '').trim();
    try {
      if (!message || message.length > 2000) {
        if (typeof ack === 'function') ack({ ok: false, error: 'INVALID_MESSAGE' });
        return;
      }
      const allowed = await canJoinTrip(socket, oportunidadId);
      if (!allowed) {
        realtimeDiagnostics.counters.forbiddenJoins += 1;
        if (typeof ack === 'function') ack({ ok: false, error: 'FORBIDDEN' });
        return;
      }

      const chatMessage = await ChatMessage.create({
        trip: oportunidadId,
        sender: socket.usuario.id,
        senderRole: socket.usuario.tipoUsuario,
        message,
        deliveredTo: [{ user: socket.usuario.id, at: new Date() }],
        readBy: [{ user: socket.usuario.id, at: new Date() }],
      });

      const eventPayload = {
        version: 1,
        eventId: `chat.message:${chatMessage._id}`,
        type: 'chat.message',
        messageId: chatMessage._id.toString(),
        oportunidadId: oportunidadId.toString(),
        senderId: socket.usuario.id,
        senderRole: socket.usuario.tipoUsuario,
        message: chatMessage.message,
        createdAt: chatMessage.createdAt.toISOString(),
      };

      emitToRooms(EVENTS.CHAT_MESSAGE_CREATED, eventPayload, [
        room(ROOM_PREFIX.CHAT, oportunidadId),
        room(ROOM_PREFIX.TRIP, oportunidadId),
      ]);
      if (typeof ack === 'function') ack({ ok: true, message: eventPayload });
    } catch (error) {
      if (typeof ack === 'function') ack({ ok: false, error: 'CHAT_SEND_FAILED' });
    }
  });

  socket.on(EVENTS.CHAT_READ, async (payload, ack) => {
    const oportunidadId = payload?.oportunidadId || payload?.tripId;
    try {
      const allowed = await canJoinTrip(socket, oportunidadId);
      if (!allowed) {
        if (typeof ack === 'function') ack({ ok: false, error: 'FORBIDDEN' });
        return;
      }

      await ChatMessage.updateMany(
        {
          trip: oportunidadId,
          'readBy.user': { $ne: socket.usuario.id },
        },
        {
          $push: { readBy: { user: socket.usuario.id, at: new Date() } },
        }
      );

      const eventPayload = {
        version: 1,
        eventId: `chat.read:${oportunidadId}:${socket.usuario.id}:${Date.now()}`,
        type: 'chat.read',
        oportunidadId: oportunidadId.toString(),
        userId: socket.usuario.id,
        readAt: new Date().toISOString(),
      };
      emitToRooms(EVENTS.CHAT_READ, eventPayload, [room(ROOM_PREFIX.CHAT, oportunidadId)]);
      if (typeof ack === 'function') ack({ ok: true });
    } catch (error) {
      if (typeof ack === 'function') ack({ ok: false, error: 'CHAT_READ_FAILED' });
    }
  });

  socket.on('disconnecting', (reason) => {
    operationalLogger.info('realtime', 'socket_disconnecting', {
      socketId: socket.id,
      reason,
      rooms: Array.from(socket.rooms),
    });
  });

  socket.on('disconnect', (reason) => {
    socketPresence.delete(socket.id);
    realtimeDiagnostics.counters.disconnects += 1;
    operationalLogger.info('realtime', 'socket_disconnected', {
      socketId: socket.id,
      reason,
    });
  });
}

async function configureRedisAdapter(socketServer) {
  const redisUrl = process.env.SOCKET_IO_REDIS_URL || process.env.REDIS_URL;
  if (!redisUrl) {
    realtimeDiagnostics.adapter = {
      ...realtimeDiagnostics.adapter,
      type: 'memory',
      status: 'local',
      configured: false,
      lastError: null,
    };
    operationalLogger.info('realtime', 'socket_adapter_local', {
      nodeId: SERVER_NODE_ID,
    });
    return;
  }

  try {
    const { createAdapter } = require('@socket.io/redis-adapter');
    const { createClient } = require('redis');
    const pubClient = createClient({
      url: redisUrl,
      socket: {
        reconnectStrategy: (retries) => Math.min(retries * 100, 3000),
      },
    });
    const subClient = pubClient.duplicate();

    pubClient.on('error', (error) => {
      realtimeDiagnostics.adapter.lastError = error.message;
      operationalLogger.warning('realtime', 'socket_redis_pub_error', {
        error: error.message,
      });
    });
    subClient.on('error', (error) => {
      realtimeDiagnostics.adapter.lastError = error.message;
      operationalLogger.warning('realtime', 'socket_redis_sub_error', {
        error: error.message,
      });
    });

    await Promise.all([pubClient.connect(), subClient.connect()]);
    socketServer.adapter(createAdapter(pubClient, subClient, {
      key: process.env.SOCKET_IO_REDIS_KEY || 'tracknarino:socket.io',
    }));

    realtimeDiagnostics.adapter = {
      type: 'redis',
      status: 'ready',
      configured: true,
      channelPrefix: process.env.SOCKET_IO_REDIS_KEY || 'tracknarino:socket.io',
      lastError: null,
    };
    socketServer.redisClients = { pubClient, subClient };
    operationalLogger.info('realtime', 'socket_redis_adapter_ready', {
      nodeId: SERVER_NODE_ID,
      channelPrefix: realtimeDiagnostics.adapter.channelPrefix,
    });
  } catch (error) {
    realtimeDiagnostics.adapter = {
      ...realtimeDiagnostics.adapter,
      type: 'redis',
      status: 'degraded_local_fallback',
      configured: true,
      lastError: error.message,
    };
    operationalLogger.error('realtime', 'socket_redis_adapter_failed_local_fallback', {
      nodeId: SERVER_NODE_ID,
      error: error.message,
    });
  }
}

function initializeRealtime(server, corsOptions) {
  realtimeDiagnostics.initializedAt = new Date();
  io = new Server(server, {
    cors: corsOptions,
    pingInterval: 25000,
    pingTimeout: 20000,
    maxHttpBufferSize: 1e6,
    transports: ['websocket', 'polling'],
    connectionStateRecovery: {
      maxDisconnectionDuration: Number(process.env.SOCKET_RECOVERY_MS || 120000),
      skipMiddlewares: false,
    },
  });

  io.use(authenticateSocket);
  io.on('connection', (socket) => {
    realtimeDiagnostics.counters.connectionsAccepted += 1;
    trackConnectionEvent('connected', socket);
    registerSocketHandlers(socket);
  });
  configureRedisAdapter(io);

  operationalLogger.info('realtime', 'socket_service_initialized', {
    recoveryMs: Number(process.env.SOCKET_RECOVERY_MS || 120000),
    nodeId: SERVER_NODE_ID,
  });
  return io;
}

function emitToRooms(eventName, payload, rooms) {
  if (!io) return false;
  const startedAt = Date.now();
  if (!rememberEvent(payload?.eventId)) {
    realtimeDiagnostics.counters.duplicateEmitsSuppressed += 1;
    recordCounter('socket.emit.duplicate_suppressed', 1, { eventName });
    operationalLogger.info('realtime', 'duplicate_event_emit_suppressed', {
      eventName,
      eventIdHash: payload?.eventId ? String(payload.eventId).length : 0,
    });
    return false;
  }

  const uniqueRooms = Array.from(new Set(rooms.filter(Boolean)));
  for (const targetRoom of uniqueRooms) {
    io.to(targetRoom).emit(eventName, payload);
  }
  realtimeDiagnostics.counters.eventsEmitted += uniqueRooms.length;
  recordCounter('socket.emit.rooms', uniqueRooms.length, { eventName });
  recordLatency('socket.emit.latency_ms', Date.now() - startedAt, { eventName });

  operationalLogger.info('realtime', 'socket_event_emitted', {
    eventName,
    rooms: uniqueRooms.length,
  });

  return uniqueRooms.length > 0;
}

function getRealtimeDiagnostics() {
  const now = Date.now();
  const recentConnectionCount = realtimeDiagnostics.recentConnections.filter(
    (event) => now - event.at <= RECENT_CONNECTION_WINDOW_MS,
  ).length;
  const rooms = io?.sockets?.adapter?.rooms;
  const roomOccupancy = rooms
    ? Array.from(rooms.entries())
      .filter(([roomName]) => !io?.sockets?.sockets?.has(roomName))
      .map(([roomName, members]) => ({ room: roomName, sockets: members.size }))
      .sort((a, b) => b.sockets - a.sockets)
      .slice(0, 25)
    : [];

  return {
    nodeId: SERVER_NODE_ID,
    initializedAt: realtimeDiagnostics.initializedAt?.toISOString?.() || null,
    adapter: realtimeDiagnostics.adapter,
    connectedSockets: socketPresence.size,
    knownRooms: rooms?.size || 0,
    counters: realtimeDiagnostics.counters,
    roomOccupancy,
    reconnectStorm: {
      windowMs: RECENT_CONNECTION_WINDOW_MS,
      recentConnectionCount,
      threshold: RECONNECT_STORM_THRESHOLD,
      state: recentConnectionCount >= RECONNECT_STORM_THRESHOLD ? 'degraded' : 'normal',
    },
    roomStrategy: {
      routeRooms: `${ROOM_PREFIX.ROUTE}:<routeId>`,
      tripRooms: `${ROOM_PREFIX.TRIP}:<tripId>`,
      contractorRooms: `${ROOM_PREFIX.CONTRACTOR}:<contractorId>`,
      clientRooms: `${ROOM_PREFIX.CLIENT}:<clientId>`,
      camioneroRooms: `${ROOM_PREFIX.CAMIONERO}:<camioneroId>`,
      chatRooms: `${ROOM_PREFIX.CHAT}:<tripId>`,
    },
    scaling: {
      stickySessionsRequired: realtimeDiagnostics.adapter.configured,
      multiNodeCompatible: realtimeDiagnostics.adapter.status === 'ready',
      adapterReady: realtimeDiagnostics.adapter.status === 'ready' || realtimeDiagnostics.adapter.status === 'local',
      assumptions: [
        'El balanceador debe mantener sticky sessions para HTTP polling.',
        'Los rooms conservan los contratos route/trip/contractor/camionero existentes.',
        'El adapter Redis debe estar listo antes de validar fanout multi-nodo.',
      ],
    },
  };
}

async function shutdownRealtime() {
  if (!io) return;
  const redisClients = io.redisClients;
  await new Promise((resolve) => io.close(resolve));
  if (redisClients?.pubClient || redisClients?.subClient) {
    await Promise.allSettled([
      redisClients.pubClient?.quit?.(),
      redisClients.subClient?.quit?.(),
    ]);
  }
  io = null;
  socketPresence.clear();
  operationalLogger.info('realtime', 'socket_service_shutdown', {
    nodeId: SERVER_NODE_ID,
  });
}

function emitTrackingLocationUpdated(payload, { contratistaId, camioneroId, oportunidadId } = {}) {
  return emitToRooms(EVENTS.TRACKING_LOCATION_UPDATED, payload, [
    camioneroId ? room(ROOM_PREFIX.CAMIONERO, camioneroId) : null,
    contratistaId ? room(ROOM_PREFIX.CONTRACTOR, contratistaId) : null,
    payload?.ownerType === 'CLIENTE' && payload?.ownerId ? room(ROOM_PREFIX.CLIENT, payload.ownerId) : null,
    oportunidadId ? room(ROOM_PREFIX.TRIP, oportunidadId) : null,
  ]);
}

function emitTripStateChanged(payload, { contratistaId, camioneroId, oportunidadId, ownerId, ownerType } = {}) {
  return emitToRooms(EVENTS.TRIP_STATE_CHANGED, payload, [
    contratistaId ? room(ROOM_PREFIX.CONTRACTOR, contratistaId) : null,
    ownerType === 'CLIENTE' && ownerId ? room(ROOM_PREFIX.CLIENT, ownerId) : null,
    camioneroId ? room(ROOM_PREFIX.CAMIONERO, camioneroId) : null,
    oportunidadId ? room(ROOM_PREFIX.TRIP, oportunidadId) : null,
  ]);
}

function emitAlertCreated(payload) {
  return emitToRooms(EVENTS.ALERT_CREATED, payload, [
    room(ROOM_PREFIX.ALERTS, 'contractors'),
  ]);
}

function emitRouteStateChanged(payload, { contratistaId, camioneroId, oportunidadId, routeId } = {}) {
  return emitToRooms(EVENTS.ROUTE_STATE_CHANGED, payload, [
    routeId ? room(ROOM_PREFIX.ROUTE, routeId) : null,
    oportunidadId ? room(ROOM_PREFIX.TRIP, oportunidadId) : null,
    contratistaId ? room(ROOM_PREFIX.CONTRACTOR, contratistaId) : null,
    camioneroId ? room(ROOM_PREFIX.CAMIONERO, camioneroId) : null,
  ]);
}

function emitRouteAuditEvent(payload, { contratistaId, camioneroId, oportunidadId, routeId } = {}) {
  return emitToRooms(EVENTS.ROUTE_AUDIT_EVENT, payload, [
    routeId ? room(ROOM_PREFIX.ROUTE, routeId) : null,
    oportunidadId ? room(ROOM_PREFIX.TRIP, oportunidadId) : null,
    contratistaId ? room(ROOM_PREFIX.CONTRACTOR, contratistaId) : null,
    camioneroId ? room(ROOM_PREFIX.CAMIONERO, camioneroId) : null,
  ]);
}

function emitOfferCreated(payload, { ownerId, camioneroId, oportunidadId } = {}) {
  return emitToRooms(EVENTS.OFFER_CREATED, payload, [
    ownerId ? room(ROOM_PREFIX.CLIENT, ownerId) : null,
    ownerId ? room(ROOM_PREFIX.CONTRACTOR, ownerId) : null,
    camioneroId ? room(ROOM_PREFIX.CAMIONERO, camioneroId) : null,
    oportunidadId ? room(ROOM_PREFIX.TRIP, oportunidadId) : null,
  ]);
}

function emitOfferAccepted(payload, { ownerId, camioneroId, oportunidadId } = {}) {
  return emitToRooms(EVENTS.OFFER_ACCEPTED, payload, [
    ownerId ? room(ROOM_PREFIX.CLIENT, ownerId) : null,
    ownerId ? room(ROOM_PREFIX.CONTRACTOR, ownerId) : null,
    camioneroId ? room(ROOM_PREFIX.CAMIONERO, camioneroId) : null,
    oportunidadId ? room(ROOM_PREFIX.TRIP, oportunidadId) : null,
  ]);
}

function emitOfferRejected(payload, { ownerId, camioneroId, oportunidadId } = {}) {
  return emitToRooms(EVENTS.OFFER_REJECTED, payload, [
    ownerId ? room(ROOM_PREFIX.CLIENT, ownerId) : null,
    ownerId ? room(ROOM_PREFIX.CONTRACTOR, ownerId) : null,
    camioneroId ? room(ROOM_PREFIX.CAMIONERO, camioneroId) : null,
    oportunidadId ? room(ROOM_PREFIX.TRIP, oportunidadId) : null,
  ]);
}

module.exports = {
  EVENTS,
  ROOM_PREFIX,
  initializeRealtime,
  getRealtimeDiagnostics,
  shutdownRealtime,
  emitTrackingLocationUpdated,
  emitTripStateChanged,
  emitAlertCreated,
  emitRouteStateChanged,
  emitRouteAuditEvent,
  emitOfferCreated,
  emitOfferAccepted,
  emitOfferRejected,
};

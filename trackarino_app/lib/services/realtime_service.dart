import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../config/api_config.dart';
import '../models/alerta_model.dart';
import '../observability/error_reporter.dart';
import '../observability/operational_logger.dart';
import 'auth_service.dart';

enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  fallbackPolling,
}

class RealtimeTrackingUpdate {
  final String eventId;
  final String camioneroId;
  final String? oportunidadId;
  final double lat;
  final double lng;
  final double? heading;
  final String trackingStatus;
  final DateTime timestamp;
  final DateTime serverReceivedAt;
  final int? ageMs;
  final bool isStale;
  final bool isOffline;
  final String? operationalEventType;
  final String? operationalEventReason;

  RealtimeTrackingUpdate({
    required this.eventId,
    required this.camioneroId,
    required this.oportunidadId,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.trackingStatus,
    required this.timestamp,
    required this.serverReceivedAt,
    required this.ageMs,
    required this.isStale,
    required this.isOffline,
    this.operationalEventType,
    this.operationalEventReason,
  });

  static RealtimeTrackingUpdate? fromJson(dynamic payload) {
    if (payload is! Map) return null;

    final camioneroId = payload['camioneroId']?.toString();
    final coords = payload['coords'];
    final coordsMap = coords is Map ? coords : null;
    var lat = (coordsMap?['lat'] as num?)?.toDouble();
    var lng = (coordsMap?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      final coordinates = payload['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        lng = (coordinates[0] as num?)?.toDouble();
        lat = (coordinates[1] as num?)?.toDouble();
      }
    }
    final timestamp = DateTime.tryParse(payload['timestamp']?.toString() ?? '');
    final serverReceivedAt = DateTime.tryParse(
      payload['serverReceivedAt']?.toString() ?? '',
    );

    if (camioneroId == null ||
        camioneroId.isEmpty ||
        lat == null ||
        lng == null ||
        timestamp == null) {
      return null;
    }

    final meta = payload['meta'];
    final metaMap = meta is Map ? meta : null;
    final operationalEvent = payload['operationalEvent'];
    final operationalEventMap =
        operationalEvent is Map ? operationalEvent : null;

    return RealtimeTrackingUpdate(
      eventId: (payload['eventId'] ?? '').toString(),
      camioneroId: camioneroId,
      oportunidadId: payload['oportunidadId']?.toString(),
      lat: lat,
      lng: lng,
      heading: (payload['heading'] as num?)?.toDouble(),
      trackingStatus: (payload['trackingStatus'] ?? 'active').toString(),
      timestamp: timestamp,
      serverReceivedAt: serverReceivedAt ?? timestamp,
      ageMs: (metaMap?['ageMs'] as num?)?.toInt(),
      isStale: metaMap?['isStale'] == true,
      isOffline: metaMap?['isOffline'] == true,
      operationalEventType: operationalEventMap?['type']?.toString(),
      operationalEventReason: operationalEventMap?['reason']?.toString(),
    );
  }
}

class RealtimeAlertUpdate {
  final String eventId;
  final AlertaSeguridad? alert;

  RealtimeAlertUpdate({required this.eventId, required this.alert});

  static RealtimeAlertUpdate? fromJson(dynamic payload) {
    if (payload is! Map) return null;
    final eventId = (payload['eventId'] ?? payload['_id'] ?? '').toString();

    try {
      final alert = AlertaSeguridad.fromJson(
        Map<String, dynamic>.from(payload),
      );
      return RealtimeAlertUpdate(eventId: eventId, alert: alert);
    } catch (_) {
      final tipo = payload['tipo']?.toString();
      final coords = payload['coords'];
      if (tipo == null || coords is! Map) return null;
      final lat = (coords['lat'] as num?)?.toDouble();
      final lng = (coords['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      return RealtimeAlertUpdate(
        eventId: eventId,
        alert: AlertaSeguridad(
          id: payload['alertaId']?.toString() ?? eventId,
          tipo: tipo,
          descripcion: payload['descripcion']?.toString(),
          usuario: payload['usuario']?.toString() ?? 'desconocido',
          coords: {'lat': lat, 'lng': lng},
          timestamp:
              DateTime.tryParse(payload['timestamp']?.toString() ?? '') ??
              DateTime.now(),
        ),
      );
    }
  }
}

class RealtimeTripUpdate {
  final String eventId;
  final String oportunidadId;
  final String estado;
  final String? previousState;
  final String? camioneroId;

  RealtimeTripUpdate({
    required this.eventId,
    required this.oportunidadId,
    required this.estado,
    required this.previousState,
    required this.camioneroId,
  });

  static RealtimeTripUpdate? fromJson(dynamic payload) {
    if (payload is! Map) return null;
    final oportunidadId = payload['oportunidadId']?.toString();
    final estado = payload['estado']?.toString();
    if (oportunidadId == null ||
        oportunidadId.isEmpty ||
        estado == null ||
        estado.isEmpty) {
      return null;
    }

    return RealtimeTripUpdate(
      eventId: (payload['eventId'] ?? '').toString(),
      oportunidadId: oportunidadId,
      estado: estado,
      previousState: payload['previousState']?.toString(),
      camioneroId: payload['camioneroId']?.toString(),
    );
  }
}

class RealtimeService with WidgetsBindingObserver {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  static const String trackingLocationUpdated = 'tracking:location_updated';
  static const String tripStateChanged = 'trip:state_changed';
  static const String alertCreated = 'alert:created';
  static const String connectionState = 'connection:state';
  static const String fleetSubscribe = 'fleet:subscribe';

  final StreamController<RealtimeConnectionStatus> _connectionController =
      StreamController<RealtimeConnectionStatus>.broadcast();
  final StreamController<RealtimeTrackingUpdate> _trackingController =
      StreamController<RealtimeTrackingUpdate>.broadcast();
  final StreamController<RealtimeTripUpdate> _tripController =
      StreamController<RealtimeTripUpdate>.broadcast();
  final StreamController<RealtimeAlertUpdate> _alertController =
      StreamController<RealtimeAlertUpdate>.broadcast();

  socket_io.Socket? _socket;
  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;
  bool _initializedLifecycle = false;
  String? _lastTrackingEventId;
  String? _lastTripEventId;
  String? _lastAlertEventId;
  DateTime? _lastConnectAttemptAt;
  bool _disposed = false;

  static const Duration _minimumConnectSpacing = Duration(seconds: 2);

  Stream<RealtimeConnectionStatus> get connectionStream =>
      _connectionController.stream;
  Stream<RealtimeTrackingUpdate> get trackingUpdates =>
      _trackingController.stream;
  Stream<RealtimeTripUpdate> get tripUpdates => _tripController.stream;
  Stream<RealtimeAlertUpdate> get alertUpdates => _alertController.stream;
  RealtimeConnectionStatus get status => _status;
  bool get isConnected => _status == RealtimeConnectionStatus.connected;

  Future<void> connect() async {
    if (_disposed) return;
    if (_status == RealtimeConnectionStatus.connected ||
        _status == RealtimeConnectionStatus.connecting) {
      return;
    }

    final now = DateTime.now();
    if (_lastConnectAttemptAt != null &&
        now.difference(_lastConnectAttemptAt!) < _minimumConnectSpacing) {
      OperationalLogger.info(
        OperationalLogCategory.realtime,
        'socket_connect_skipped_spacing',
        fields: {'status': _status.name},
      );
      return;
    }
    _lastConnectAttemptAt = now;

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      _setStatus(RealtimeConnectionStatus.fallbackPolling);
      OperationalLogger.warning(
        OperationalLogCategory.realtime,
        'socket_connect_skipped_missing_token',
      );
      return;
    }

    if (!_initializedLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _initializedLifecycle = true;
    }

    _setStatus(RealtimeConnectionStatus.connecting);
    _socket?.dispose();

    final socket = socket_io.io(
      ApiConfig.realtimeUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(8)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .setTimeout(10000)
          .setAuth({'token': token})
          .build(),
    );

    _socket = socket;
    _attachCoreListeners(socket);
    OperationalLogger.info(
      OperationalLogCategory.realtime,
      'socket_connect_started',
      fields: {'url': ApiConfig.realtimeUrl},
    );
    socket.connect();
  }

  void subscribeFleet() {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit(fleetSubscribe);
    OperationalLogger.info(
      OperationalLogCategory.realtime,
      'socket_fleet_subscribe_sent',
    );
  }

  void disconnect() {
    _socket?.off(trackingLocationUpdated);
    _socket?.off(tripStateChanged);
    _socket?.off(alertCreated);
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setStatus(RealtimeConnectionStatus.disconnected);
    OperationalLogger.info(
      OperationalLogCategory.realtime,
      'socket_disconnected_by_client',
    );
  }

  void _attachCoreListeners(socket_io.Socket socket) {
    socket
      ..off('connect')
      ..off('disconnect')
      ..off('connect_error')
      ..off('reconnect_attempt')
      ..off('reconnect_failed')
      ..off(connectionState)
      ..off(trackingLocationUpdated)
      ..off(tripStateChanged)
      ..off(alertCreated);

    socket.on('connect', (_) {
      _lastTrackingEventId = null;
      _lastTripEventId = null;
      _lastAlertEventId = null;
      _setStatus(RealtimeConnectionStatus.connected);
      subscribeFleet();
      OperationalLogger.info(
        OperationalLogCategory.realtime,
        'socket_connected',
      );
    });

    socket.on('disconnect', (_) {
      _setStatus(RealtimeConnectionStatus.fallbackPolling);
      OperationalLogger.warning(
        OperationalLogCategory.realtime,
        'socket_disconnected_fallback_enabled',
      );
    });

    socket.on('connect_error', (error) {
      OperationalLogger.warning(
        OperationalLogCategory.realtime,
        'socket_connect_error',
        fields: {'errorType': error.runtimeType.toString()},
      );
      _setStatus(RealtimeConnectionStatus.fallbackPolling);
    });

    socket.on('reconnect_attempt', (_) {
      _setStatus(RealtimeConnectionStatus.reconnecting);
      OperationalLogger.info(
        OperationalLogCategory.realtime,
        'socket_reconnect_attempt',
      );
    });

    socket.on('reconnect_failed', (_) {
      _setStatus(RealtimeConnectionStatus.fallbackPolling);
      OperationalLogger.warning(
        OperationalLogCategory.realtime,
        'socket_reconnect_failed_fallback_enabled',
      );
    });

    socket.on(trackingLocationUpdated, (payload) {
      try {
        final update = RealtimeTrackingUpdate.fromJson(payload);
        if (update == null) return;
        if (update.eventId.isNotEmpty &&
            update.eventId == _lastTrackingEventId) {
          return;
        }
        _lastTrackingEventId = update.eventId;
        _trackingController.add(update);
      } catch (error, stackTrace) {
        ErrorReporter.capture(
          error,
          stackTrace,
          type: OperationalErrorType.realtime,
          tags: {'event': trackingLocationUpdated},
        );
      }
    });

    socket.on(tripStateChanged, (payload) {
      try {
        final update = RealtimeTripUpdate.fromJson(payload);
        if (update == null) return;
        if (update.eventId.isNotEmpty && update.eventId == _lastTripEventId) {
          return;
        }
        _lastTripEventId = update.eventId;
        _tripController.add(update);
      } catch (error, stackTrace) {
        ErrorReporter.capture(
          error,
          stackTrace,
          type: OperationalErrorType.realtime,
          tags: {'event': tripStateChanged},
        );
      }
    });

    socket.on(alertCreated, (payload) {
      try {
        final update = RealtimeAlertUpdate.fromJson(payload);
        if (update == null || update.alert == null) return;
        if (update.eventId.isNotEmpty && update.eventId == _lastAlertEventId) {
          return;
        }
        _lastAlertEventId = update.eventId;
        _alertController.add(update);
      } catch (error, stackTrace) {
        ErrorReporter.capture(
          error,
          stackTrace,
          type: OperationalErrorType.realtime,
          tags: {'event': alertCreated},
        );
      }
    });
  }

  void _setStatus(RealtimeConnectionStatus nextStatus) {
    if (_status == nextStatus) return;
    _status = nextStatus;
    if (!_connectionController.isClosed) {
      _connectionController.add(nextStatus);
    }
    OperationalLogger.info(
      OperationalLogCategory.realtime,
      'socket_status_changed',
      fields: {'status': nextStatus.name},
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      OperationalLogger.info(
        OperationalLogCategory.lifecycle,
        'realtime_lifecycle_resumed',
      );
      connect();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _socket?.disconnect();
      _setStatus(RealtimeConnectionStatus.fallbackPolling);
      OperationalLogger.info(
        OperationalLogCategory.lifecycle,
        'realtime_lifecycle_suspended',
        fields: {'state': state.name},
      );
    }
  }

  void dispose() {
    _disposed = true;
    if (_initializedLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _initializedLifecycle = false;
    }
    disconnect();
    _connectionController.close();
    _trackingController.close();
    _tripController.close();
    _alertController.close();
  }
}

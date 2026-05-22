import 'package:flutter/material.dart';

import '../offline/connectivity_service.dart';
import '../offline/sync_types.dart';
import '../services/realtime_service.dart';
import '../theme/app_colors.dart';
import '../widgets/operational/operational_svg_icon.dart';

enum OperationalHealthLevel { healthy, degraded, offline, recovering, critical }

class OperationalHealthSnapshot {
  final OperationalHealthLevel level;
  final String title;
  final String message;
  final String dataSafetyMessage;
  final String backlogLabel;
  final String icon;

  const OperationalHealthSnapshot({
    required this.level,
    required this.title,
    required this.message,
    required this.dataSafetyMessage,
    required this.backlogLabel,
    required this.icon,
  });

  factory OperationalHealthSnapshot.resolve({
    required SyncQueueSummary summary,
    required ConnectivityHealth connectivity,
    required RealtimeConnectionStatus realtime,
  }) {
    if (summary.failed > 0) {
      return OperationalHealthSnapshot(
        level: OperationalHealthLevel.critical,
        title: 'Atención requerida',
        message: '${summary.failed} acción(es) necesitan reintento operativo.',
        dataSafetyMessage: 'Los datos permanecen protegidos localmente.',
        backlogLabel: _backlogLabel(summary),
        icon: OperationalSvgIcons.alertTriangle,
      );
    }

    if (connectivity == ConnectivityHealth.offline) {
      return OperationalHealthSnapshot(
        level: OperationalHealthLevel.offline,
        title: 'Operando sin conexión',
        message:
            'La app seguirá guardando acciones críticas en el dispositivo.',
        dataSafetyMessage: 'Datos protegidos localmente hasta reconectar.',
        backlogLabel: _backlogLabel(summary),
        icon: OperationalSvgIcons.cloudOff,
      );
    }

    if (summary.syncing > 0 ||
        realtime == RealtimeConnectionStatus.connecting ||
        realtime == RealtimeConnectionStatus.reconnecting) {
      return OperationalHealthSnapshot(
        level: OperationalHealthLevel.recovering,
        title: 'Recuperando sincronización',
        message: 'El sistema está confirmando acciones con el servidor.',
        dataSafetyMessage: 'La cola local conserva el orden de replay.',
        backlogLabel: _backlogLabel(summary),
        icon: OperationalSvgIcons.refreshCw,
      );
    }

    if (connectivity == ConnectivityHealth.networkOnly ||
        summary.pending > 0 ||
        realtime == RealtimeConnectionStatus.fallbackPolling ||
        realtime == RealtimeConnectionStatus.disconnected) {
      return OperationalHealthSnapshot(
        level: OperationalHealthLevel.degraded,
        title: 'Servicio degradado',
        message: _degradedMessage(summary, connectivity, realtime),
        dataSafetyMessage: 'Las acciones pendientes siguen persistidas.',
        backlogLabel: _backlogLabel(summary),
        icon: OperationalSvgIcons.activity,
      );
    }

    return OperationalHealthSnapshot(
      level: OperationalHealthLevel.healthy,
      title: 'Sistema sincronizado',
      message: 'Tiempo real y sincronización operan con normalidad.',
      dataSafetyMessage: 'Todos los datos están confirmados o protegidos.',
      backlogLabel: 'Sin backlog operativo',
      icon: OperationalSvgIcons.checkCircle,
    );
  }

  String get label {
    switch (level) {
      case OperationalHealthLevel.healthy:
        return 'Saludable';
      case OperationalHealthLevel.degraded:
        return 'Degradado';
      case OperationalHealthLevel.offline:
        return 'Sin conexión';
      case OperationalHealthLevel.recovering:
        return 'Recuperando';
      case OperationalHealthLevel.critical:
        return 'Crítico';
    }
  }

  Color get color {
    switch (level) {
      case OperationalHealthLevel.healthy:
        return AppColors.statusActive;
      case OperationalHealthLevel.degraded:
        return AppColors.statusStale;
      case OperationalHealthLevel.offline:
        return AppColors.graphite700;
      case OperationalHealthLevel.recovering:
        return AppColors.statusSyncing;
      case OperationalHealthLevel.critical:
        return AppColors.alertCritical;
    }
  }

  static String _degradedMessage(
    SyncQueueSummary summary,
    ConnectivityHealth connectivity,
    RealtimeConnectionStatus realtime,
  ) {
    if (connectivity == ConnectivityHealth.networkOnly) {
      return 'Hay red, pero el servidor no responde todavía.';
    }
    if (summary.pending > 0) {
      return '${summary.pending} acción(es) esperan confirmación del servidor.';
    }
    if (realtime == RealtimeConnectionStatus.fallbackPolling) {
      return 'Socket no disponible; la operación continúa por polling.';
    }
    return 'Tiempo real no está conectado en este momento.';
  }

  static String _backlogLabel(SyncQueueSummary summary) {
    final total = summary.visibleCount;
    if (total == 0) return 'Sin acciones pendientes';
    if (summary.failed > 0) {
      return '$total en cola, ${summary.failed} con error';
    }
    if (summary.syncing > 0) {
      return '$total en cola, ${summary.syncing} sincronizando';
    }
    return '$total acción(es) esperando conexión';
  }
}

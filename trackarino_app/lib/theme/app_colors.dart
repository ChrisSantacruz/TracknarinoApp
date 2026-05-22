import 'package:flutter/material.dart';

/// Logistics platform palette — graphite surfaces, deep green primary.
abstract final class AppColors {
  // Brand
  static const Color deepGreen = Color(0xFF1B5E3B);
  static const Color deepGreenLight = Color(0xFF2D7A52);
  static const Color deepGreenDark = Color(0xFF0F3D26);

  // Surfaces (light)
  static const Color graphite50 = Color(0xFFF4F5F6);
  static const Color graphite100 = Color(0xFFE8EAED);
  static const Color graphite200 = Color(0xFFD1D5DB);
  static const Color graphite700 = Color(0xFF374151);
  static const Color graphite800 = Color(0xFF1F2937);
  static const Color graphite900 = Color(0xFF111827);

  // Surfaces (dark)
  static const Color darkSurface = Color(0xFF1A1D21);
  static const Color darkSurfaceElevated = Color(0xFF252A30);
  static const Color darkSurfaceHigh = Color(0xFF2E343C);

  // Operational status
  static const Color statusActive = Color(0xFF22A06B);
  static const Color statusStale = Color(0xFFE07B00);
  static const Color statusOffline = Color(0xFFDC3545);
  static const Color statusPending = Color(0xFF5B7C99);
  static const Color statusSyncing = Color(0xFF3B82F6);

  // Alerts
  static const Color alertCritical = Color(0xFFC62828);
  static const Color alertWarning = Color(0xFFE65100);
  static const Color alertInfo = Color(0xFF1565C0);

  // Map / route
  static const Color routeLine = Color(0xFF1B5E3B);
  static const Color mapMarkerCurrent = Color(0xFF2563EB);
  static const Color mapMarkerDestination = Color(0xFFDC3545);

  static Color trackingStatusColor(String status) {
    switch (status) {
      case 'active':
      case 'en_ruta':
        return statusActive;
      case 'stale':
      case 'asignada':
      case 'aceptada':
        return statusStale;
      case 'offline':
        return statusOffline;
      default:
        return graphite700;
    }
  }

  static String trackingStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Activo';
      case 'stale':
        return 'Señal antigua';
      case 'offline':
        return 'Sin señal';
      case 'en_ruta':
        return 'En ruta';
      case 'asignada':
        return 'Asignado';
      case 'aceptada':
        return 'Aceptado';
      case 'no_location':
        return 'Sin ubicación';
      default:
        return 'Desconocido';
    }
  }
}

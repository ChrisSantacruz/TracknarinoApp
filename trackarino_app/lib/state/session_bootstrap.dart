import 'package:flutter/foundation.dart';

import '../offline/sync_engine.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';

/// Post-auth side effects (notifications, GPS, realtime, sync).
abstract final class SessionBootstrap {
  static Future<void> applyAuthenticatedSession({
    required AuthService auth,
    required NotificationService notification,
    required LocationService location,
  }) async {
    SyncEngine.instance.triggerSyncSoon(reason: 'authenticated_session');

    try {
      await notification.initialize().timeout(const Duration(seconds: 8));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Notification init failed: $e');
      }
    }

    final user = auth.currentUser;
    if (user?.tipoUsuario == 'camionero' && user?.id != null) {
      await location.init(user!.id!);
    }

    if (user?.tipoUsuario == 'contratista' || user?.tipoUsuario == 'camionero') {
      await RealtimeService.instance.connect();
      if (user?.tipoUsuario == 'contratista') {
        RealtimeService.instance.subscribeFleet();
      }
    }
  }

  static Future<void> teardownSession({required LocationService location}) async {
    location.stopTracking();
    RealtimeService.instance.disconnect();
  }
}

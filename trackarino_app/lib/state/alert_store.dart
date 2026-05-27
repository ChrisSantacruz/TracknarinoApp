import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/alerta_model.dart';
import '../services/alerta_service.dart';
import '../services/realtime_service.dart';

enum AlertLoadStatus { idle, loading, ready, error }

/// Single source of truth for operational alerts shown on map/list screens.
class AlertStore extends ChangeNotifier {
  List<AlertaSeguridad> _alerts = [];
  AlertLoadStatus _status = AlertLoadStatus.idle;
  String? _errorMessage;
  int _unreadBump = 0;

  List<AlertaSeguridad> get alerts => List.unmodifiable(_alerts);
  AlertLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  int get alertCount => _alerts.length;
  int get unreadBump => _unreadBump;

  void mergeFromRealtime(RealtimeAlertUpdate update) {
    final alert = update.alert;
    if (alert == null) return;

    final existingIndex = _alerts.indexWhere(
      (a) => a.id != null && a.id == alert.id,
    );
    if (existingIndex >= 0) {
      _alerts[existingIndex] = alert;
    } else {
      _alerts = [alert, ..._alerts];
      _unreadBump += 1;
    }
    _status = AlertLoadStatus.ready;
    _errorMessage = null;
    notifyListeners();
  }

  void upsertLocal(AlertaSeguridad alert) {
    final index = _alerts.indexWhere(
      (a) => a.id != null && alert.id != null && a.id == alert.id,
    );
    if (index >= 0) {
      _alerts[index] = alert;
    } else {
      _alerts = [alert, ..._alerts];
    }
    _status = AlertLoadStatus.ready;
    notifyListeners();
  }

  Future<void> refreshNearby(Position position) async {
    _status = AlertLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await AlertaService.obtenerAlertasCercanas(position);
      _alerts = list;
      _status = AlertLoadStatus.ready;
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las alertas. Revisa tu conexión.';
      _status = AlertLoadStatus.error;
    }
    notifyListeners();
  }

  void clearUnreadBump() => _unreadBump = 0;
}

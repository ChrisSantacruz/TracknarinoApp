import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../observability/operational_logger.dart';

enum ConnectivityHealth { offline, networkOnly, internetReachable }

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityHealth> _healthController =
      StreamController<ConnectivityHealth>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectivityHealth _current = ConnectivityHealth.offline;
  Timer? _debounce;

  Stream<ConnectivityHealth> get healthStream => _healthController.stream;
  ConnectivityHealth get current => _current;
  bool get canAttemptNetwork => _current != ConnectivityHealth.offline;
  bool get hasInternetReachability =>
      _current == ConnectivityHealth.internetReachable;

  Future<void> initialize() async {
    _subscription ??= _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
    await refresh();
  }

  Future<ConnectivityHealth> refresh() async {
    final result = await _connectivity.checkConnectivity();
    final health = await _evaluate(result);
    _setHealth(health);
    return health;
  }

  void _handleConnectivityChanged(List<ConnectivityResult> result) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () async {
      final health = await _evaluate(result);
      _setHealth(health);
    });
  }

  Future<ConnectivityHealth> _evaluate(List<ConnectivityResult> result) async {
    if (result.isEmpty || result.contains(ConnectivityResult.none)) {
      return ConnectivityHealth.offline;
    }

    try {
      final probeUri = Uri.parse(ApiConfig.baseUrl);
      await http.get(probeUri).timeout(const Duration(seconds: 5));
      return ConnectivityHealth.internetReachable;
    } catch (error) {
      OperationalLogger.info(
        OperationalLogCategory.connectivity,
        'connectivity_probe_failed',
        fields: {'errorType': error.runtimeType.toString()},
      );
      return ConnectivityHealth.networkOnly;
    }
  }

  void _setHealth(ConnectivityHealth next) {
    if (_current == next) return;
    _current = next;
    OperationalLogger.info(
      OperationalLogCategory.connectivity,
      'connectivity_health_changed',
      fields: {'health': next.name},
    );
    if (!_healthController.isClosed) {
      _healthController.add(next);
    }
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _subscription?.cancel();
    await _healthController.close();
  }
}

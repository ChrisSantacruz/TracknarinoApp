import 'dart:async';

/// Reusable polling lifecycle for future WebSocket fallback.
class PollingController {
  Timer? _timer;
  bool _inFlight = false;

  bool get isInFlight => _inFlight;

  void start({
    required Duration interval,
    required Future<void> Function() onTick,
    bool immediate = true,
  }) {
    stop();
    if (immediate) {
      _runTick(onTick);
    }
    _timer = Timer.periodic(interval, (_) => _runTick(onTick));
  }

  Future<void> _runTick(Future<void> Function() onTick) async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      await onTick();
    } finally {
      _inFlight = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _inFlight = false;
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/realtime_service.dart';
import '../state/alert_store.dart';
import '../state/trip_store.dart';

/// Keeps alert/trip stores in sync with socket events for the authenticated session.
class RealtimeBindings extends StatefulWidget {
  final Widget child;

  const RealtimeBindings({super.key, required this.child});

  @override
  State<RealtimeBindings> createState() => _RealtimeBindingsState();
}

class _RealtimeBindingsState extends State<RealtimeBindings> {
  StreamSubscription<RealtimeAlertUpdate>? _alertSub;
  StreamSubscription<RealtimeTripUpdate>? _tripSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _alertSub ??= RealtimeService.instance.alertUpdates.listen((update) {
      if (!mounted) return;
      context.read<AlertStore>().mergeFromRealtime(update);
    });
    _tripSub ??= RealtimeService.instance.tripUpdates.listen((_) {
      if (!mounted) return;
      context.read<TripStore>().refreshActiveTrip();
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _tripSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

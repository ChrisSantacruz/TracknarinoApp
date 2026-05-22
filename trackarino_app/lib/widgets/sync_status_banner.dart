import 'dart:async';

import 'package:flutter/material.dart';

import '../offline/connectivity_service.dart';
import '../offline/sync_engine.dart';
import '../offline/sync_types.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'operational/operational_svg_icon.dart';

class SyncStatusBanner extends StatefulWidget {
  final Widget child;

  const SyncStatusBanner({super.key, required this.child});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  SyncQueueSummary _summary = const SyncQueueSummary(
    pending: 0,
    syncing: 0,
    failed: 0,
    oldestPendingAt: null,
  );
  ConnectivityHealth _health = ConnectivityHealth.offline;

  StreamSubscription<SyncQueueSummary>? _summarySubscription;
  StreamSubscription<ConnectivityHealth>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    final engine = SyncEngine.instance;
    _health = engine.connectivityHealth;
    _summarySubscription = engine.summaryStream.listen((summary) {
      if (mounted) setState(() => _summary = summary);
    });
    _connectivitySubscription = engine.connectivityStream.listen((health) {
      if (mounted) setState(() => _health = health);
    });
  }

  @override
  void dispose() {
    _summarySubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _buildBanner(context);
    if (banner == null) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: banner,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildBanner(BuildContext context) {
    if (_summary.hasFailures) {
      return _BannerBody(
        key: const ValueKey('sync_failed'),
        color: AppColors.alertCritical,
        icon: OperationalSvgIcons.alertTriangle,
        text:
            '${_summary.failed} acción(es) necesitan atención. Datos protegidos localmente.',
        onTap: () => SyncEngine.instance.triggerSyncSoon(reason: 'banner_retry'),
      );
    }

    if (_health == ConnectivityHealth.offline) {
      return _BannerBody(
        key: const ValueKey('offline'),
        color: AppColors.graphite800,
        icon: OperationalSvgIcons.cloudOff,
        text:
            'Sin conexión. Las acciones críticas quedan protegidas localmente.',
      );
    }

    if (_health == ConnectivityHealth.networkOnly) {
      return _BannerBody(
        key: const ValueKey('network_only'),
        color: AppColors.statusStale,
        icon: OperationalSvgIcons.wifiOff,
        text:
            'Red disponible, servidor no alcanzable. Reintentando con cuidado.',
      );
    }

    if (_summary.syncing > 0) {
      return _BannerBody(
        key: const ValueKey('syncing'),
        color: AppColors.statusSyncing,
        icon: OperationalSvgIcons.refreshCw,
        text: 'Sincronizando ${_summary.syncing} acción(es)...',
      );
    }

    if (_summary.hasPending) {
      return _BannerBody(
        key: const ValueKey('pending'),
        color: AppColors.statusPending,
        icon: OperationalSvgIcons.cloudUpload,
        text: '${_summary.pending} acción(es) en cola de sincronización',
        onTap: () => SyncEngine.instance.triggerSyncSoon(reason: 'banner_pending'),
      );
    }

    return null;
  }
}

class _BannerBody extends StatelessWidget {
  final Color color;
  final String icon;
  final String text;
  final VoidCallback? onTap;

  const _BannerBody({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              OperationalSvgIcon(icon, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              if (onTap != null)
                const OperationalSvgIcon(
                  OperationalSvgIcons.chevronRight,
                  color: Colors.white70,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

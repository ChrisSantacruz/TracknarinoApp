import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/operational_health_model.dart';
import '../../offline/app_database.dart';
import '../../offline/connectivity_service.dart';
import '../../offline/outbound_sync_repository.dart';
import '../../offline/sync_engine.dart';
import '../../offline/sync_types.dart';
import '../../services/realtime_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/operational_card.dart';
import '../../widgets/operational/operational_svg_icon.dart';
import '../../widgets/operational/premium_operational_widgets.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  SyncQueueSummary _summary = const SyncQueueSummary(
    pending: 0,
    syncing: 0,
    failed: 0,
    oldestPendingAt: null,
  );
  ConnectivityHealth _connectivity = SyncEngine.instance.connectivityHealth;
  RealtimeConnectionStatus _realtime = RealtimeService.instance.status;
  List<OutboundQueueItem> _items = const [];
  final List<_TimelineEvent> _sessionEvents = [];
  bool _retrying = false;

  StreamSubscription<SyncQueueSummary>? _summarySubscription;
  StreamSubscription<ConnectivityHealth>? _connectivitySubscription;
  StreamSubscription<RealtimeConnectionStatus>? _realtimeSubscription;
  StreamSubscription<List<OutboundQueueItem>>? _itemsSubscription;

  @override
  void initState() {
    super.initState();
    final engine = SyncEngine.instance;
    _summarySubscription = engine.summaryStream.listen((summary) {
      if (mounted) setState(() => _summary = summary);
    });
    _connectivitySubscription = engine.connectivityStream.listen((health) {
      if (!mounted) return;
      setState(() {
        _connectivity = health;
        _sessionEvents.insert(0, _TimelineEvent.connectivity(health));
      });
    });
    _realtimeSubscription = RealtimeService.instance.connectionStream.listen((
      status,
    ) {
      if (!mounted) return;
      setState(() {
        _realtime = status;
        _sessionEvents.insert(0, _TimelineEvent.realtime(status));
      });
    });
    _itemsSubscription = OutboundSyncRepository.instance
        .watchRecentItems()
        .listen((items) {
          if (mounted) setState(() => _items = items);
        });
  }

  @override
  void dispose() {
    _summarySubscription?.cancel();
    _connectivitySubscription?.cancel();
    _realtimeSubscription?.cancel();
    _itemsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final health = OperationalHealthSnapshot.resolve(
      summary: _summary,
      connectivity: _connectivity,
      realtime: _realtime,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de sincronización'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar ahora',
            onPressed: _summary.visibleCount == 0 ? null : _retryAllDue,
            icon: OperationalSvgIcon(
              OperationalSvgIcons.refreshCw,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.inkBlack,
      body: PremiumGradientScaffold(
        safeArea: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              const PremiumScreenHeader(
                eyebrow: 'SyncEngine',
                title: 'Centro de sincronización',
                subtitle:
                    'Cola offline, conectividad y estado realtime sin pérdida de eventos.',
              ),
              const SizedBox(height: AppSpacing.md),
              _HealthHero(snapshot: health),
              const SizedBox(height: AppSpacing.md),
              _buildHealthGrid(),
              const SizedBox(height: AppSpacing.md),
              _buildPendingSection(),
              const SizedBox(height: AppSpacing.md),
              _buildFailureSection(),
              const SizedBox(height: AppSpacing.md),
              _buildRealtimeSection(),
              const SizedBox(height: AppSpacing.md),
              _buildTimelineSection(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await SyncEngine.instance.syncNow(reason: 'sync_center_refresh');
  }

  Future<void> _retryAllDue() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await OutboundSyncRepository.instance.resetFailedForRetry();
      SyncEngine.instance.triggerSyncSoon(reason: 'sync_center_retry_all');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _retryItem(OutboundQueueItem item) async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await OutboundSyncRepository.instance.resetFailedForRetry(ids: [item.id]);
      SyncEngine.instance.triggerSyncSoon(reason: 'sync_center_retry_item');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Widget _buildHealthGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      children: [
        _MetricTile(
          icon: OperationalSvgIcons.cloudUpload,
          label: 'Pendientes',
          value: _summary.pending.toString(),
          detail:
              _summary.pending == 0 ? 'Cola despejada' : 'Esperando servidor',
          color: AppColors.statusPending,
        ),
        _MetricTile(
          icon: OperationalSvgIcons.refreshCw,
          label: 'Sincronizando',
          value: _summary.syncing.toString(),
          detail: _summary.syncing == 0 ? 'Sin envío activo' : 'Confirmando',
          color: AppColors.statusSyncing,
          pulsing: _summary.syncing > 0,
        ),
        _MetricTile(
          icon: OperationalSvgIcons.alertTriangle,
          label: 'Con error',
          value: _summary.failed.toString(),
          detail: _summary.failed == 0 ? 'Sin atención' : 'Requiere reintento',
          color:
              _summary.failed == 0
                  ? AppColors.statusActive
                  : AppColors.alertCritical,
        ),
        _MetricTile(
          icon: OperationalSvgIcons.shieldCheck,
          label: 'Persistencia',
          value: _summary.visibleCount == 0 ? 'OK' : 'Local',
          detail:
              _summary.visibleCount == 0 ? 'Sin backlog' : 'Datos protegidos',
          color: AppColors.statusActive,
        ),
      ],
    );
  }

  Widget _buildPendingSection() {
    final pending =
        _items
            .where(
              (item) =>
                  item.status == SyncStatus.pending ||
                  item.status == SyncStatus.syncing,
            )
            .take(8)
            .toList();

    return _SectionCard(
      title: 'Acciones pendientes',
      subtitle:
          pending.isEmpty
              ? 'Todos los datos están sincronizados.'
              : '${pending.length} acción(es) visibles en la cola local.',
      icon: OperationalSvgIcons.cloudUpload,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child:
            pending.isEmpty
                ? const _EmptyOperationalState(
                  icon: OperationalSvgIcons.checkCircle,
                  title: 'Todos los datos están sincronizados',
                  message: 'No hay acciones esperando conexión.',
                )
                : Column(
                  key: ValueKey(pending.length),
                  children:
                      pending
                          .map((item) => _QueueActionCard(item: item))
                          .toList(),
                ),
      ),
    );
  }

  Widget _buildFailureSection() {
    final failed =
        _items
            .where((item) => item.status == SyncStatus.failed)
            .take(8)
            .toList();

    return _SectionCard(
      title: 'Recuperación',
      subtitle:
          failed.isEmpty
              ? 'No hay acciones bloqueadas.'
              : 'Reintentos controlados sin pérdida de datos.',
      icon: OperationalSvgIcons.alertTriangle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child:
            failed.isEmpty
                ? const _EmptyOperationalState(
                  icon: OperationalSvgIcons.shieldCheck,
                  title: 'Sin fallos pendientes',
                  message: 'Tus alertas y eventos permanecen protegidos.',
                )
                : Column(
                  key: ValueKey('failed-${failed.length}-$_retrying'),
                  children: [
                    _RecoveryGuidance(
                      retrying: _retrying,
                      onRetryAll: _retryAllDue,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...failed.map(
                      (item) => _QueueActionCard(
                        item: item,
                        showRetry: true,
                        retrying: _retrying,
                        onRetry: () => _retryItem(item),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildRealtimeSection() {
    final realtimeColor = _realtimeColor(_realtime);

    return _SectionCard(
      title: 'Inteligencia en tiempo real',
      subtitle: _realtimeSubtitle(_realtime),
      icon: OperationalSvgIcons.radio,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConnectionQualityRow(
            label: 'Socket',
            value: _realtimeLabel(_realtime),
            icon: OperationalSvgIcons.radio,
            color: realtimeColor,
            pulsing: _realtime == RealtimeConnectionStatus.connected,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ConnectionQualityRow(
            label: 'Fallback',
            value:
                _realtime == RealtimeConnectionStatus.fallbackPolling
                    ? 'Polling activo'
                    : 'Disponible si el socket cae',
            icon: OperationalSvgIcons.activity,
            color:
                _realtime == RealtimeConnectionStatus.fallbackPolling
                    ? AppColors.statusStale
                    : AppColors.graphite700,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ConnectionQualityRow(
            label: 'Calidad',
            value: _qualityLabel(_realtime, _connectivity),
            icon: OperationalSvgIcons.shieldCheck,
            color: _qualityColor(_realtime, _connectivity),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final events =
        [
          ..._sessionEvents.take(6),
          ..._items.take(10).map(_TimelineEvent.fromQueueItem),
        ].take(12).toList();

    return _SectionCard(
      title: 'Línea operativa',
      subtitle: 'Registro compacto de sincronización y recuperación.',
      icon: OperationalSvgIcons.clock,
      child:
          events.isEmpty
              ? const _EmptyOperationalState(
                icon: OperationalSvgIcons.database,
                title: 'Sin actividad reciente',
                message:
                    'La cola local aparecerá aquí cuando haya eventos reales.',
              )
              : Column(
                children:
                    events.map((event) => _TimelineRow(event: event)).toList(),
              ),
    );
  }
}

class _HealthHero extends StatelessWidget {
  final OperationalHealthSnapshot snapshot;

  const _HealthHero({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final color = snapshot.color;

    return Semantics(
      label: '${snapshot.label}. ${snapshot.message}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.18),
              Theme.of(context).cardColor,
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconOrb(icon: snapshot.icon, color: color, pulsing: true),
                const SizedBox(width: AppSpacing.sm),
                _StatusPill(label: snapshot.label, color: color),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              snapshot.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              snapshot.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _SafetyStrip(
              icon: OperationalSvgIcons.shieldCheck,
              text: snapshot.dataSafetyMessage,
              trailing: snapshot.backlogLabel,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String detail;
  final Color color;
  final bool pulsing;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return OperationalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconOrb(icon: icon, color: color, size: 34, pulsing: pulsing),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconOrb(
                icon: icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _QueueActionCard extends StatelessWidget {
  final OutboundQueueItem item;
  final bool showRetry;
  final bool retrying;
  final VoidCallback? onRetry;

  const _QueueActionCard({
    required this.item,
    this.showRetry = false,
    this.retrying = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconOrb(
                icon: _operationIcon(item.operationType),
                color: color,
                size: 34,
                pulsing: item.status == SyncStatus.syncing,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _operationTitle(item.operationType),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _operationMessage(item),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _StatusPill(label: _statusLabel(item.status), color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaPill(
                icon: OperationalSvgIcons.clock,
                text: _relativeTime(item.createdAt.toLocal()),
              ),
              if (item.attempts > 0)
                _MetaPill(
                  icon: OperationalSvgIcons.refreshCw,
                  text: '${item.attempts} intento(s)',
                ),
              if (item.nextRetryAt != null)
                _MetaPill(
                  icon: OperationalSvgIcons.activity,
                  text:
                      'Reintento ${_relativeTime(item.nextRetryAt!.toLocal())}',
                ),
            ],
          ),
          if (showRetry && onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: retrying ? null : onRetry,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OperationalSvgIcon(
                      OperationalSvgIcons.refreshCw,
                      color:
                          retrying
                              ? AppColors.graphite700
                              : Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Text('Reintentar acción'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecoveryGuidance extends StatelessWidget {
  final bool retrying;
  final VoidCallback onRetryAll;

  const _RecoveryGuidance({required this.retrying, required this.onRetryAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.alertCritical.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.alertCritical.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const OperationalSvgIcon(
                OperationalSvgIcons.shieldCheck,
                color: AppColors.alertCritical,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Los datos no se han perdido',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'La cola local conserva estas acciones y puede reintentarlas cuando el servidor vuelva a aceptar confirmaciones.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: retrying ? null : onRetryAll,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OperationalSvgIcon(
                    OperationalSvgIcons.refreshCw,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    retrying ? 'Preparando reintento' : 'Reintentar fallidas',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionQualityRow extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final Color color;
  final bool pulsing;

  const _ConnectionQualityRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconOrb(icon: icon, color: color, size: 34, pulsing: pulsing),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEvent event;

  const _TimelineRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _IconOrb(icon: event.icon, color: event.color, size: 30),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.only(top: 4),
                color: event.color.withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  event.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeTime(event.timestamp.toLocal()),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOperationalState extends StatelessWidget {
  final String icon;
  final String title;
  final String message;

  const _EmptyOperationalState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          OperationalSvgIcon(icon, color: AppColors.statusActive, size: 42),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SafetyStrip extends StatelessWidget {
  final String icon;
  final String text;
  final String trailing;
  final Color color;

  const _SafetyStrip({
    required this.icon,
    required this.text,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          OperationalSvgIcon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OperationalSvgIcon(icon, color: AppColors.graphite700, size: 12),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _IconOrb extends StatelessWidget {
  final String icon;
  final Color color;
  final double size;
  final bool pulsing;

  const _IconOrb({
    required this.icon,
    required this.color,
    this.size = 40,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 2.8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Center(
        child: OperationalSvgIcon(icon, color: color, size: size * 0.48),
      ),
    );

    if (!pulsing) return orb;
    return _Pulse(color: color, child: orb);
  }
}

class _Pulse extends StatefulWidget {
  final Color color;
  final Widget child;

  const _Pulse({required this.color, required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.18),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _TimelineEvent {
  final String title;
  final String message;
  final String icon;
  final Color color;
  final DateTime timestamp;

  const _TimelineEvent({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.timestamp,
  });

  factory _TimelineEvent.connectivity(ConnectivityHealth health) {
    switch (health) {
      case ConnectivityHealth.internetReachable:
        return _TimelineEvent(
          title: 'Conexión restablecida',
          message: 'El servidor vuelve a estar alcanzable.',
          icon: OperationalSvgIcons.checkCircle,
          color: AppColors.statusActive,
          timestamp: DateTime.now(),
        );
      case ConnectivityHealth.networkOnly:
        return _TimelineEvent(
          title: 'Red degradada',
          message: 'Hay señal, pero el servidor no responde.',
          icon: OperationalSvgIcons.activity,
          color: AppColors.statusStale,
          timestamp: DateTime.now(),
        );
      case ConnectivityHealth.offline:
        return _TimelineEvent(
          title: 'Modo offline protegido',
          message: 'Las nuevas acciones se guardarán localmente.',
          icon: OperationalSvgIcons.cloudOff,
          color: AppColors.graphite700,
          timestamp: DateTime.now(),
        );
    }
  }

  factory _TimelineEvent.realtime(RealtimeConnectionStatus status) {
    return _TimelineEvent(
      title: 'Tiempo real: ${_realtimeLabel(status)}',
      message: _realtimeSubtitle(status),
      icon: OperationalSvgIcons.radio,
      color: _realtimeColor(status),
      timestamp: DateTime.now(),
    );
  }

  factory _TimelineEvent.fromQueueItem(OutboundQueueItem item) {
    return _TimelineEvent(
      title: _operationTitle(item.operationType),
      message: _timelineMessage(item),
      icon: _operationIcon(item.operationType),
      color: _statusColor(item.status),
      timestamp: item.syncedAt ?? item.createdAt,
    );
  }
}

String _operationTitle(String operationType) {
  switch (operationType) {
    case SyncOperationType.gpsLocation:
      return 'Lote GPS';
    case SyncOperationType.alert:
      return 'Alerta operativa';
    case SyncOperationType.tripAction:
      return 'Cambio de viaje';
    default:
      return 'Evento operativo';
  }
}

String _operationIcon(String operationType) {
  switch (operationType) {
    case SyncOperationType.gpsLocation:
      return OperationalSvgIcons.mapPin;
    case SyncOperationType.alert:
      return OperationalSvgIcons.bell;
    case SyncOperationType.tripAction:
      return OperationalSvgIcons.route;
    default:
      return OperationalSvgIcons.database;
  }
}

String _operationMessage(OutboundQueueItem item) {
  switch (item.status) {
    case SyncStatus.pending:
      return 'Esperando conexión estable para confirmar con el servidor.';
    case SyncStatus.syncing:
      return 'Enviando y esperando confirmación segura.';
    case SyncStatus.synced:
      return 'Confirmado por el servidor.';
    case SyncStatus.failed:
      return 'Persistido localmente; listo para reintento controlado.';
    default:
      return 'Estado operativo registrado localmente.';
  }
}

String _timelineMessage(OutboundQueueItem item) {
  switch (item.status) {
    case SyncStatus.synced:
      return 'Sincronización completada.';
    case SyncStatus.syncing:
      return 'Sincronización en progreso.';
    case SyncStatus.failed:
      return 'Requiere recuperación; datos protegidos localmente.';
    default:
      return 'Acción esperando replay seguro.';
  }
}

String _statusLabel(String status) {
  switch (status) {
    case SyncStatus.pending:
      return 'Pendiente';
    case SyncStatus.syncing:
      return 'Sincronizando';
    case SyncStatus.synced:
      return 'Confirmado';
    case SyncStatus.failed:
      return 'Reintento';
    default:
      return 'Local';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case SyncStatus.pending:
      return AppColors.statusPending;
    case SyncStatus.syncing:
      return AppColors.statusSyncing;
    case SyncStatus.synced:
      return AppColors.statusActive;
    case SyncStatus.failed:
      return AppColors.alertCritical;
    default:
      return AppColors.graphite700;
  }
}

String _realtimeLabel(RealtimeConnectionStatus status) {
  switch (status) {
    case RealtimeConnectionStatus.connected:
      return 'Socket conectado';
    case RealtimeConnectionStatus.connecting:
      return 'Conectando';
    case RealtimeConnectionStatus.reconnecting:
      return 'Reconectando';
    case RealtimeConnectionStatus.fallbackPolling:
      return 'Respaldo por polling';
    case RealtimeConnectionStatus.disconnected:
      return 'Desconectado';
  }
}

String _realtimeSubtitle(RealtimeConnectionStatus status) {
  switch (status) {
    case RealtimeConnectionStatus.connected:
      return 'Eventos operativos llegan por socket.';
    case RealtimeConnectionStatus.connecting:
      return 'Preparando canal de tiempo real.';
    case RealtimeConnectionStatus.reconnecting:
      return 'Reconectando sin duplicar listeners.';
    case RealtimeConnectionStatus.fallbackPolling:
      return 'El sistema continúa con respaldo por polling.';
    case RealtimeConnectionStatus.disconnected:
      return 'Sin canal activo en este momento.';
  }
}

Color _realtimeColor(RealtimeConnectionStatus status) {
  switch (status) {
    case RealtimeConnectionStatus.connected:
      return AppColors.statusActive;
    case RealtimeConnectionStatus.connecting:
    case RealtimeConnectionStatus.reconnecting:
      return AppColors.statusSyncing;
    case RealtimeConnectionStatus.fallbackPolling:
      return AppColors.statusStale;
    case RealtimeConnectionStatus.disconnected:
      return AppColors.graphite700;
  }
}

String _qualityLabel(
  RealtimeConnectionStatus realtime,
  ConnectivityHealth connectivity,
) {
  if (connectivity == ConnectivityHealth.offline) return 'Sin conexión';
  if (connectivity == ConnectivityHealth.networkOnly) {
    return 'Servidor no alcanzable';
  }
  if (realtime == RealtimeConnectionStatus.connected) return 'Estable';
  if (realtime == RealtimeConnectionStatus.reconnecting ||
      realtime == RealtimeConnectionStatus.connecting) {
    return 'Recuperando';
  }
  if (realtime == RealtimeConnectionStatus.fallbackPolling) return 'Degradada';
  return 'No disponible';
}

Color _qualityColor(
  RealtimeConnectionStatus realtime,
  ConnectivityHealth connectivity,
) {
  if (connectivity == ConnectivityHealth.offline) return AppColors.graphite700;
  if (connectivity == ConnectivityHealth.networkOnly) {
    return AppColors.statusStale;
  }
  if (realtime == RealtimeConnectionStatus.connected) {
    return AppColors.statusActive;
  }
  if (realtime == RealtimeConnectionStatus.fallbackPolling) {
    return AppColors.statusStale;
  }
  return AppColors.statusSyncing;
}

String _relativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  if (difference.isNegative) {
    final ahead = dateTime.difference(now);
    if (ahead.inMinutes < 1) return 'en segundos';
    if (ahead.inHours < 1) return 'en ${ahead.inMinutes} min';
    return 'en ${ahead.inHours} h';
  }
  if (difference.inSeconds < 45) return 'hace segundos';
  if (difference.inMinutes < 1) return 'hace 1 min';
  if (difference.inHours < 1) return 'hace ${difference.inMinutes} min';
  if (difference.inDays < 1) return 'hace ${difference.inHours} h';
  return 'hace ${difference.inDays} d';
}

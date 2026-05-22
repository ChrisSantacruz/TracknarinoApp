import 'package:flutter/material.dart';

import '../../models/operational_diagnostics_model.dart';
import '../../release/operational_release_gate.dart';
import '../../release/release_gate_service.dart';
import '../../services/operational_diagnostics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/operational_card.dart';
import '../../widgets/operational/operational_empty_state.dart';
import '../../widgets/operational/operational_error_state.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../widgets/operational/operational_status_chip.dart';
import '../../widgets/operational/operational_svg_icon.dart';
import 'operational_replay_inspector_screen.dart';

class OperationalDiagnosticsScreen extends StatefulWidget {
  const OperationalDiagnosticsScreen({super.key});

  @override
  State<OperationalDiagnosticsScreen> createState() =>
      _OperationalDiagnosticsScreenState();
}

class _OperationalDiagnosticsScreenState
    extends State<OperationalDiagnosticsScreen> {
  OperationalDiagnostics? _diagnostics;
  bool _loading = true;
  String? _error;
  int _sinceHours = 24;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final diagnostics = await OperationalDiagnosticsService.fetchDiagnostics(
        sinceHours: _sinceHours,
      );
      if (!mounted) return;
      setState(() {
        _diagnostics = diagnostics;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el centro operacional: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDiagnostics,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _buildWindowSelector(),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const _DiagnosticsSkeleton()
          else if (_error != null)
            OperationalCard(
              child: OperationalErrorState(
                message: _error!,
                onRetry: _loadDiagnostics,
              ),
            )
          else if (_diagnostics != null)
            _DiagnosticsBody(diagnostics: _diagnostics!),
        ],
      ),
    );
  }

  Widget _buildWindowSelector() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Centro operacional',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 24, label: Text('24h')),
            ButtonSegment(value: 72, label: Text('72h')),
            ButtonSegment(value: 168, label: Text('7d')),
          ],
          selected: {_sinceHours},
          onSelectionChanged: (selected) {
            setState(() => _sinceHours = selected.first);
            _loadDiagnostics();
          },
        ),
      ],
    );
  }
}

class _DiagnosticsBody extends StatelessWidget {
  final OperationalDiagnostics diagnostics;

  const _DiagnosticsBody({required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommandHero(diagnostics: diagnostics),
        const SizedBox(height: AppSpacing.md),
        const _ReleaseReadinessPanel(),
        const SizedBox(height: AppSpacing.md),
        _OperationalMapPanel(analytics: diagnostics.routeAnalytics),
        const SizedBox(height: AppSpacing.md),
        _PerformanceHud(diagnostics: diagnostics),
        const SizedBox(height: AppSpacing.md),
        _HealthGrid(diagnostics: diagnostics),
        const SizedBox(height: AppSpacing.md),
        _RouteAnalyticsPanel(analytics: diagnostics.routeAnalytics),
        const SizedBox(height: AppSpacing.md),
        _RealtimePanel(diagnostics: diagnostics),
        const SizedBox(height: AppSpacing.md),
        _IncidentTimeline(timeline: diagnostics.timeline),
        const SizedBox(height: AppSpacing.md),
        _DeploymentReadiness(diagnostics: diagnostics),
      ],
    );
  }
}

class _PerformanceHud extends StatelessWidget {
  final OperationalDiagnostics diagnostics;

  const _PerformanceHud({required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    final pressure = diagnostics.routeAnalytics.operationalPressure;
    final realtime = diagnostics.realtimeHealth;
    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.graphite900,
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          border: Border.all(color: AppColors.deepGreen.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: OperationalSvgIcons.activity,
              title: 'HUD de desempeño operacional',
              subtitle:
                  'Vista táctica con presión de rutas, realtime, proveedor y recuperación offline observada.',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _HudChip(
                  label: 'Reruta',
                  value: pressure.reroutePressure.toString(),
                  color: AppColors.statusSyncing,
                ),
                _HudChip(
                  label: 'Reemplazos',
                  value: pressure.routeReplacementPressure.toString(),
                  color: AppColors.deepGreenLight,
                ),
                _HudChip(
                  label: 'Corredor',
                  value: pressure.corridorInstability.toString(),
                  color: AppColors.statusStale,
                ),
                _HudChip(
                  label: 'Offline replay',
                  value: diagnostics.fleetHealth.offlineReplay.toString(),
                  color: AppColors.deepGreen,
                ),
                _HudChip(
                  label: 'Socket',
                  value: realtime.reconnectStormState,
                  color:
                      realtime.reconnectStormState == 'degraded'
                          ? AppColors.alertCritical
                          : AppColors.statusActive,
                ),
                _HudChip(
                  label: 'Provider',
                  value: diagnostics.providerHealth.status,
                  color: _severityColor(diagnostics.providerHealth.status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseReadinessPanel extends StatefulWidget {
  const _ReleaseReadinessPanel();

  @override
  State<_ReleaseReadinessPanel> createState() => _ReleaseReadinessPanelState();
}

class _ReleaseReadinessPanelState extends State<_ReleaseReadinessPanel> {
  late Future<OperationalReleaseStatus> _future;

  @override
  void initState() {
    super.initState();
    _future = ReleaseGateService.fetchReleaseGates();
  }

  void _reload() {
    setState(() {
      _future = ReleaseGateService.fetchReleaseGates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OperationalReleaseStatus>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const OperationalCard(
            child: Column(
              children: [
                OperationalSkeleton(height: 16, width: double.infinity),
                SizedBox(height: AppSpacing.sm),
                OperationalSkeleton(height: 84, width: double.infinity),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return OperationalCard(
            child: OperationalErrorState(
              message: 'No se pudo cargar readiness de release: ${snapshot.error}',
              onRetry: _reload,
            ),
          );
        }

        final release = snapshot.data!;
        final color = _releaseStateColor(release.overallState);
        final blockers = release.unresolvedBlockers.take(3).toList();
        final evidence = release.evidenceCompleteness;
        return OperationalCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.graphite900,
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: OperationalSvgIcons.shieldCheck,
                  title: 'Release readiness',
                  subtitle:
                      'Gates reales de despliegue, evidencia, regresión y scaling. Sin estados saludables fabricados.',
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _HudChip(
                      label: 'Estado',
                      value: _releaseStateLabel(release.overallState),
                      color: color,
                    ),
                    _HudChip(
                      label: 'Confianza',
                      value: '${release.confidenceScore}/100',
                      color: color,
                    ),
                    _HudChip(
                      label: 'Evidencia',
                      value:
                          '${(evidence.scenarioCoverage * 100).round()}% escenarios',
                      color:
                          evidence.missingScenarioTypes.isEmpty
                              ? AppColors.statusActive
                              : AppColors.statusStale,
                    ),
                    _HudChip(
                      label: 'Artefactos',
                      value:
                          '${evidence.verifiedArtifacts}/${evidence.checkedArtifacts}',
                      color: AppColors.deepGreen,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  release.confidenceBasis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (blockers.isEmpty)
                  OperationalStatusChip(
                    label: 'Sin blockers críticos abiertos',
                    color: AppColors.statusActive,
                    compact: true,
                  )
                else
                  ...blockers.map(
                    (blocker) => _ConnectionRow(
                      label: blocker.code,
                      value: blocker.message,
                      color: _releaseStateColor(blocker.severity),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommandHero extends StatelessWidget {
  final OperationalDiagnostics diagnostics;

  const _CommandHero({required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(diagnostics.severity);
    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconOrb(icon: OperationalSvgIcons.activity, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Operación logística en vivo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              OperationalStatusChip(
                label: _severityLabel(diagnostics.severity),
                color: color,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Diagnósticos derivados de auditoría de rutas, telemetría del proveedor, estado realtime y GPS reciente. Sin KPIs estimados.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaPill(
                icon: OperationalSvgIcons.clock,
                text: 'Ventana ${diagnostics.window.hours}h',
              ),
              _MetaPill(
                icon: OperationalSvgIcons.route,
                text: '${diagnostics.routeAnalytics.activeRoutes} rutas activas',
              ),
              _MetaPill(
                icon: OperationalSvgIcons.radio,
                text:
                    '${diagnostics.realtimeHealth.connectedSockets} sockets activos',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OperationalReplayInspectorScreen(),
                  ),
                );
              },
              icon: const OperationalSvgIcon(
                OperationalSvgIcons.clock,
                color: AppColors.deepGreen,
                size: 16,
              ),
              label: const Text('Abrir replay'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalMapPanel extends StatelessWidget {
  final RouteAnalytics analytics;

  const _OperationalMapPanel({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final hotspots = [
      ...analytics.invalidationHotspots.take(4),
      ...analytics.corridorAlertDensity.take(4),
    ].take(6).toList();

    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: OperationalSvgIcons.mapPin,
            title: 'Mapa operativo de inestabilidad',
            subtitle:
                'Corredores con invalidaciones, degradación o intersecciones de alerta reales.',
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 190,
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.graphite900.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
              border: Border.all(
                color: AppColors.deepGreen.withValues(alpha: 0.35),
              ),
            ),
            child:
                hotspots.isEmpty
                    ? const Center(
                      child: Text(
                        'Sin inestabilidad de corredor en la ventana seleccionada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                    : Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children:
                          hotspots
                              .map(
                                (hotspot) => _HotspotChip(hotspot: hotspot),
                              )
                              .toList(),
                    ),
          ),
        ],
      ),
    );
  }
}

class _HealthGrid extends StatelessWidget {
  final OperationalDiagnostics diagnostics;

  const _HealthGrid({required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      children: [
        _MetricTile(
          icon: OperationalSvgIcons.truck,
          label: 'Flota activa',
          value: diagnostics.fleetHealth.active.toString(),
          detail:
              '${diagnostics.fleetHealth.stale} antigua, ${diagnostics.fleetHealth.offline} sin señal',
          color: _severityColor(diagnostics.fleetHealth.severity),
        ),
        _MetricTile(
          icon: OperationalSvgIcons.route,
          label: 'Rerutas',
          value:
              diagnostics.routeAnalytics.counts['rerouteFrequency']
                  ?.toString() ??
              '0',
          detail: 'Frecuencia derivada de auditoría',
          color: AppColors.statusSyncing,
        ),
        _MetricTile(
          icon: OperationalSvgIcons.alertTriangle,
          label: 'Rutas degradadas',
          value:
              diagnostics.routeAnalytics.counts['degradedRoutes']
                  ?.toString() ??
              '0',
          detail:
              '${diagnostics.routeAnalytics.counts['staleRoutes'] ?? 0} stale en ventana',
          color: AppColors.statusStale,
        ),
        _MetricTile(
          icon: OperationalSvgIcons.database,
          label: 'Replay offline',
          value: diagnostics.fleetHealth.offlineReplay.toString(),
          detail: 'GPS confirmado desde cola local',
          color: AppColors.deepGreen,
        ),
      ],
    );
  }
}

class _RouteAnalyticsPanel extends StatelessWidget {
  final RouteAnalytics analytics;

  const _RouteAnalyticsPanel({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: OperationalSvgIcons.route,
            title: 'Analítica de rutas y rerutas',
            subtitle:
                'Causas y hotspots derivados de RouteAuditRecord y RouteTelemetryEvent.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (analytics.rerouteCauses.isEmpty)
            const OperationalEmptyState(
              icon: Icons.route_outlined,
              title: 'Sin causas de reruta',
              message: 'No hay rerutas registradas en la ventana seleccionada.',
            )
          else
            ...analytics.rerouteCauses.map(
              (cause) => _CountRow(
                label: cause.name,
                count: cause.count,
                color: AppColors.statusSyncing,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          ...analytics.providerReliability.map(
            (provider) => _CountRow(
              label:
                  '${provider.provider} · fallos ${(provider.failureRate * 100).toStringAsFixed(0)}%',
              count: provider.failures,
              color:
                  provider.failures > 0
                      ? AppColors.alertCritical
                      : AppColors.statusActive,
            ),
          ),
        ],
      ),
    );
  }
}

class _RealtimePanel extends StatelessWidget {
  final OperationalDiagnostics diagnostics;

  const _RealtimePanel({required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    final realtime = diagnostics.realtimeHealth;
    final adapterColor =
        realtime.adapterStatus == 'ready'
            ? AppColors.statusActive
            : AppColors.statusStale;

    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: OperationalSvgIcons.radio,
            title: 'Salud realtime',
            subtitle:
                'Socket.IO, rooms, fallback local y preparación multi-nodo.',
          ),
          const SizedBox(height: AppSpacing.md),
          _ConnectionRow(
            label: 'Adapter',
            value: '${realtime.adapterType} · ${realtime.adapterStatus}',
            color: adapterColor,
          ),
          _ConnectionRow(
            label: 'Rooms',
            value: '${realtime.knownRooms} rooms conocidos',
            color: AppColors.deepGreen,
          ),
          _ConnectionRow(
            label: 'Reconexiones',
            value:
                '${realtime.recentConnectionCount} en ventana runtime · ${realtime.reconnectStormState}',
            color:
                realtime.reconnectStormState == 'degraded'
                    ? AppColors.alertCritical
                    : AppColors.statusActive,
          ),
          _ConnectionRow(
            label: 'Multi-nodo',
            value:
                realtime.multiNodeCompatible
                    ? 'Redis adapter listo'
                    : realtime.stickySessionsRequired
                    ? 'Sticky sessions requeridas'
                    : 'Adapter local',
            color:
                realtime.multiNodeCompatible
                    ? AppColors.statusActive
                    : AppColors.statusStale,
          ),
          if (realtime.roomOccupancy.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...realtime.roomOccupancy.take(4).map(
              (room) => _ConnectionRow(
                label: _shortId(room.room),
                value: '${room.sockets} socket(s)',
                color: AppColors.deepGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HudChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132, minHeight: 48),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconOrb(icon: OperationalSvgIcons.activity, color: color, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentTimeline extends StatelessWidget {
  final List<IncidentTimelineEvent> timeline;

  const _IncidentTimeline({required this.timeline});

  @override
  Widget build(BuildContext context) {
    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: OperationalSvgIcons.clock,
            title: 'Línea de incidente',
            subtitle:
                'Base de replay operacional para rutas, rerutas, alertas y degradaciones.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (timeline.isEmpty)
            const OperationalEmptyState(
              icon: Icons.history,
              title: 'Sin eventos recientes',
              message: 'El replay aparecerá cuando existan auditorías reales.',
            )
          else
            ...timeline.take(12).map((event) => _TimelineRow(event: event)),
        ],
      ),
    );
  }
}

class _DeploymentReadiness extends StatelessWidget {
  final OperationalDiagnostics diagnostics;

  const _DeploymentReadiness({required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    final env = diagnostics.environmentReadiness;
    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: OperationalSvgIcons.shieldCheck,
            title: 'Readiness de despliegue',
            subtitle:
                'Separación de ambiente, proveedor, Redis y replay sin exponer secretos.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OperationalStatusChip(
                label: env.ok ? 'Env listo' : 'Env incompleto',
                color: env.ok ? AppColors.statusActive : AppColors.statusStale,
                compact: true,
              ),
              OperationalStatusChip(
                label: env.redisSocketAdapter ? 'Redis preparado' : 'Adapter local',
                color:
                    env.redisSocketAdapter
                        ? AppColors.statusActive
                        : AppColors.graphite700,
                compact: true,
              ),
              OperationalStatusChip(
                label: env.providerReady ? 'Provider listo' : 'Provider revisar',
                color:
                    env.providerReady
                        ? AppColors.statusActive
                        : AppColors.alertCritical,
                compact: true,
              ),
              OperationalStatusChip(
                label:
                    diagnostics.replayReadiness.timelineAvailable
                        ? 'Timeline activo'
                        : 'Timeline pendiente',
                color: AppColors.deepGreen,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            diagnostics.replayReadiness.note,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSkeleton extends StatelessWidget {
  const _DiagnosticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const OperationalCard(
      child: Column(
        children: [
          OperationalSkeleton(height: 18, width: double.infinity),
          SizedBox(height: AppSpacing.md),
          OperationalSkeleton(height: 120, width: double.infinity),
          SizedBox(height: AppSpacing.md),
          OperationalSkeleton(height: 18, width: 220),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconOrb(icon: icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OperationalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconOrb(icon: icon, color: color, size: 34),
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

class _HotspotChip extends StatelessWidget {
  final RouteHotspot hotspot;

  const _HotspotChip({required this.hotspot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      constraints: const BoxConstraints(maxWidth: 190),
      decoration: BoxDecoration(
        color: AppColors.deepGreen.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.deepGreen.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OperationalSvgIcon(
            OperationalSvgIcons.mapPin,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              '${_shortId(hotspot.routeId)} · ${hotspot.count}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountRow({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          _IconOrb(icon: OperationalSvgIcons.activity, color: color, size: 30),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          OperationalStatusChip(
            label: count.toString(),
            color: color,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ConnectionRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          _IconOrb(icon: OperationalSvgIcons.radio, color: color, size: 32),
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
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IncidentTimelineEvent event;

  const _TimelineRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(event.severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconOrb(icon: OperationalSvgIcons.clock, color: color, size: 30),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventType,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  event.reason ?? _shortId(event.routeId ?? 'sin ruta'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OperationalStatusChip(
            label: _relativeTime(event.occurredAt),
            color: color,
            compact: true,
          ),
        ],
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
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OperationalSvgIcon(icon, color: AppColors.graphite700, size: 13),
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

  const _IconOrb({required this.icon, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}

Color _severityColor(String severity) {
  switch (severity) {
    case 'critical':
    case 'fail':
    case 'blocked':
      return AppColors.alertCritical;
    case 'warning':
    case 'degraded':
      return AppColors.statusStale;
    case 'healthy':
    case 'ok':
    case 'pass':
      return AppColors.statusActive;
    default:
      return AppColors.deepGreen;
  }
}

Color _releaseStateColor(String state) {
  switch (state) {
    case 'pass':
      return AppColors.statusActive;
    case 'warning':
      return AppColors.statusStale;
    case 'fail':
    case 'blocked':
    case 'critical':
      return AppColors.alertCritical;
    default:
      return AppColors.deepGreen;
  }
}

String _releaseStateLabel(String state) {
  switch (state) {
    case 'pass':
      return 'Aprobado';
    case 'warning':
      return 'Advertencia';
    case 'blocked':
      return 'Bloqueado';
    case 'fail':
      return 'No liberar';
    default:
      return state;
  }
}

String _severityLabel(String severity) {
  switch (severity) {
    case 'critical':
      return 'Crítico';
    case 'warning':
      return 'Atención';
    case 'healthy':
      return 'Saludable';
    default:
      return 'Informativo';
  }
}

String _shortId(String value) {
  if (value.length <= 16) return value;
  return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
}

String _relativeTime(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime.toLocal());
  if (difference.inMinutes < 1) return 'ahora';
  if (difference.inHours < 1) return '${difference.inMinutes} min';
  if (difference.inDays < 1) return '${difference.inHours} h';
  return '${difference.inDays} d';
}

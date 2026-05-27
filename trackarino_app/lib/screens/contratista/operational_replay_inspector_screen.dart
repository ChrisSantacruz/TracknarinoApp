import 'package:flutter/material.dart';

import '../../models/operational_diagnostics_model.dart';
import '../../services/operational_diagnostics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/operational/operational_card.dart';
import '../../widgets/operational/operational_empty_state.dart';
import '../../widgets/operational/operational_error_state.dart';
import '../../widgets/operational/operational_skeleton.dart';
import '../../widgets/operational/operational_status_chip.dart';
import '../../widgets/operational/operational_svg_icon.dart';
import '../../widgets/operational/premium_operational_widgets.dart';

class OperationalReplayInspectorScreen extends StatefulWidget {
  const OperationalReplayInspectorScreen({super.key});

  @override
  State<OperationalReplayInspectorScreen> createState() =>
      _OperationalReplayInspectorScreenState();
}

class _OperationalReplayInspectorScreenState
    extends State<OperationalReplayInspectorScreen> {
  OperationalDiagnostics? _diagnostics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final diagnostics = await OperationalDiagnosticsService.fetchDiagnostics(
        sinceHours: 168,
      );
      if (!mounted) return;
      setState(() {
        _diagnostics = diagnostics;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el replay operacional: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Replay operacional')),
      backgroundColor: AppColors.inkBlack,
      body: PremiumGradientScaffold(
        safeArea: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const PremiumScreenHeader(
                eyebrow: 'Replay',
                title: 'Historial operacional',
                subtitle:
                    'Eventos de diagnóstico y sincronización de los últimos 7 días.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const PremiumGlassCard(
                  child: OperationalSkeleton(
                    height: 180,
                    width: double.infinity,
                  ),
                )
              else if (_error != null)
                PremiumGlassCard(
                  child: OperationalErrorState(
                    message: _error!,
                    onRetry: _load,
                  ),
                )
              else if (_diagnostics != null)
                _ReplayTimeline(diagnostics: _diagnostics!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayTimeline extends StatelessWidget {
  final OperationalDiagnostics diagnostics;

  const _ReplayTimeline({required this.diagnostics});

  @override
  Widget build(BuildContext context) {
    final timeline = diagnostics.timeline;
    return OperationalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const OperationalSvgIcon(
                OperationalSvgIcons.route,
                color: AppColors.deepGreen,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Inspector timeline-first',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              OperationalStatusChip(
                label: '${timeline.length} eventos',
                color: AppColors.deepGreen,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Muestra auditorías reales de ciclo de ruta, reruta, recuperación offline e intersecciones de corredor. No interpola mapa ni genera playback falso.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (timeline.isEmpty)
            const OperationalEmptyState(
              icon: Icons.timeline,
              title: 'Sin replay disponible',
              message:
                  'El inspector se habilita cuando existan eventos reales.',
            )
          else
            ...timeline.map((event) => _ReplayEventRow(event: event)),
        ],
      ),
    );
  }
}

class _ReplayEventRow extends StatelessWidget {
  final IncidentTimelineEvent event;

  const _ReplayEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(event.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          OperationalSvgIcon(OperationalSvgIcons.clock, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventType,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  event.reason ?? event.routeId ?? 'sin ruta asociada',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OperationalStatusChip(
            label: event.severity,
            color: color,
            compact: true,
          ),
        ],
      ),
    );
  }
}

Color _colorFor(String severity) {
  switch (severity) {
    case 'critical':
      return AppColors.alertCritical;
    case 'warning':
      return AppColors.statusStale;
    default:
      return AppColors.deepGreen;
  }
}

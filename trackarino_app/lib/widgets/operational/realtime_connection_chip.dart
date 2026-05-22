import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/realtime_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class RealtimeConnectionChip extends StatelessWidget {
  final RealtimeConnectionStatus status;

  const RealtimeConnectionChip({super.key, required this.status});

  static Color colorFor(RealtimeConnectionStatus status) {
    switch (status) {
      case RealtimeConnectionStatus.connected:
        return AppColors.statusActive;
      case RealtimeConnectionStatus.connecting:
      case RealtimeConnectionStatus.reconnecting:
        return AppColors.statusStale;
      case RealtimeConnectionStatus.fallbackPolling:
      case RealtimeConnectionStatus.disconnected:
        return AppColors.graphite700;
    }
  }

  static String labelFor(RealtimeConnectionStatus status) {
    switch (status) {
      case RealtimeConnectionStatus.connected:
        return 'Tiempo real activo';
      case RealtimeConnectionStatus.connecting:
        return 'Conectando';
      case RealtimeConnectionStatus.reconnecting:
        return 'Reconectando';
      case RealtimeConnectionStatus.fallbackPolling:
        return 'Respaldo por polling';
      case RealtimeConnectionStatus.disconnected:
        return 'Sin socket';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.string(
            status == RealtimeConnectionStatus.connected
                ? _radioSvg
                : _syncSvg,
            width: 12,
            height: 12,
            color: color,
            semanticsLabel: labelFor(status),
          ),
          const SizedBox(width: 4),
          Text(
            labelFor(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

const String _radioSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M4.9 19.1C1 15.2 1 8.8 4.9 4.9M19.1 4.9C23 8.8 23 15.2 19.1 19.1M8.5 15.5C6.6 13.6 6.6 10.4 8.5 8.5M15.5 8.5C17.4 10.4 17.4 13.6 15.5 15.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <circle cx="12" cy="12" r="1.8" fill="currentColor"/>
</svg>
''';

const String _syncSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M20 7V12H15M4 17V12H9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M18.1 9C16.9 6.6 14.5 5 11.8 5C8.8 5 6.3 6.9 5.3 9.6M5.9 15C7.1 17.4 9.5 19 12.2 19C15.2 19 17.7 17.1 18.7 14.4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

/// Map legend for fleet tracking states.
class FleetMapLegend extends StatelessWidget {
  const FleetMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            _LegendRow(color: AppColors.statusActive, label: 'Activo'),
            SizedBox(height: 4),
            _LegendRow(color: AppColors.statusStale, label: 'Señal antigua'),
            SizedBox(height: 4),
            _LegendRow(color: AppColors.statusOffline, label: 'Sin señal'),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

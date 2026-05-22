import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../map/operational_map_intelligence.dart';
import '../../routing/operational_routing_intelligence.dart';

class OperationalRouteLayer extends StatelessWidget {
  final List<LatLng> points;
  final int completedPointCount;
  final bool emphasized;

  const OperationalRouteLayer({
    super.key,
    required this.points,
    this.completedPointCount = 0,
    this.emphasized = true,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    final activePoints =
        completedPointCount > 0 && completedPointCount < points.length
            ? points.sublist(completedPointCount - 1)
            : points;
    final completedPoints =
        completedPointCount > 1
            ? points.sublist(0, completedPointCount.clamp(0, points.length))
            : <LatLng>[];

    final activeColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.deepGreenLight
            : AppColors.routeLine;

    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          strokeWidth: emphasized ? 9 : 7,
          color: activeColor.withValues(alpha: 0.12),
        ),
        if (completedPoints.length > 1)
          Polyline(
            points: completedPoints,
            strokeWidth: 4,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.28),
          ),
        Polyline(
          points: activePoints,
          strokeWidth: emphasized ? 4.8 : 3.8,
          color: activeColor,
        ),
      ],
    );
  }
}

class OperationalRouteCorridorLayer extends StatelessWidget {
  final List<LatLng> points;
  final double toleranceMeters;
  final RouteHealthState health;
  final bool visible;

  const OperationalRouteCorridorLayer({
    super.key,
    required this.points,
    required this.toleranceMeters,
    required this.health,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || points.length < 2) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _routeHealthColor(health);
    final width = _corridorStrokeWidth(toleranceMeters);

    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          strokeWidth: width,
          color: color.withValues(alpha: dark ? 0.12 : 0.09),
        ),
        Polyline(
          points: points,
          strokeWidth: 1.2,
          color: color.withValues(alpha: dark ? 0.22 : 0.18),
        ),
      ],
    );
  }
}

class OperationalDegradedRouteSegmentsLayer extends StatelessWidget {
  final List<List<LatLng>> segments;

  const OperationalDegradedRouteSegmentsLayer({
    super.key,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSegments =
        segments.where((segment) => segment.length >= 2).toList();
    if (visibleSegments.isEmpty) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        for (final segment in visibleSegments)
          Polyline(
            points: segment,
            strokeWidth: 8,
            color: AppColors.alertWarning.withValues(alpha: 0.30),
          ),
        for (final segment in visibleSegments)
          Polyline(
            points: segment,
            strokeWidth: 3,
            color: AppColors.alertWarning.withValues(alpha: 0.82),
          ),
      ],
    );
  }
}

class OperationalRerouteCandidateLayer extends StatelessWidget {
  final List<LatLng> points;

  const OperationalRerouteCandidateLayer({
    super.key,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          strokeWidth: 7,
          color: AppColors.alertInfo.withValues(alpha: 0.14),
        ),
        Polyline(
          points: points,
          strokeWidth: 3,
          color: AppColors.alertInfo.withValues(alpha: 0.72),
          isDotted: true,
        ),
      ],
    );
  }
}

class OperationalRouteHealthChip extends StatelessWidget {
  final RouteHealthState health;
  final RouteDeviationSeverity deviation;
  final int corridorAlertCount;
  final bool rerouteRecommended;

  const OperationalRouteHealthChip({
    super.key,
    required this.health,
    required this.deviation,
    required this.corridorAlertCount,
    required this.rerouteRecommended,
  });

  @override
  Widget build(BuildContext context) {
    final color = _routeHealthColor(health);
    final label = _routeHealthLabel(health);
    final detail =
        rerouteRecommended
            ? 'Reruta recomendada'
            : corridorAlertCount > 0
                ? '$corridorAlertCount alerta(s) en corredor'
                : _deviationLabel(deviation);

    return Material(
      elevation: 7,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OperationalVehiclePresenceMarker extends StatelessWidget {
  final String status;
  final double heading;
  final bool selected;
  final String semanticsLabel;

  const OperationalVehiclePresenceMarker({
    super.key,
    required this.status,
    required this.heading,
    required this.semanticsLabel,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.trackingStatusColor(status);
    final surface = Theme.of(context).colorScheme.surface;

    return Semantics(
      label: semanticsLabel,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (status == 'active' || status == 'en_ruta')
                _OperationalPulse(color: color, size: 52),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surface.withValues(alpha: 0.96),
                  border: Border.all(
                    color: selected ? color : color.withValues(alpha: 0.42),
                    width: selected ? 2.4 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: heading / 360,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: SvgPicture.string(
                  _navigationSvg(_hex(color), _hex(surface)),
                  width: 26,
                  height: 26,
                  semanticsLabel: semanticsLabel,
                ),
              ),
              Positioned(
                right: 5,
                bottom: 5,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OperationalDestinationMarker extends StatelessWidget {
  final String label;

  const OperationalDestinationMarker({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return Semantics(
      label: label,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: surface.withValues(alpha: 0.96),
          border: Border.all(color: AppColors.mapMarkerDestination, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.string(
            _flagSvg,
            width: 23,
            height: 23,
            color: AppColors.mapMarkerDestination,
            semanticsLabel: label,
          ),
        ),
      ),
    );
  }
}

class OperationalAlertMarker extends StatelessWidget {
  final String type;
  final DateTime? timestamp;
  final bool selected;
  final VoidCallback? onTap;

  const OperationalAlertMarker({
    super.key,
    required this.type,
    this.timestamp,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = OperationalAlertMeta.fromType(type);
    final surface = Theme.of(context).colorScheme.surface;
    final isCritical = meta.severity == OperationalAlertSeverity.critical;
    final freshness = timestamp == null ? null : _freshnessLabel(timestamp!);

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: onTap != null,
        label: '${meta.label}${freshness == null ? '' : ', $freshness'}',
        child: AnimatedScale(
          scale: selected ? 1.1 : 1,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isCritical) _OperationalPulse(color: meta.color, size: 52),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: surface.withValues(alpha: 0.96),
                    border: Border.all(
                      color:
                          selected
                              ? meta.color
                              : meta.color.withValues(alpha: 0.56),
                      width: selected ? 2.2 : 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.string(
                      meta.svg,
                      width: 22,
                      height: 22,
                      color: meta.color,
                      semanticsLabel: meta.label,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: meta.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OperationalFleetClusterMarker extends StatelessWidget {
  final OperationalFleetCluster cluster;
  final VoidCallback? onTap;

  const OperationalFleetClusterMarker({
    super.key,
    required this.cluster,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = _clusterPriorityColor(cluster.priority);
    final surface = Theme.of(context).colorScheme.surface;
    final label = '${cluster.count} vehiculos, ${cluster.activeCount} activos';

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: onTap != null,
        label: label,
        child: AnimatedScale(
          scale: cluster.selected ? 1.08 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.string(
                  _clusterSvg(
                    _hex(priorityColor),
                    _hex(surface),
                    cluster.count >= 10 ? 1 : 0,
                  ),
                  width: 66,
                  height: 66,
                  semanticsLabel: label,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cluster.count.toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                      ),
                    ),
                    Text(
                      cluster.activeTripCount > 0 ? 'ruta' : 'flota',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OperationalAlertClusterMarker extends StatelessWidget {
  final OperationalAlertCluster cluster;
  final VoidCallback? onTap;

  const OperationalAlertClusterMarker({
    super.key,
    required this.cluster,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        cluster.hasCritical ? AppColors.alertCritical : AppColors.alertWarning;
    final surface = Theme.of(context).colorScheme.surface;
    final label = '${cluster.count} alertas agrupadas';

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: onTap != null,
        label: label,
        child: SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.string(
                _clusterSvg(
                  _hex(color),
                  _hex(surface),
                  cluster.hasCritical ? 1 : 0,
                ),
                width: 62,
                height: 62,
                semanticsLabel: label,
              ),
              Text(
                cluster.count.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OperationalDensityCircleLayer extends StatelessWidget {
  final List<OperationalDensityCell> cells;
  final Color color;
  final bool visible;

  const OperationalDensityCircleLayer({
    super.key,
    required this.cells,
    required this.color,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || cells.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return CircleLayer(
      circles:
          cells.map((cell) {
            final intensity = cell.count.clamp(2, 18) / 18;
            final radius = 90.0 + (cell.count.clamp(2, 18) * 18.0);
            return CircleMarker(
              point: cell.center,
              radius: radius,
              useRadiusInMeter: true,
              color: color.withValues(alpha: (dark ? 0.16 : 0.12) * intensity),
              borderColor: color.withValues(
                alpha: (dark ? 0.22 : 0.18) * intensity,
              ),
              borderStrokeWidth: 1,
            );
          }).toList(),
    );
  }
}

class OperationalMapActionChip extends StatelessWidget {
  final String svg;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const OperationalMapActionChip({
    super.key,
    required this.svg,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;

    return Material(
      elevation: 7,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      color: scheme.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.string(
                  svg,
                  width: 19,
                  height: 19,
                  color: accent,
                  semanticsLabel: label,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _clusterPriorityColor(int priority) {
  if (priority >= 70) return AppColors.statusActive;
  if (priority >= 45) return AppColors.statusStale;
  return AppColors.graphite700;
}

Color _routeHealthColor(RouteHealthState health) {
  switch (health) {
    case RouteHealthState.healthy:
      return AppColors.statusActive;
    case RouteHealthState.caution:
    case RouteHealthState.stale:
      return AppColors.statusStale;
    case RouteHealthState.degraded:
    case RouteHealthState.invalid:
      return AppColors.alertCritical;
    case RouteHealthState.rerouting:
      return AppColors.alertInfo;
    case RouteHealthState.offline:
      return AppColors.graphite700;
  }
}

String _routeHealthLabel(RouteHealthState health) {
  switch (health) {
    case RouteHealthState.healthy:
      return 'Ruta saludable';
    case RouteHealthState.caution:
      return 'Ruta en cautela';
    case RouteHealthState.degraded:
      return 'Ruta degradada';
    case RouteHealthState.rerouting:
      return 'Recalculando';
    case RouteHealthState.stale:
      return 'Ruta antigua';
    case RouteHealthState.invalid:
      return 'Ruta inválida';
    case RouteHealthState.offline:
      return 'Modo offline';
  }
}

String _deviationLabel(RouteDeviationSeverity deviation) {
  switch (deviation) {
    case RouteDeviationSeverity.onRoute:
      return 'Dentro del corredor';
    case RouteDeviationSeverity.slight:
      return 'Desvío leve';
    case RouteDeviationSeverity.significant:
      return 'Desvío significativo';
    case RouteDeviationSeverity.invalid:
      return 'Fuera de corredor';
  }
}

double _corridorStrokeWidth(double toleranceMeters) {
  if (toleranceMeters >= 140) return 24;
  if (toleranceMeters >= 90) return 20;
  return 16;
}

String _clusterSvg(String accent, String surface, int emphasized) => '''
<svg width="72" height="72" viewBox="0 0 72 72" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="36" cy="36" r="31" fill="$accent" fill-opacity="${emphasized == 1 ? '0.12' : '0.08'}"/>
  <circle cx="36" cy="36" r="24" fill="$surface" fill-opacity="0.97"/>
  <circle cx="36" cy="36" r="24" stroke="$accent" stroke-opacity="0.72" stroke-width="${emphasized == 1 ? '2.6' : '1.8'}"/>
  <path d="M20 36C20 27.2 27.2 20 36 20C44.8 20 52 27.2 52 36" stroke="$accent" stroke-opacity="0.34" stroke-width="3" stroke-linecap="round"/>
  <circle cx="54" cy="24" r="5" fill="$accent" fill-opacity="${emphasized == 1 ? '1' : '0.72'}"/>
</svg>
''';

class OperationalAlertMeta {
  final String label;
  final Color color;
  final String svg;
  final OperationalAlertSeverity severity;

  const OperationalAlertMeta({
    required this.label,
    required this.color,
    required this.svg,
    required this.severity,
  });

  static OperationalAlertMeta fromType(String type) {
    switch (type.toLowerCase()) {
      case 'accidente':
        return const OperationalAlertMeta(
          label: 'Accidente',
          color: AppColors.alertCritical,
          svg: _accidentSvg,
          severity: OperationalAlertSeverity.critical,
        );
      case 'robo':
      case 'intento_robo':
      case 'sospecha':
        return const OperationalAlertMeta(
          label: 'Riesgo de robo',
          color: AppColors.alertCritical,
          svg: _shieldAlertSvg,
          severity: OperationalAlertSeverity.critical,
        );
      case 'obstaculo':
      case 'bloqueo':
      case 'trancon':
      case 'trafico':
        return const OperationalAlertMeta(
          label: 'Bloqueo vial',
          color: AppColors.alertWarning,
          svg: _roadBlockSvg,
          severity: OperationalAlertSeverity.warning,
        );
      case 'derrumbe':
      case 'deslizamiento':
      case 'landslide':
        return const OperationalAlertMeta(
          label: 'Deslizamiento',
          color: AppColors.alertWarning,
          svg: _landslideSvg,
          severity: OperationalAlertSeverity.warning,
        );
      case 'protesta':
      case 'protest':
        return const OperationalAlertMeta(
          label: 'Protesta',
          color: AppColors.alertWarning,
          svg: _protestSvg,
          severity: OperationalAlertSeverity.warning,
        );
      case 'clima':
      case 'clima_adverso':
      case 'weather':
        return const OperationalAlertMeta(
          label: 'Riesgo climático',
          color: AppColors.alertInfo,
          svg: _weatherSvg,
          severity: OperationalAlertSeverity.info,
        );
      default:
        return const OperationalAlertMeta(
          label: 'Alerta operativa',
          color: AppColors.graphite700,
          svg: _alertTriangleSvg,
          severity: OperationalAlertSeverity.info,
        );
    }
  }
}

enum OperationalAlertSeverity { critical, warning, info }

class _OperationalPulse extends StatelessWidget {
  final Color color;
  final double size;

  const _OperationalPulse({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.74, end: 1),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) {
        return Container(
          width: size * (1.08 + value * 0.16),
          height: size * (1.08 + value * 0.16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.09 * (1 - value)),
            border: Border.all(
              color: color.withValues(alpha: 0.16 * (1 - value)),
            ),
          ),
        );
      },
    );
  }
}

String _freshnessLabel(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.inMinutes < 60) {
    return 'reportada hace ${difference.inMinutes} min';
  }
  if (difference.inHours < 24) return 'reportada hace ${difference.inHours} h';
  return 'reportada hace ${difference.inDays} dias';
}

String _hex(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

String _navigationSvg(String bodyColor, String surfaceColor) => '''
<svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M16 3.5L24.5 28L16 23.2L7.5 28L16 3.5Z" fill="$bodyColor"/>
  <path d="M16 8.8L20.2 21.8L16 19.4L11.8 21.8L16 8.8Z" fill="$surfaceColor" fill-opacity="0.76"/>
  <path d="M16 3.5L24.5 28L16 23.2L7.5 28L16 3.5Z" stroke="$surfaceColor" stroke-opacity="0.72" stroke-width="1.2" stroke-linejoin="round"/>
</svg>
''';

const String operationalRefreshSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M20 6V11H15" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M4 18V13H9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M18.5 9A7 7 0 0 0 6.2 6.8L4 9M20 15L17.8 17.2A7 7 0 0 1 5.5 15" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const String operationalAlertSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 3L21 19H3L12 3Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
  <path d="M12 9V13" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <circle cx="12" cy="16.5" r="1" fill="currentColor"/>
</svg>
''';

const String operationalPhoneSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M22 16.9V19.6C22 21 20.8 22.1 19.4 22C9.8 21.4 2.6 14.2 2 4.6C1.9 3.2 3 2 4.4 2H7.1C7.8 2 8.4 2.5 8.6 3.2L9.4 6.5C9.6 7.2 9.4 7.9 8.8 8.3L7.4 9.4C8.6 12.5 11.5 15.4 14.6 16.6L15.7 15.2C16.1 14.6 16.8 14.4 17.5 14.6L20.8 15.4C21.5 15.6 22 16.2 22 16.9Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
</svg>
''';

const String operationalCrosshairSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="7" stroke="currentColor" stroke-width="2"/>
  <path d="M12 2V5M12 19V22M2 12H5M19 12H22" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <circle cx="12" cy="12" r="2" fill="currentColor"/>
</svg>
''';

const String _flagSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 21V4M6 4H18L16 8L18 12H6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const String _alertTriangleSvg = operationalAlertSvg;

const String _accidentSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M7 17H17M8 17L6 20M16 17L18 20M6 13L8.2 7.5C8.5 6.6 9.4 6 10.3 6H13.7C14.6 6 15.5 6.6 15.8 7.5L18 13" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M5 13H19V17H5V13Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
  <circle cx="8" cy="15.2" r="1" fill="currentColor"/>
  <circle cx="16" cy="15.2" r="1" fill="currentColor"/>
</svg>
''';

const String _shieldAlertSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 3L19 6V11C19 15.5 16.2 19.5 12 21C7.8 19.5 5 15.5 5 11V6L12 3Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
  <path d="M12 8V12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <circle cx="12" cy="15.5" r="1" fill="currentColor"/>
</svg>
''';

const String _roadBlockSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M4 14H20M6 10H18M7 18L9 6M17 18L15 6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M8 10L5 14M13 10L10 14M18 10L15 14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

const String _landslideSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M3 20H21L15 8L11 14L8 10L3 20Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
  <circle cx="17" cy="5" r="2" stroke="currentColor" stroke-width="2"/>
</svg>
''';

const String _protestSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 21V4M6 4H17V12H6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M10 8H15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

const String _weatherSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M7 18H17.5C20 18 22 16 22 13.5C22 11.1 20.1 9.1 17.7 9C16.9 6.1 14.3 4 11.2 4C7.9 4 5.2 6.4 4.7 9.5C3.1 10.1 2 11.6 2 13.4C2 15.9 4.1 18 7 18Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
  <path d="M8 21L9 19M13 21L14 19M18 21L19 19" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

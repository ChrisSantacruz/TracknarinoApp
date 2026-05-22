import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_spacing.dart';

class MapControlCluster extends StatelessWidget {
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onRecenter;
  final VoidCallback? onFitFleet;
  final VoidCallback? onFilter;
  final bool recenterActive;
  final bool filterActive;

  const MapControlCluster({
    super.key,
    this.onZoomIn,
    this.onZoomOut,
    this.onRecenter,
    this.onFitFleet,
    this.onFilter,
    this.recenterActive = true,
    this.filterActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onZoomIn != null)
          _MapControlButton(
            svg: _plusSvg,
            tooltip: 'Acercar',
            onPressed: onZoomIn!,
          ),
        if (onZoomIn != null && onZoomOut != null)
          const SizedBox(height: AppSpacing.xs),
        if (onZoomOut != null)
          _MapControlButton(
            svg: _minusSvg,
            tooltip: 'Alejar',
            onPressed: onZoomOut!,
          ),
        if (onRecenter != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _MapControlButton(
            svg: _targetSvg,
            tooltip: 'Centrar flota',
            onPressed: onRecenter!,
            highlighted: recenterActive,
          ),
        ],
        if (onFitFleet != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _MapControlButton(
            svg: _expandSvg,
            tooltip: 'Ajustar flota activa',
            onPressed: onFitFleet!,
          ),
        ],
        if (onFilter != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _MapControlButton(
            svg: _filterSvg,
            tooltip: 'Filtrar estados',
            onPressed: onFilter!,
            highlighted: filterActive,
          ),
        ],
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final String svg;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlighted;

  const _MapControlButton({
    required this.svg,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      color: highlighted ? scheme.primary : scheme.surface,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: SizedBox(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          child: Center(
            child: SvgPicture.string(
              svg,
              width: 20,
              height: 20,
              color: highlighted ? scheme.onPrimary : scheme.onSurface,
              semanticsLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}

const String _plusSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 5V19M5 12H19" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

const String _minusSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M5 12H19" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

const String _targetSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 3V6M12 18V21M3 12H6M18 12H21" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <circle cx="12" cy="12" r="5" stroke="currentColor" stroke-width="2"/>
  <circle cx="12" cy="12" r="1.5" fill="currentColor"/>
</svg>
''';

const String _expandSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M8 3H3V8M16 3H21V8M21 16V21H16M3 16V21H8" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M3 3L9 9M21 3L15 9M21 21L15 15M3 21L9 15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

const String _filterSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M4 5H20L14 12V18L10 20V12L4 5Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
</svg>
''';

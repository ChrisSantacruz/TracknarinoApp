import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';

/// Consistent fleet truck marker for contractor maps.
class FleetMapMarker extends StatelessWidget {
  final String status;
  final String? initial;
  final double size;
  final double heading;
  final bool selected;

  const FleetMapMarker({
    super.key,
    required this.status,
    this.initial,
    this.size = 44,
    this.heading = 0,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.trackingStatusColor(status);
    final letter = (initial != null && initial!.isNotEmpty)
        ? initial!.substring(0, 1).toUpperCase()
        : '?';

    final marker = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (status == 'active')
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.72, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) {
                return Container(
                  width: size * (1.25 + value * 0.12),
                  height: size * (1.25 + value * 0.12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.08 * (1 - value)),
                    border: Border.all(
                      color: color.withValues(alpha: 0.16 * (1 - value)),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.36),
                width: selected ? 2.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
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
              _truckSvg(_hex(color), _hex(Theme.of(context).colorScheme.surface)),
              width: size * 0.58,
              height: size * 0.58,
              semanticsLabel: 'Vehículo ${AppColors.trackingStatusLabel(status)}',
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 19,
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return AnimatedScale(
      scale: selected ? 1.08 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: marker,
    );
  }

  static String _hex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static String _truckSvg(String bodyColor, String surfaceColor) {
    return '''
<svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M16 3.5L20.2 9.2V24.7C20.2 27.1 18.3 29 16 29C13.7 29 11.8 27.1 11.8 24.7V9.2L16 3.5Z" fill="$bodyColor"/>
  <path d="M13.8 10H18.2V17.8H13.8V10Z" fill="$surfaceColor" fill-opacity="0.84"/>
  <path d="M13.8 20.2H18.2V24.2C18.2 25.5 17.2 26.5 16 26.5C14.8 26.5 13.8 25.5 13.8 24.2V20.2Z" fill="$surfaceColor" fill-opacity="0.34"/>
  <path d="M11.8 13.8H9.6V23.3H11.8V13.8Z" fill="$bodyColor" fill-opacity="0.74"/>
  <path d="M22.4 13.8H20.2V23.3H22.4V13.8Z" fill="$bodyColor" fill-opacity="0.74"/>
  <path d="M16 3.5L20.2 9.2V24.7C20.2 27.1 18.3 29 16 29C13.7 29 11.8 27.1 11.8 24.7V9.2L16 3.5Z" stroke="$surfaceColor" stroke-opacity="0.72" stroke-width="1.2"/>
</svg>
''';
  }
}

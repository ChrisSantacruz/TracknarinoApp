import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class OperationalStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  const OperationalStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
  });

  factory OperationalStatusChip.tracking(String status, {bool compact = false}) {
    return OperationalStatusChip(
      label: AppColors.trackingStatusLabel(status),
      color: AppColors.trackingStatusColor(status),
      icon: _iconForStatus(status),
      compact: compact,
    );
  }

  static IconData? _iconForStatus(String status) {
    switch (status) {
      case 'active':
      case 'en_ruta':
        return Icons.circle;
      case 'stale':
        return Icons.schedule;
      case 'offline':
        return Icons.cloud_off;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vPad = compact ? AppSpacing.xxs : AppSpacing.xs;
    final hPad = compact ? AppSpacing.xs : AppSpacing.sm;
    final fontSize = compact ? 11.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 10 : 12, color: color),
            SizedBox(width: compact ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/oportunidad_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'operational/operational_status_chip.dart';

class ViajeActivoBanner extends StatelessWidget {
  final Oportunidad viajeActivo;
  final VoidCallback onIniciarViaje;
  final VoidCallback onVerRuta;

  const ViajeActivoBanner({
    super.key,
    required this.viajeActivo,
    required this.onIniciarViaje,
    required this.onVerRuta,
  });

  @override
  Widget build(BuildContext context) {
    final enRuta = viajeActivo.estado == 'en_ruta';
    final esAsignado = viajeActivo.estado == 'asignada';
    final status = enRuta ? 'en_ruta' : 'asignada';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.trackingStatusColor(status),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.cardRadius),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  enRuta ? Icons.local_shipping : Icons.assignment_turned_in,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    enRuta ? 'Viaje en curso' : 'Viaje asignado',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                OperationalStatusChip.tracking(status, compact: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viajeActivo.titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.trip_origin, color: AppColors.statusActive, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        viajeActivo.origen,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.flag, color: AppColors.mapMarkerDestination, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        viajeActivo.destino,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      '\$${viajeActivo.precio.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.deepGreen,
                          ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: onVerRuta,
                      child: const Text('Ver ruta'),
                    ),
                    if (esAsignado) ...[
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: onIniciarViaje,
                        child: const Text('Iniciar'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

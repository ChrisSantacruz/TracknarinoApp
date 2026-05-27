import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';

enum TruckerPlaceCategory { fuel, tire, mechanic, parking, food, emergency }

extension TruckerPlaceCategoryX on TruckerPlaceCategory {
  String get label {
    switch (this) {
      case TruckerPlaceCategory.fuel:
        return 'Gasolina';
      case TruckerPlaceCategory.tire:
        return 'Montallantas';
      case TruckerPlaceCategory.mechanic:
        return 'Taller';
      case TruckerPlaceCategory.parking:
        return 'Parqueo';
      case TruckerPlaceCategory.food:
        return 'Comida';
      case TruckerPlaceCategory.emergency:
        return 'Emergencia';
    }
  }

  IconData get icon {
    switch (this) {
      case TruckerPlaceCategory.fuel:
        return Icons.local_gas_station_outlined;
      case TruckerPlaceCategory.tire:
        return Icons.tire_repair_outlined;
      case TruckerPlaceCategory.mechanic:
        return Icons.handyman_outlined;
      case TruckerPlaceCategory.parking:
        return Icons.local_parking_outlined;
      case TruckerPlaceCategory.food:
        return Icons.restaurant_outlined;
      case TruckerPlaceCategory.emergency:
        return Icons.local_hospital_outlined;
    }
  }

  Color get color {
    switch (this) {
      case TruckerPlaceCategory.fuel:
        return AppColors.emerald400;
      case TruckerPlaceCategory.tire:
        return AppColors.statusStale;
      case TruckerPlaceCategory.mechanic:
        return AppColors.statusSyncing;
      case TruckerPlaceCategory.parking:
        return AppColors.graphite300;
      case TruckerPlaceCategory.food:
        return AppColors.deepGreenLight;
      case TruckerPlaceCategory.emergency:
        return AppColors.alertCritical;
    }
  }
}

class TruckerPlace {
  final String id;
  final String name;
  final TruckerPlaceCategory category;
  final LatLng position;
  final String? address;
  final String? phone;

  const TruckerPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    this.address,
    this.phone,
  });
}

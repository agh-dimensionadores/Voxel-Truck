import 'package:flutter/material.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final TruckStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      TruckStatus.abierto => ('ABIERTO', AppColors.tealDark, AppColors.tealLight),
      TruckStatus.pendiente => ('PENDIENTE', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
      TruckStatus.cerrado => ('CERRADO', AppColors.purpleDark, AppColors.purpleLight),
      TruckStatus.enviado => ('ENVIADO', AppColors.purpleDark, AppColors.purpleLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class LoadAlertBanner extends StatelessWidget {
  const LoadAlertBanner({super.key, required this.validation});

  final LoadValidation validation;

  @override
  Widget build(BuildContext context) {
    if (validation == LoadValidation.optimizada) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.tealDark),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carga optimizada',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealDark,
                    ),
                  ),
                  Text(
                    'Listo para cerrar camión',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isExcess = validation == LoadValidation.excedida;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExcess ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExcess ? AppColors.error.withValues(alpha: 0.4) : AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: isExcess ? AppColors.error : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALERTA',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                    color: isExcess ? AppColors.error : AppColors.warning,
                  ),
                ),
                Text(
                  isExcess ? 'Carga excedida' : 'Camión subutilizado',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isExcess ? AppColors.error : const Color(0xFFB45309),
                  ),
                ),
                Text(
                  isExcess
                      ? 'Cierre bloqueado. Se notificará por email a representantes.'
                      : 'Ocupación menor al 80%. Se notificará por email al cerrar.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.purple,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class OccupancyGauge extends StatelessWidget {
  const OccupancyGauge({
    super.key,
    required this.percent,
    required this.volumeUsed,
    required this.volumeCapacity,
  });

  final double percent;
  final double volumeUsed;
  final double volumeCapacity;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100) / 100;
    Color barColor = AppColors.teal;
    if (percent > 100) {
      barColor = AppColors.error;
    } else if (percent < kOptimizedOccupancyMin) {
      barColor = AppColors.warning;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ocupación',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: barColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: clamped,
                minHeight: 10,
                backgroundColor: AppColors.border,
                color: barColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${volumeUsed.toStringAsFixed(1)} m³ de ${volumeCapacity.toStringAsFixed(0)} m³',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleRecommendationCard extends StatelessWidget {
  const VehicleRecommendationCard({super.key, required this.vehicle});

  final VehicleType vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.purple, AppColors.purpleDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehículo recomendado',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  vehicle.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${vehicle.volumeM3.toStringAsFixed(0)} m³ de capacidad',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
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

class TruckListTile extends StatelessWidget {
  const TruckListTile({super.key, required this.truck, required this.onTap});

  final Truck truck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vehicle = truck.recommendedVehicle(vehicleTypes);
    final validation = truck.validateLoad(vehicleTypes);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      truck.tripNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  StatusBadge(status: truck.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${truck.logisticsCenter} → ${truck.destination}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniStat(label: '${truck.huCount} HU', icon: Icons.inventory_2_outlined),
                  const SizedBox(width: 16),
                  _MiniStat(
                    label: '${truck.totalVolume.toStringAsFixed(1)} m³',
                    icon: Icons.view_in_ar_outlined,
                  ),
                  const Spacer(),
                  if (truck.status == TruckStatus.pendiente)
                    const Icon(
                      Icons.mail_outline,
                      size: 20,
                      color: AppColors.warning,
                    ),
                  if (truck.status == TruckStatus.abierto && validation != LoadValidation.optimizada)
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: validation == LoadValidation.excedida ? AppColors.error : AppColors.warning,
                    ),
                  if (vehicle != null && (truck.status == TruckStatus.abierto || truck.status == TruckStatus.cerrado))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vehicle.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.purple),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

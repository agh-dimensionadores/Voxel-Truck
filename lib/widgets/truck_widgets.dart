import 'package:flutter/material.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/state/display_settings_controller.dart';
import 'package:voxel_truck/theme/app_colors.dart';
import 'package:voxel_truck/utils/unit_formatter.dart';
import 'package:voxel_truck/widgets/modern_surface.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
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
      return ModernSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: AppColors.tealLight.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.tealDark, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Carga optimizada · listo para cerrar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.tealDark,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isExcess = validation == LoadValidation.excedida;
    final color = isExcess ? AppColors.error : AppColors.warning;
    return ModernSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: (isExcess ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)).withValues(alpha: 0.7),
      border: Border.all(color: color.withValues(alpha: 0.25)),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isExcess
                  ? 'Carga excedida · alerta por email al cerrar'
                  : 'Subutilizado (<80%) · alerta por email al cerrar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isExcess ? AppColors.error : const Color(0xFFB45309),
              ),
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
      child: ModernSurface(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        radius: 16,
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
    final formatter = UnitFormatter(DisplaySettingsScope.of(context).settings);
    final clamped = percent.clamp(0, 100) / 100;
    Color barColor = AppColors.teal;
    if (percent > 100) {
      barColor = AppColors.error;
    } else if (percent < kOptimizedOccupancyMin) {
      barColor = AppColors.warning;
    }

    return ModernSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Ocupación',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  height: 1,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 8,
              backgroundColor: AppColors.border.withValues(alpha: 0.5),
              color: barColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatter.formatVolumeRange(volumeUsed, volumeCapacity),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class VehicleRecommendationCard extends StatelessWidget {
  const VehicleRecommendationCard({super.key, required this.vehicle});

  final VehicleType vehicle;

  @override
  Widget build(BuildContext context) {
    final formatter = UnitFormatter(DisplaySettingsScope.of(context).settings);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.08),
            AppColors.teal.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.purple, AppColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo recomendado',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${vehicle.name} · ${formatter.formatVolume(vehicle.volumeM3, decimals: 0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
    final formatter = UnitFormatter(DisplaySettingsScope.of(context).settings);
    final vehicle = truck.recommendedVehicle(vehicleTypes);
    final validation = truck.validateLoad(vehicleTypes);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ModernSurface(
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
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    StatusBadge(status: truck.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.purple.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${truck.logisticsCenter}  →  ${truck.destination}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniStat(label: '${truck.huCount} HU', icon: Icons.inventory_2_outlined),
                    const SizedBox(width: 14),
                    _MiniStat(
                      label: formatter.formatVolume(truck.totalVolume),
                      icon: Icons.view_in_ar_outlined,
                    ),
                    const Spacer(),
                    if (truck.status == TruckStatus.pendiente)
                      Icon(Icons.mail_outline, size: 18, color: AppColors.warning.withValues(alpha: 0.9)),
                    if (truck.status == TruckStatus.abierto && validation != LoadValidation.optimizada)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: validation == LoadValidation.excedida ? AppColors.error : AppColors.warning,
                        ),
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
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
        Icon(icon, size: 13, color: AppColors.purple),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

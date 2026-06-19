import 'package:flutter/material.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/state/display_settings_controller.dart';
import 'package:voxel_truck/theme/app_colors.dart';
import 'package:voxel_truck/utils/unit_formatter.dart';
import 'package:voxel_truck/widgets/modern_surface.dart';

class HuListTile extends StatelessWidget {
  const HuListTile({
    super.key,
    required this.unit,
    required this.onDelete,
    this.canDelete = true,
  });

  final HandlingUnit unit;
  final VoidCallback onDelete;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = UnitFormatter(DisplaySettingsScope.of(context).settings);
    final sourceLabel = switch (unit.source) {
      DimensionSource.voxelCam => 'Voxel Cam',
      DimensionSource.coresa => 'Coresa',
      DimensionSource.manual => 'Manual',
    };

    final sourceColor = switch (unit.source) {
      DimensionSource.voxelCam => AppColors.purple,
      DimensionSource.coresa => AppColors.teal,
      DimensionSource.manual => AppColors.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ModernSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 16,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.purpleLight,
                    AppColors.tealLight.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: AppColors.purple, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.code,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatter.formatDimensions(unit),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sourceLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sourceColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatter.formatVolume(unit.volume, decimals: 2),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.tealDark,
                  ),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.border.withValues(alpha: 0.4),
                      minimumSize: const Size(32, 32),
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

class VoxelLogo extends StatelessWidget {
  const VoxelLogo({super.key, this.height = 42});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'static/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_in_ar_rounded, color: AppColors.purple, size: height),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: height * 0.55, fontWeight: FontWeight.w700),
              children: const [
                TextSpan(text: 'Voxel ', style: TextStyle(color: AppColors.purple)),
                TextSpan(text: 'Truck', style: TextStyle(color: AppColors.teal)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MobileShell extends StatelessWidget {
  const MobileShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 480) {
          return child;
        }

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        );
      },
    );
  }
}

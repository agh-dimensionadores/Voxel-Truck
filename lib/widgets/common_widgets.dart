import 'package:flutter/material.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/theme/app_colors.dart';

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
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRect(child: child),
          ),
        );
      },
    );
  }
}

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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.purpleLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: AppColors.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.code,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${unit.length.toInt()}×${unit.width.toInt()}×${unit.height.toInt()} cm · ${unit.weight.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sourceLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
                  '${unit.volume.toStringAsFixed(2)} m³',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.tealDark),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.error,
                    visualDensity: VisualDensity.compact,
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

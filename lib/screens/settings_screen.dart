import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voxel_truck/config/app_config.dart';
import 'package:voxel_truck/models/display_units.dart';
import 'package:voxel_truck/state/display_settings_controller.dart';
import 'package:voxel_truck/theme/app_colors.dart';
import 'package:voxel_truck/utils/unit_formatter.dart';
import 'package:voxel_truck/widgets/modern_surface.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DisplaySettingsScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final settings = controller.settings;
          final formatter = UnitFormatter(settings);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              ModernSurface(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      AppConfig.isApiConfigured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      color: AppConfig.isApiConfigured ? AppColors.teal : AppColors.warning,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConfig.isApiConfigured ? 'Voxel Cam conectado' : 'Modo demo (sin API)',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppConfig.isApiConfigured
                                ? AppConfig.apiBaseUrl
                                : 'El APK no tiene URL/token. Solo funcionan códigos demo.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unidades de visualización',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 12),
              ModernSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.view_in_ar_outlined, color: AppColors.teal, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Volumen',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cómo se muestran los volúmenes en la app',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    ...VolumeDisplayUnit.values.map(
                      (unit) => _SettingsRadioTile<VolumeDisplayUnit>(
                        value: unit,
                        groupValue: settings.volumeUnit,
                        onChanged: (value) {
                          if (value != null) controller.setVolumeUnit(value);
                        },
                        activeColor: AppColors.teal,
                        title: Text(unit.title),
                        subtitle: Text(
                          unit == VolumeDisplayUnit.dm3
                              ? 'Recomendado · coincide con Voxel Cam'
                              : 'Equivalente tradicional de capacidad de camión',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ModernSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.straighten_rounded, color: AppColors.purple, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Dimensiones',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Largo, ancho y alto de cada bulto',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    ...DimensionDisplayUnit.values.map(
                      (unit) => _SettingsRadioTile<DimensionDisplayUnit>(
                        value: unit,
                        groupValue: settings.dimensionUnit,
                        onChanged: (value) {
                          if (value != null) controller.setDimensionUnit(value);
                        },
                        activeColor: AppColors.purple,
                        title: Text(unit.title),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ejemplo: ${formatter.formatVolume(0.578)} · ${formatter.formatDimensionLine(120.5, 80, 60)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsRadioTile<T> extends StatelessWidget {
  const _SettingsRadioTile({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.activeColor,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: RadioListTile<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        contentPadding: EdgeInsets.zero,
        activeColor: activeColor,
      ),
    );
  }
}

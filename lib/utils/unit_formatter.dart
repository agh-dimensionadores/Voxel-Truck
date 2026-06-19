import 'package:voxel_truck/models/display_units.dart';
import 'package:voxel_truck/models/truck.dart';

/// Valores internos: dimensiones en cm (como vienen del API), volumen en m³.
class UnitFormatter {
  const UnitFormatter(this.settings);

  final DisplaySettings settings;

  double volumeFromM3(double volumeM3) {
    return settings.volumeUnit == VolumeDisplayUnit.dm3 ? volumeM3 * 1000 : volumeM3;
  }

  String formatVolume(double volumeM3, {int decimals = 1}) {
    final value = volumeFromM3(volumeM3);
    final decimalsAdjusted = settings.volumeUnit == VolumeDisplayUnit.dm3 && decimals == 1 ? 2 : decimals;
    return '${value.toStringAsFixed(decimalsAdjusted)} ${settings.volumeUnit.label}';
  }

  String formatVolumeRange(double usedM3, double capacityM3) {
    final usedDecimals = settings.volumeUnit == VolumeDisplayUnit.dm3 ? 2 : 1;
    final capacityDecimals = settings.volumeUnit == VolumeDisplayUnit.dm3 ? 0 : 0;
    return '${volumeFromM3(usedM3).toStringAsFixed(usedDecimals)} ${settings.volumeUnit.label} '
        'de ${volumeFromM3(capacityM3).toStringAsFixed(capacityDecimals)} ${settings.volumeUnit.label}';
  }

  String formatDimensions(HandlingUnit unit) {
    if (unit.isLot) {
      return 'Lote · ${unit.bundleCount} bultos · ${unit.weight.toStringAsFixed(1)} kg';
    }
    if (unit.length > 0 && unit.width > 0 && unit.height > 0) {
      return '${formatDimensionLine(unit.length, unit.width, unit.height)} · ${unit.weight.toStringAsFixed(1)} kg';
    }
    return '${unit.weight.toStringAsFixed(1)} kg';
  }

  /// [lengthCm], [widthCm], [heightCm] ya están en centímetros (sin convertir).
  String formatDimensionLine(double lengthCm, double widthCm, double heightCm) {
    final l = _formatDimensionValue(lengthCm);
    final w = _formatDimensionValue(widthCm);
    final h = _formatDimensionValue(heightCm);
    return '$l×$w×$h ${settings.dimensionUnit.label}';
  }

  String _formatDimensionValue(double valueCm) {
    if (settings.dimensionUnit == DimensionDisplayUnit.mm) {
      return (valueCm * 10).toStringAsFixed(0);
    }
    return valueCm == valueCm.roundToDouble()
        ? valueCm.toStringAsFixed(0)
        : valueCm.toStringAsFixed(1);
  }
}

/// Convierte volumen del API (dm³) a m³ internos.
double volumeDm3ToM3(double? dm3) {
  if (dm3 == null) return 0;
  return dm3 / 1000;
}

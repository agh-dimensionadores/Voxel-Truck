import 'package:voxel_truck/utils/unit_formatter.dart';

enum TruckStatus { abierto, pendiente, cerrado, enviado }

enum LoadValidation { optimizada, subutilizada, excedida }

enum DimensionSource { voxelCam, coresa, manual }

const double kOptimizedOccupancyMin = 80;

class HandlingUnit {
  const HandlingUnit({
    required this.code,
    required this.length,
    required this.width,
    required this.height,
    required this.weight,
    required this.source,
    this.explicitVolumeM3,
    this.bundleCount,
  });

  final String code;
  final double length;
  final double width;
  final double height;
  final double weight;
  final DimensionSource source;
  final double? explicitVolumeM3;
  final int? bundleCount;

  bool get isLot => bundleCount != null && bundleCount! > 1;

  double get volume {
    if (explicitVolumeM3 != null) return explicitVolumeM3!;
    if (length > 0 && width > 0 && height > 0) {
      return (length * width * height) / 1_000_000;
    }
    return 0;
  }

  factory HandlingUnit.fromVoxelCamApi(Map<String, dynamic> data, String scannedCode) {
    final largo = _dimensionCm(data, 'largo');
    final ancho = _dimensionCm(data, 'ancho');
    final alto = _dimensionCm(data, 'alto');
    final peso = _toDouble(data['peso']);
    final pesoTotal = _toDouble(data['peso_total']);
    final volumen = _toDouble(data['volumen']);
    final volumenTotal = _toDouble(data['volumen_total']);
    final cantidadBultos = _toInt(data['cantidad_bultos']);

    final weight = peso ?? pesoTotal ?? 0;
    final rawVolumeDm3 = volumenTotal ?? volumen;
    final explicitVolume =
        rawVolumeDm3 != null ? volumeDm3ToM3(rawVolumeDm3) : null;

    return HandlingUnit(
      code: scannedCode,
      length: largo,
      width: ancho,
      height: alto,
      weight: weight,
      source: DimensionSource.voxelCam,
      explicitVolumeM3: explicitVolume,
      bundleCount: cantidadBultos > 1 ? cantidadBultos : null,
    );
  }

  static double _dimensionCm(Map<String, dynamic> data, String base) {
    final direct = _toDouble(data['${base}_cm']) ??
        _toDouble(data[base]) ??
        _toDouble(data[_englishDimensionKey(base)]);
    return direct ?? 0;
  }

  static String _englishDimensionKey(String base) => switch (base) {
        'largo' => 'length',
        'ancho' => 'width',
        'alto' => 'height',
        _ => base,
      };

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _toInt(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class VehicleType {
  const VehicleType({required this.name, required this.volumeM3});

  final String name;
  final double volumeM3;
}

class Truck {
  Truck({
    required this.id,
    required this.tripNumber,
    required this.logisticsCenter,
    required this.destination,
    required this.date,
    this.observations,
    this.status = TruckStatus.abierto,
    this.savedOccupancyPercent,
    this.closedAt,
    this.alertEmailSent = false,
    List<HandlingUnit>? handlingUnits,
  }) : handlingUnits = handlingUnits ?? [];

  final String id;
  final String tripNumber;
  final String logisticsCenter;
  final String destination;
  final DateTime date;
  final String? observations;
  TruckStatus status;
  double? savedOccupancyPercent;
  DateTime? closedAt;
  bool alertEmailSent;
  final List<HandlingUnit> handlingUnits;

  double get totalWeight => handlingUnits.fold(0, (sum, hu) => sum + hu.weight);

  double get totalVolume =>
      handlingUnits.fold(0, (sum, hu) => sum + hu.volume);

  int get huCount => handlingUnits.length;

  bool get isEditable => status == TruckStatus.abierto;

  VehicleType? recommendedVehicle(List<VehicleType> vehicles) {
    if (handlingUnits.isEmpty) return null;
    for (final vehicle in vehicles) {
      if (totalVolume <= vehicle.volumeM3) return vehicle;
    }
    return vehicles.last;
  }

  double occupancyPercent(VehicleType? vehicle) {
    if (vehicle == null || vehicle.volumeM3 == 0) return 0;
    return (totalVolume / vehicle.volumeM3 * 100).clamp(0, 150);
  }

  LoadValidation validateLoad(List<VehicleType> vehicles) {
    if (handlingUnits.isEmpty) return LoadValidation.subutilizada;

    final vehicle = recommendedVehicle(vehicles);
    if (vehicle == null) return LoadValidation.subutilizada;

    final percent = occupancyPercent(vehicle);
    if (percent > 100) return LoadValidation.excedida;
    if (percent < kOptimizedOccupancyMin) return LoadValidation.subutilizada;
    return LoadValidation.optimizada;
  }

  bool isOptimized(List<VehicleType> vehicles) =>
      validateLoad(vehicles) == LoadValidation.optimizada;
}
